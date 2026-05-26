import 'dart:math' as math;

import '../config/radar_config.dart';

/// WGS84 ↔ 雷達圖像素座標。
///
/// 演算法照搬自 cwa-tg-bot/services/radar_render.py 的 latlon_to_pixel，
/// 用 AEQD（Azimuthal Equidistant）投影手動實作，避免拉入 proj4dart。
class CoordProjection {
  /// WGS84 橢球體 semi-major axis（公尺）。pyproj 預設值。
  static const double _earthRadius = 6378137.0;

  /// 給定雷達站中心 + 觀測點 lat/lon，回傳像素座標 (px_x, px_y)。
  ///
  /// 雷達圖是 3600×3600，中心 1800 為站點本身，
  /// 每公里對應 [RadarConfig.pixelPerKm] 個像素。
  static (double, double) latLonToPixel({
    required double centerLat,
    required double centerLon,
    required double lat,
    required double lon,
  }) {
    final (x, y) = _aeqdProject(
      centerLat: centerLat,
      centerLon: centerLon,
      lat: lat,
      lon: lon,
    );
    final pxX =
        RadarConfig.imageCenterPx + (x / 1000.0) * RadarConfig.pixelPerKm;
    // 影像 y 軸朝下，地理 y 朝上 → 反向
    final pxY =
        RadarConfig.imageCenterPx - (y / 1000.0) * RadarConfig.pixelPerKm;
    return (pxX, pxY);
  }

  /// AEQD 投影：把 WGS84 lat/lon 投到以 (centerLat, centerLon) 為原點的
  /// 平面（單位：公尺）。
  static (double, double) _aeqdProject({
    required double centerLat,
    required double centerLon,
    required double lat,
    required double lon,
  }) {
    final cLat = _deg2rad(centerLat);
    final cLon = _deg2rad(centerLon);
    final pLat = _deg2rad(lat);
    final pLon = _deg2rad(lon);

    final cosC =
        math.sin(cLat) * math.sin(pLat) +
        math.cos(cLat) * math.cos(pLat) * math.cos(pLon - cLon);
    // clamp 避免浮點誤差讓 acos 拿到 1.0000001 之類
    final cosCClamped = cosC.clamp(-1.0, 1.0);
    final c = math.acos(cosCClamped);

    // 同點：return (0, 0) 避免除以 0
    if (c.abs() < 1e-12) return (0.0, 0.0);

    final k = c / math.sin(c);
    final x = _earthRadius * k * math.cos(pLat) * math.sin(pLon - cLon);
    final y =
        _earthRadius *
        k *
        (math.cos(cLat) * math.sin(pLat) -
            math.sin(cLat) * math.cos(pLat) * math.cos(pLon - cLon));
    return (x, y);
  }

  static double _deg2rad(double deg) => deg * math.pi / 180.0;
}
