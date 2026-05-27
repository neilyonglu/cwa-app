// 投影演算法的健全性檢查。
//
// 拿 pyproj 在相同公式（球面 AEQD）下會產出的數值當參照，
// 容差設大（5-10 px）容納球體 vs 橢球體的微小差異。
//
// 跑法：
//   cd cwa_app_server && dart test test/algorithm/coord_projection_test.dart

import 'package:cwa_app_server/src/algorithm/coord_projection.dart';
import 'package:cwa_app_server/src/config/radar_config.dart';
import 'package:test/test.dart';

void main() {
  group('CoordProjection.latLonToPixel', () {
    test('站點本身投到影像中心 (1800, 1800)', () {
      final s = RadarConfig.stations['north']!;
      final (px, py) = CoordProjection.latLonToPixel(
        centerLat: s.centerLat,
        centerLon: s.centerLon,
        lat: s.centerLat,
        lon: s.centerLon,
      );
      expect(px, closeTo(1800.0, 0.01));
      expect(py, closeTo(1800.0, 0.01));
    });

    test('站點正北 1 度 → y 軸朝上、x 不動', () {
      // 樹林 (25, 121.4) → (26, 121.4)
      // 1° lat ≈ 111.32 km、11.96 px/km → 約 1331.4 px
      // 影像 y 軸朝下 → pxY = 1800 - 1331.4 = 468.6
      final s = RadarConfig.stations['north']!;
      final (px, py) = CoordProjection.latLonToPixel(
        centerLat: s.centerLat,
        centerLon: s.centerLon,
        lat: s.centerLat + 1.0,
        lon: s.centerLon,
      );
      expect(px, closeTo(1800.0, 1.0));
      expect(py, closeTo(468.6, 5.0));
    });

    test('站點正東 1 度 → x 軸朝右、y 略偏', () {
      // 樹林 (25, 121.4) → (25, 122.4)
      // 在緯度 25°、1° lon ≈ cos(25°) × 111.32 km ≈ 100.92 km
      // px ≈ 1800 + 100.92 × 11.96 ≈ 3007
      // AEQD 在大圓上等距 → y 會有極小往南的偏移（~4-5 px）
      final s = RadarConfig.stations['north']!;
      final (px, py) = CoordProjection.latLonToPixel(
        centerLat: s.centerLat,
        centerLon: s.centerLon,
        lat: s.centerLat,
        lon: s.centerLon + 1.0,
      );
      expect(px, closeTo(3007.0, 10.0));
      expect(py, closeTo(1800.0, 10.0));
    });

    test('台北車站 (25.0478, 121.5170) 應落在影像中央偏右上', () {
      // 樹林站約在台北車站西方 ~11.7 km、南方 ~5.3 km
      // → px ≈ 1800 + 11.7×11.96 = 1940、py ≈ 1800 - 5.3×11.96 = 1737
      final s = RadarConfig.stations['north']!;
      final (px, py) = CoordProjection.latLonToPixel(
        centerLat: s.centerLat,
        centerLon: s.centerLon,
        lat: 25.0478,
        lon: 121.5170,
      );
      expect(px, closeTo(1940.0, 15.0));
      expect(py, closeTo(1737.0, 15.0));
      // 一定在影像內
      expect(px, inInclusiveRange(0, RadarConfig.imageSize - 1));
      expect(py, inInclusiveRange(0, RadarConfig.imageSize - 1));
    });

    test('高雄市區 (22.6273, 120.3014) 對北部雷達會落在影像外（南部 ~265 km）', () {
      // 樹林站到高雄 ~265 km，遠超出 3600/2/11.96 ≈ 150 km 半徑
      // → px/py 任一會 < 0 或 >= 3600
      final s = RadarConfig.stations['north']!;
      final (px, py) = CoordProjection.latLonToPixel(
        centerLat: s.centerLat,
        centerLon: s.centerLon,
        lat: 22.6273,
        lon: 120.3014,
      );
      final outOfRange =
          px < 0 ||
          px >= RadarConfig.imageSize ||
          py < 0 ||
          py >= RadarConfig.imageSize;
      expect(
        outOfRange,
        isTrue,
        reason: 'expected out-of-range, got ($px, $py)',
      );
    });

    test('反對稱：點 P 從站點看的 (x,y)、互換站點與 P 後 (x,y) 應反號', () {
      // AEQD 是局部對稱的：以 A 為心看 B 投到 (x,y) ≈ 以 B 為心看 A 投到 (-x,-y)
      // 不會完全相等（球面 vs 平面差異），但短距離下接近。
      final a = (lat: 25.0, lon: 121.4);
      final b = (lat: 25.05, lon: 121.55);

      final (px1, py1) = CoordProjection.latLonToPixel(
        centerLat: a.lat,
        centerLon: a.lon,
        lat: b.lat,
        lon: b.lon,
      );
      final (px2, py2) = CoordProjection.latLonToPixel(
        centerLat: b.lat,
        centerLon: b.lon,
        lat: a.lat,
        lon: a.lon,
      );
      // (px - 1800) ≈ -(px - 1800) 互為相反
      expect(px1 - 1800, closeTo(-(px2 - 1800), 2.0));
      expect(py1 - 1800, closeTo(-(py2 - 1800), 2.0));
    });
  });
}
