import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/radar_config.dart';

/// 雷達圖標註 + 裁切。
///
/// 對應 cwa-tg-bot/services/radar_render.py 的 mark_location：
///   1. 在 (pxX, pxY) 畫紅點（紅心 + 白邊）
///   2. 以 (pxX, pxY) 為中心裁切 [cropSize]×[cropSize]，若靠邊界則 clamp
///
/// 比直接回 3600×3600 PNG 好的地方：
///   - 流量小 95%（1.3 MB → ~50 KB）
///   - 使用者永遠在影像中央，肉眼易判讀
///   - 紅點 baked 進影像，client 不用算座標換算
class RadarRenderer {
  /// cwa-tg-bot 設定：CROP_SIZE = 450。
  static const cropSize = 450;

  /// 紅點半徑（px，於 3600×3600 原圖座標系）。
  /// 比 cwa-tg-bot 的 3 大一點，給現代手機螢幕看比較清楚。
  static const _markerRadius = 5;

  /// 白邊厚度。
  static const _outlineWidth = 2;

  /// 在 PNG 上畫紅點 + 裁切 450×450（觀測點置中或靠邊 clamp）。
  ///
  /// 回傳：
  ///   - bytes：裁切後的 PNG bytes
  ///   - userPxX / userPxY：紅點在「裁切後影像」中的座標
  ///     （一般 = cropSize/2 = 225；靠雷達邊緣時不一定）
  ///
  /// 失敗（PNG 解碼掛、觀測點超出原圖範圍）回傳 null。
  static ({Uint8List bytes, double userPxX, double userPxY})? markAndCrop({
    required Uint8List pngBytes,
    required double pxX,
    required double pxY,
  }) {
    final size = RadarConfig.imageSize;
    if (pxX < 0 || pxX >= size || pxY < 0 || pxY >= size) return null;

    final image = img.decodePng(pngBytes);
    if (image == null) return null;

    final cx = pxX.round().clamp(0, size - 1);
    final cy = pxY.round().clamp(0, size - 1);

    // 白邊（先畫大圓）
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: _markerRadius + _outlineWidth,
      color: img.ColorRgb8(255, 255, 255),
    );
    // 紅心（蓋在白邊上）
    img.fillCircle(
      image,
      x: cx,
      y: cy,
      radius: _markerRadius,
      color: img.ColorRgb8(255, 0, 0),
    );

    // 裁切（cwa-tg-bot 演算法照搬）
    final half = cropSize ~/ 2;
    final left = (cx - half).clamp(0, size - cropSize);
    final top = (cy - half).clamp(0, size - cropSize);

    final cropped = img.copyCrop(
      image,
      x: left,
      y: top,
      width: cropSize,
      height: cropSize,
    );

    final encoded = img.encodePng(cropped);

    return (
      bytes: Uint8List.fromList(encoded),
      userPxX: (cx - left).toDouble(),
      userPxY: (cy - top).toDouble(),
    );
  }
}
