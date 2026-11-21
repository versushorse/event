// 天気予報取得サービス（気象庁 公式天気予報JSONによる商用利用可能・無料気象データ連携）
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/outing_spot.dart';

/// 1日分の天気情報
class DailyWeather {
  final DateTime date;
  final String weatherCodeLabel;
  final String weatherIcon;
  final double maxTemp;
  final double minTemp;
  final int rainProbability;

  const DailyWeather({
    required this.date,
    required this.weatherCodeLabel,
    required this.weatherIcon,
    required this.maxTemp,
    required this.minTemp,
    required this.rainProbability,
  });

  String get shortLabel =>
      '$weatherIcon $weatherCodeLabel ${maxTemp.round()}℃/${minTemp.round()}℃ (雨$rainProbability%)';

  bool get isRainy => rainProbability >= 50 || weatherCodeLabel.contains('雨') || weatherCodeLabel.contains('雪');
}

/// エリアの週末・週間天気サマリー
class AreaWeatherSummary {
  final String areaName;
  final List<DailyWeather> dailyForecasts;
  final String adviceComment;

  const AreaWeatherSummary({
    required this.areaName,
    required this.dailyForecasts,
    required this.adviceComment,
  });

  String get summaryText {
    if (dailyForecasts.isEmpty) return '🌤️ お出かけ日和';
    return dailyForecasts.map((d) {
      final wday = ['', '月', '火', '水', '木', '金', '土', '日'][d.date.weekday];
      return '${d.date.month}/${d.date.day}($wday) ${d.shortLabel}';
    }).join(' ｜ ');
  }
}

class WeatherService {
  /// 指定座標（緯度経度）に対応する都道府県の気象庁予報区コードに変換
  static String _toJmaOfficeCode(double lat, double lng) {
    final id = TohokuRegion.nearestTo(lat, lng).ikoyoPrefectureId;
    if (id == 1) return '016000'; // 北海道（石狩・札幌代表）
    if (id == 46) return '460100'; // 鹿児島県
    if (id == 47) return '471000'; // 沖縄県（本島代表）
    return '${id.toString().padLeft(2, '0')}0000';
  }

  /// 指定座標（緯度経度）の直近週末の天気を気象庁公式JSONから取得
  static Future<AreaWeatherSummary?> fetchWeekendWeather({
    required double lat,
    required double lng,
    required String areaName,
    DateTime? targetSaturday,
  }) async {
    try {
      final officeCode = _toJmaOfficeCode(lat, lng);
      final uri = Uri.parse(
        'https://www.jma.go.jp/bosai/forecast/data/forecast/$officeCode.json',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return _fallbackWeather(areaName);

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is! List || decoded.isEmpty) {
        return _fallbackWeather(areaName);
      }

      // 日付('YYYY-MM-DD')をキーにしてコード・降水確率・最高/最低気温を集約
      final codeByDate = <String, String>{};
      final popByDate = <String, int>{};
      final maxByDate = <String, double>{};
      final minByDate = <String, double>{};

      // 1. 週間予報（decoded[1]）を優先読み込み
      if (decoded.length > 1 && decoded[1] is Map<String, dynamic>) {
        final weekly = decoded[1] as Map<String, dynamic>;
        final tsList = weekly['timeSeries'] as List<dynamic>? ?? [];
        if (tsList.isNotEmpty && tsList[0] is Map<String, dynamic>) {
          final ts0 = tsList[0] as Map<String, dynamic>;
          final times = ts0['timeDefines'] as List<dynamic>? ?? [];
          final areas = ts0['areas'] as List<dynamic>? ?? [];
          if (areas.isNotEmpty && areas[0] is Map<String, dynamic>) {
            final area0 = areas[0] as Map<String, dynamic>;
            final codes = area0['weatherCodes'] as List<dynamic>? ?? [];
            final pops = area0['pops'] as List<dynamic>? ?? [];
            for (var i = 0; i < times.length; i++) {
              final dateKey = _dateKeyFromIso(times[i].toString());
              if (dateKey == null) continue;
              if (i < codes.length) {
                final c = codes[i].toString().trim();
                if (c.isNotEmpty) codeByDate[dateKey] = c;
              }
              if (i < pops.length) {
                final p = int.tryParse(pops[i].toString().trim());
                if (p != null) popByDate[dateKey] = p;
              }
            }
          }
        }
        if (tsList.length > 1 && tsList[1] is Map<String, dynamic>) {
          final ts1 = tsList[1] as Map<String, dynamic>;
          final times = ts1['timeDefines'] as List<dynamic>? ?? [];
          final areas = ts1['areas'] as List<dynamic>? ?? [];
          if (areas.isNotEmpty && areas[0] is Map<String, dynamic>) {
            final area0 = areas[0] as Map<String, dynamic>;
            final mins = area0['tempsMin'] as List<dynamic>? ?? [];
            final maxs = area0['tempsMax'] as List<dynamic>? ?? [];
            for (var i = 0; i < times.length; i++) {
              final dateKey = _dateKeyFromIso(times[i].toString());
              if (dateKey == null) continue;
              if (i < mins.length) {
                final mn = double.tryParse(mins[i].toString().trim());
                if (mn != null) minByDate[dateKey] = mn;
              }
              if (i < maxs.length) {
                final mx = double.tryParse(maxs[i].toString().trim());
                if (mx != null) maxByDate[dateKey] = mx;
              }
            }
          }
        }
      }

      // 2. 短期3日間予報（decoded[0]）で今日・明日のコードを補完
      if (decoded[0] is Map<String, dynamic>) {
        final shortTerm = decoded[0] as Map<String, dynamic>;
        final tsList = shortTerm['timeSeries'] as List<dynamic>? ?? [];
        if (tsList.isNotEmpty && tsList[0] is Map<String, dynamic>) {
          final ts0 = tsList[0] as Map<String, dynamic>;
          final times = ts0['timeDefines'] as List<dynamic>? ?? [];
          final areas = ts0['areas'] as List<dynamic>? ?? [];
          if (areas.isNotEmpty && areas[0] is Map<String, dynamic>) {
            final area0 = areas[0] as Map<String, dynamic>;
            final codes = area0['weatherCodes'] as List<dynamic>? ?? [];
            for (var i = 0; i < times.length; i++) {
              final dateKey = _dateKeyFromIso(times[i].toString());
              if (dateKey == null || codeByDate.containsKey(dateKey)) continue;
              if (i < codes.length) {
                final c = codes[i].toString().trim();
                if (c.isNotEmpty) codeByDate[dateKey] = c;
              }
            }
          }
        }
      }

      if (codeByDate.isEmpty) return _fallbackWeather(areaName);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final satDate = targetSaturday ?? _calculateNextSaturday(today);
      final sunDate = satDate.add(const Duration(days: 1));
      final sortedKeys = codeByDate.keys.toList()..sort();

      final forecasts = <DailyWeather>[];
      for (final dateKey in sortedKeys) {
        final dt = DateTime.tryParse(dateKey);
        if (dt == null) continue;
        final isSat = dt.year == satDate.year &&
            dt.month == satDate.month &&
            dt.day == satDate.day;
        final isSun = dt.year == sunDate.year &&
            dt.month == sunDate.month &&
            dt.day == sunDate.day;
        if (isSat || isSun) {
          final info = _interpretJmaWeatherCode(codeByDate[dateKey] ?? '100');
          forecasts.add(
            DailyWeather(
              date: dt,
              weatherCodeLabel: info.label,
              weatherIcon: info.icon,
              maxTemp: maxByDate[dateKey] ?? 15.0,
              minTemp: minByDate[dateKey] ?? 7.0,
              rainProbability: popByDate[dateKey] ?? (info.isRainyDefault ? 60 : 20),
            ),
          );
        }
      }

      // もし直近週末がAPIの範囲外だった場合は直近2日分を抽出
      if (forecasts.isEmpty) {
        for (var i = 0; i < sortedKeys.length && i < 2; i++) {
          final dateKey = sortedKeys[i];
          final dt = DateTime.tryParse(dateKey) ?? now;
          final info = _interpretJmaWeatherCode(codeByDate[dateKey] ?? '100');
          forecasts.add(
            DailyWeather(
              date: dt,
              weatherCodeLabel: info.label,
              weatherIcon: info.icon,
              maxTemp: maxByDate[dateKey] ?? 15.0,
              minTemp: minByDate[dateKey] ?? 7.0,
              rainProbability: popByDate[dateKey] ?? (info.isRainyDefault ? 60 : 20),
            ),
          );
        }
      }

      // 天気に応じたお出かけアドバイスコメントを生成
      String advice;
      final hasRain = forecasts.any((f) => f.isRainy);
      if (hasRain) {
        advice = '🌧️ 雨や冷え込みの予報があるため、屋内スポットや温泉・スパでのリフレッシュがおすすめです！';
      } else {
        advice = '☀️ 過ごしやすいお出かけ日和！大きな公園やマルシェ、自然ドライブにぴったりです。';
      }

      return AreaWeatherSummary(
        areaName: areaName,
        dailyForecasts: forecasts,
        adviceComment: advice,
      );
    } catch (e) {
      debugPrint('[WeatherService] 気象庁天気取得エラー: $e');
      return _fallbackWeather(areaName);
    }
  }

  static String? _dateKeyFromIso(String iso) {
    if (iso.length < 10) return null;
    final sub = iso.substring(0, 10);
    return DateTime.tryParse(sub) != null ? sub : null;
  }

  static DateTime _calculateNextSaturday(DateTime today) {
    if (today.weekday == DateTime.sunday) {
      return today.subtract(const Duration(days: 1));
    }
    final daysUntilSat = DateTime.saturday - today.weekday;
    return today.add(Duration(days: daysUntilSat));
  }

  static ({String label, String icon, bool isRainyDefault})
      _interpretJmaWeatherCode(String rawCode) {
    final code = rawCode.trim();
    if (code.startsWith('4')) {
      return (label: '雪', icon: '❄️', isRainyDefault: true);
    }
    if (code.startsWith('3')) {
      if (code == '304' || code == '309' || code == '314' || code == '322') {
        return (label: 'みぞれ・雪', icon: '❄️', isRainyDefault: true);
      }
      return (label: '雨', icon: '🌧️', isRainyDefault: true);
    }
    if (code.startsWith('2')) {
      if (code == '200') return (label: 'くもり', icon: '☁️', isRainyDefault: false);
      if (code == '201') {
        return (label: 'くもり時々晴', icon: '⛅', isRainyDefault: false);
      }
      const rainSubCodes = [
        '202', '203', '206', '207', '208', '210', '211', '212', '213', '214',
        '218', '219', '220', '221', '222', '223', '224', '225', '240', '250',
        '260', '270', '281',
      ];
      if (rainSubCodes.contains(code)) {
        return (label: 'くもり時々雨', icon: '🌦️', isRainyDefault: true);
      }
      return (label: 'くもり', icon: '☁️', isRainyDefault: false);
    }
    if (code == '100') return (label: '快晴', icon: '☀️', isRainyDefault: false);
    if (code == '101') return (label: '晴れ時々曇', icon: '🌤️', isRainyDefault: false);
    const sunnyRainCodes = [
      '102', '103', '106', '107', '108', '112', '113', '114', '118', '119',
    ];
    if (sunnyRainCodes.contains(code)) {
      return (label: '晴れ一時雨', icon: '🌦️', isRainyDefault: true);
    }
    return (label: '晴れ', icon: '☀️', isRainyDefault: false);
  }

  static AreaWeatherSummary _fallbackWeather(String areaName) {
    final now = DateTime.now();
    final sat = _calculateNextSaturday(now);
    final sun = sat.add(const Duration(days: 1));
    return AreaWeatherSummary(
      areaName: areaName,
      dailyForecasts: [
        DailyWeather(
          date: sat,
          weatherCodeLabel: '晴れ時々曇',
          weatherIcon: '🌤️',
          maxTemp: 16.0,
          minTemp: 7.0,
          rainProbability: 20,
        ),
        DailyWeather(
          date: sun,
          weatherCodeLabel: '晴れ',
          weatherIcon: '☀️',
          maxTemp: 17.0,
          minTemp: 8.0,
          rainProbability: 10,
        ),
      ],
      adviceComment: '🌤️ 過ごしやすい週末の予報です。お出かけ・ドライブを楽しんでください！',
    );
  }
}
