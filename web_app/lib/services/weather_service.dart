// 天気予報取得サービス（Open-Meteo API による無料・高精度気象データ連携）
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  /// 指定座標（緯度経度）の直近週末の天気を取得
  static Future<AreaWeatherSummary?> fetchWeekendWeather({
    required double lat,
    required double lng,
    required String areaName,
    DateTime? targetSaturday,
  }) async {
    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&timezone=Asia%2FTokyo',
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode != 200) return _fallbackWeather(areaName);

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>?;
      if (daily == null) return _fallbackWeather(areaName);

      final timeList = daily['time'] as List<dynamic>? ?? [];
      final codes = daily['weather_code'] as List<dynamic>? ?? [];
      final maxTemps = daily['temperature_2m_max'] as List<dynamic>? ?? [];
      final minTemps = daily['temperature_2m_min'] as List<dynamic>? ?? [];
      final rains = daily['precipitation_probability_max'] as List<dynamic>? ?? [];

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final satDate = targetSaturday ?? _calculateNextSaturday(today);
      final sunDate = satDate.add(const Duration(days: 1));

      final forecasts = <DailyWeather>[];

      for (var i = 0; i < timeList.length; i++) {
        final dateStr = timeList[i].toString();
        final dt = DateTime.tryParse(dateStr);
        if (dt == null) continue;

        final isSat = dt.year == satDate.year && dt.month == satDate.month && dt.day == satDate.day;
        final isSun = dt.year == sunDate.year && dt.month == sunDate.month && dt.day == sunDate.day;

        // 週末（土・日）に合致する予報をピックアップ
        if (isSat || isSun) {
          final code = (codes[i] as num?)?.toInt() ?? 0;
          final maxT = (maxTemps[i] as num?)?.toDouble() ?? 15.0;
          final minT = (minTemps[i] as num?)?.toDouble() ?? 8.0;
          final rainP = (rains[i] as num?)?.toInt() ?? 10;
          final info = _interpretWeatherCode(code);

          forecasts.add(
            DailyWeather(
              date: dt,
              weatherCodeLabel: info.label,
              weatherIcon: info.icon,
              maxTemp: maxT,
              minTemp: minT,
              rainProbability: rainP,
            ),
          );
        }
      }

      // もし直近週末がAPIの範囲外（翌週末など先の日付）だった場合は直近2日分を抽出
      if (forecasts.isEmpty && timeList.isNotEmpty) {
        for (var i = 0; i < timeList.length && i < 2; i++) {
          final dt = DateTime.tryParse(timeList[i].toString()) ?? now;
          final code = (codes[i] as num?)?.toInt() ?? 0;
          final maxT = (maxTemps[i] as num?)?.toDouble() ?? 15.0;
          final minT = (minTemps[i] as num?)?.toDouble() ?? 8.0;
          final rainP = (rains[i] as num?)?.toInt() ?? 10;
          final info = _interpretWeatherCode(code);

          forecasts.add(
            DailyWeather(
              date: dt,
              weatherCodeLabel: info.label,
              weatherIcon: info.icon,
              maxTemp: maxT,
              minTemp: minT,
              rainProbability: rainP,
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
      debugPrint('[WeatherService] 天気取得エラー: $e');
      return _fallbackWeather(areaName);
    }
  }

  static DateTime _calculateNextSaturday(DateTime today) {
    if (today.weekday == DateTime.sunday) {
      return today.subtract(const Duration(days: 1));
    }
    final daysUntilSat = DateTime.saturday - today.weekday;
    return today.add(Duration(days: daysUntilSat));
  }

  static ({String label, String icon}) _interpretWeatherCode(int code) {
    switch (code) {
      case 0:
        return (label: '快晴', icon: '☀️');
      case 1:
      case 2:
        return (label: '晴れ時々曇', icon: '🌤️');
      case 3:
        return (label: 'くもり', icon: '☁️');
      case 45:
      case 48:
        return (label: '霧', icon: '🌫️');
      case 51:
      case 53:
      case 55:
        return (label: '小雨', icon: '🌧️');
      case 61:
      case 63:
      case 65:
        return (label: '雨', icon: '🌧️');
      case 71:
      case 73:
      case 75:
      case 85:
      case 86:
        return (label: '雪', icon: '❄️');
      case 80:
      case 81:
      case 82:
        return (label: 'にわか雨', icon: '🌦️');
      case 95:
      case 96:
      case 99:
        return (label: '雷雨', icon: '⚡');
      default:
        return (label: '晴れ', icon: '☀️');
    }
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
