import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/radar_config.dart';
import 'coord_projection.dart';

/// dBZ 分析結果。
class DbzAnalysis {
  /// 命中的 dBZ 值；如果取色完全對不上色表則為 null。
  final int? dbz;

  /// 觀測點是否落在影像範圍內（像素 0..3599）。
  final bool inRange;

  /// 是否為盲區（dbz == 0 — 通常表示資料缺失或站點極近邊緣）。
  final bool isBlindZone;

  /// 像素座標（除錯 / 前端標註用）。
  final double pxX;
  final double pxY;

  const DbzAnalysis({
    required this.dbz,
    required this.inRange,
    required this.isBlindZone,
    required this.pxX,
    required this.pxY,
  });
}

/// 雷達 PNG + 站點 + 觀測點 → dBZ 分析。
///
/// 演算法照搬自 cwa-tg-bot/services/radar_render.py 的 analyze_point_dbz
/// 與 match_dbz_from_color、dbz_to_human_text。
class DbzAnalyzer {
  /// 顏色 → dBZ 索引快查表。lazy 初始化以避免每次 lookup 重建。
  static final Map<int, int> _colorToDbz = _buildLookup();

  static Map<int, int> _buildLookup() {
    final m = <int, int>{};
    for (int i = 0; i < RadarConfig.dbzColorScale.length; i++) {
      final (r, g, b) = RadarConfig.dbzColorScale[i];
      m[_rgbKey(r, g, b)] = i;
    }
    return m;
  }

  static int _rgbKey(int r, int g, int b) => (r << 16) | (g << 8) | b;

  /// 像素 RGB → dBZ 值。
  ///
  /// 1. 完全相符 → 直接回傳 index
  /// 2. 找最接近的 dBZ 色（歐式距離平方），距離 <= 100 才接受；否則回 null
  ///    （避免把白色背景 / 海岸線等非雨色判讀成 dBZ）。
  static int? matchDbz(int r, int g, int b) {
    final key = _rgbKey(r, g, b);
    final exact = _colorToDbz[key];
    if (exact != null) return exact;

    int? nearestDbz;
    int? nearestDist;
    for (int i = 0; i < RadarConfig.dbzColorScale.length; i++) {
      final (cr, cg, cb) = RadarConfig.dbzColorScale[i];
      final dr = r - cr;
      final dg = g - cg;
      final db = b - cb;
      final dist = dr * dr + dg * dg + db * db;
      if (nearestDist == null || dist < nearestDist) {
        nearestDist = dist;
        nearestDbz = i;
      }
    }
    if (nearestDist != null && nearestDist <= 100) return nearestDbz;
    return null;
  }

  /// 解碼 PNG bytes，取觀測點像素，回傳 dBZ 分析。
  static DbzAnalysis analyzePoint({
    required Uint8List pngBytes,
    required RadarStation station,
    required double lat,
    required double lon,
  }) {
    final (pxX, pxY) = CoordProjection.latLonToPixel(
      centerLat: station.centerLat,
      centerLon: station.centerLon,
      lat: lat,
      lon: lon,
    );

    final size = RadarConfig.imageSize;
    if (pxX < 0 || pxX >= size || pxY < 0 || pxY >= size) {
      return DbzAnalysis(
        dbz: null,
        inRange: false,
        isBlindZone: false,
        pxX: pxX,
        pxY: pxY,
      );
    }

    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      return DbzAnalysis(
        dbz: null,
        inRange: true,
        isBlindZone: false,
        pxX: pxX,
        pxY: pxY,
      );
    }

    final x = pxX.round().clamp(0, size - 1);
    final y = pxY.round().clamp(0, size - 1);
    final pixel = decoded.getPixel(x, y);
    final r = pixel.r.toInt();
    final g = pixel.g.toInt();
    final b = pixel.b.toInt();

    final dbz = matchDbz(r, g, b);
    return DbzAnalysis(
      dbz: dbz,
      inRange: true,
      isBlindZone: dbz == 0,
      pxX: pxX,
      pxY: pxY,
    );
  }

  /// dBZ → 中文人類描述。完全照 cwa-tg-bot 的 dbz_to_human_text。
  static String toHumanText(int? dbz) {
    if (dbz == null || dbz <= 0) return '目前無明顯降雨';
    if (dbz < 15) return '雲系籠罩，可能微雨';
    if (dbz < 30) return '正在下雨';
    if (dbz < 45) return '雨勢明顯';
    return '強降雨';
  }

  /// dBZ → 簡短狀態（給 Hero 大字用）。
  static String toShortLabel(int? dbz) {
    if (dbz == null || dbz <= 0) return '沒下雨';
    if (dbz < 15) return '微雨';
    if (dbz < 30) return '小雨';
    if (dbz < 45) return '中雨';
    return '大雨';
  }
}
