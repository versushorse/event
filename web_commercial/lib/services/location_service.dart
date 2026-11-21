// 位置情報（GPS）取得・距離計算サービス
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final double latitude;
  final double longitude;
  final String label;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.label,
  });
}

class LocationService {
  /// 端末が直近にキャッシュしている位置情報を瞬時（ミリ秒）に取得
  static Future<LocationResult?> getLastKnownLocation() async {
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final label = _guessAreaName(position.latitude, position.longitude);
        return LocationResult(
          latitude: position.latitude,
          longitude: position.longitude,
          label: label,
        );
      }
    } catch (e) {
      debugPrint('[LocationService] キャッシュ位置取得スキップ: $e');
    }
    return null;
  }

  /// 現在位置（GPS）を高精度で取得する
  static Future<LocationResult?> getCurrentLocation() async {
    // ユニットテスト/ウィジェットテスト環境ではネイティブGPSを呼び出さず安全にスキップ
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }

    try {
      // 1. 位置情報サービスが有効かチェック
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] 位置情報サービス（GPS）が無効です');
        return null;
      }

      // 2. 権限チェック
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LocationService] 位置情報の権限が拒否されました');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] 位置情報の権限が永続的に拒否されています');
        return null;
      }

      // 3. 現在地を取得（高精度、タイムアウト6秒）
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );

      final label = _guessAreaName(position.latitude, position.longitude);

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    } catch (e) {
      debugPrint('[LocationService] 現在地取得エラー: $e');
      // 高精度取得でタイムアウトや失敗した場合、直近のキャッシュ位置があればそれを返す
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationResult(
            latitude: lastKnown.latitude,
            longitude: lastKnown.longitude,
            label: _guessAreaName(lastKnown.latitude, lastKnown.longitude),
          );
        }
      } catch (_) {}
      return null;
    }
  }

  /// 緯度経度からおおよそのエリア名を推定（逆ジオコーディングの軽量フォールバック）
  static String _guessAreaName(double lat, double lng) {
    // 東北・宮城
    if (lat >= 38.20 && lat <= 38.50 && lng >= 140.70 && lng <= 141.10) {
      return '宮城・仙台・泉エリア';
    } else if (lat >= 37.80 && lat <= 39.00 && lng >= 140.00 && lng <= 141.50) {
      return '宮城・東北エリア';
    }
    // 関東
    else if (lat >= 35.65 && lat <= 35.75 && lng >= 139.65 && lng <= 139.80) {
      return '東京都心周辺';
    } else if (lat >= 35.55 && lat < 35.65 && lng >= 139.55 && lng <= 139.75) {
      return '城南・川崎エリア';
    } else if (lat >= 35.40 && lat < 35.55 && lng >= 139.55 && lng <= 139.70) {
      return '横浜エリア';
    } else if (lat >= 35.60 && lat <= 35.80 && lng >= 139.30 && lng < 139.60) {
      return '東京多摩エリア';
    } else if (lat >= 35.80 && lat <= 36.00 && lng >= 139.50 && lng <= 139.75) {
      return '埼玉南・さいたまエリア';
    } else if (lat >= 35.55 && lat <= 35.75 && lng >= 139.85 && lng <= 140.20) {
      return '千葉西・湾岸エリア';
    }
    // 中部・関西・その他主要都市
    else if (lat >= 35.00 && lat <= 35.30 && lng >= 136.80 && lng <= 137.10) {
      return '愛知・名古屋エリア';
    } else if (lat >= 34.60 && lat <= 34.85 && lng >= 135.40 && lng <= 135.65) {
      return '大阪エリア';
    } else if (lat >= 34.95 && lat <= 35.10 && lng >= 135.70 && lng <= 135.85) {
      return '京都エリア';
    } else if (lat >= 34.65 && lat <= 34.75 && lng >= 135.15 && lng <= 135.30) {
      return '兵庫・神戸エリア';
    } else if (lat >= 33.50 && lat <= 33.70 && lng >= 130.30 && lng <= 130.50) {
      return '福岡エリア';
    } else if (lat >= 43.00 && lat <= 43.15 && lng >= 141.25 && lng <= 141.45) {
      return '北海道・札幌エリア';
    }
    return '現在地（GPS）';
  }

  /// 現在地からスポットまでの直線距離（km）を計算
  static double calculateDistanceKm({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    );
    return (distanceMeters / 1000.0 * 10).round() / 10.0;
  }

  /// 直線距離（km）から車でのおおよその所要時間（分）を算出
  /// 市街地・高速混合で平均時速35km〜40km＋信号・出入庫マージン10分を考慮
  static int estimateDriveMinutes(double distanceKm) {
    if (distanceKm <= 5) return max(10, (distanceKm * 2.5).round());
    if (distanceKm <= 20) return max(15, (distanceKm * 2.0).round());
    if (distanceKm <= 50) return max(30, (distanceKm * 1.5).round());
    return max(45, (distanceKm * 1.3).round());
  }
}
