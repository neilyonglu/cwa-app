import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../algorithm/dbz_analyzer.dart';
import '../algorithm/radar_renderer.dart';
import '../config/radar_config.dart';
import '../generated/protocol.dart';
import '../services/gemini_analyst.dart';
import '../services/radar_fetcher.dart';

/// 雷達相關 endpoint。
///
/// `getNearby(lat, lon)` 等同 cwa-tg-bot 的「查看現在位置」：
///   1. 依緯度挑站
///   2. 抓 PNG（cached）
///   3. 投影 + dBZ 分析
///   4. 在 PNG 上畫紅點 + 裁切 450×450（觀測點置中）
///   5. 回傳結構化結果（含裁切後 PNG）
class RadarEndpoint extends Endpoint {
  Future<NearbyRadarResult> getNearby(
    Session session,
    double lat,
    double lon,
  ) async {
    final stationKey = RadarConfig.stationKeyForLatitude(lat);
    final station = RadarConfig.stations[stationKey]!;
    session.log(
      '[radar] getNearby($lat, $lon) → ${station.name} (${station.datasetId})',
    );

    final fetched = await RadarFetcher.fetch(session, station.datasetId);
    if (fetched.bytes == null) {
      return NearbyRadarResult(
        ok: false,
        shortLabel: '無資料',
        humanText: '目前無法取得雷達圖資',
        stationName: station.name,
        imageTime: '',
        pngBytes: ByteData(0),
        userPxX: 0,
        userPxY: 0,
        inRange: false,
        isBlindZone: false,
        errorMessage: '抓 CWA S3 失敗',
      );
    }

    final analysis = DbzAnalyzer.analyzePoint(
      pngBytes: fetched.bytes!,
      station: station,
      lat: lat,
      lon: lon,
    );

    session.log(
      '[radar] dbz=${analysis.dbz} px=(${analysis.pxX.toStringAsFixed(1)}, '
      '${analysis.pxY.toStringAsFixed(1)}) inRange=${analysis.inRange}',
    );

    // 標註 + 裁切（cwa-tg-bot parity）
    Uint8List finalPng = fetched.bytes!;
    double markPxX = analysis.pxX;
    double markPxY = analysis.pxY;

    if (analysis.inRange) {
      final rendered = RadarRenderer.markAndCrop(
        pngBytes: fetched.bytes!,
        pxX: analysis.pxX,
        pxY: analysis.pxY,
      );
      if (rendered != null) {
        finalPng = rendered.bytes;
        markPxX = rendered.userPxX;
        markPxY = rendered.userPxY;
      }
    }

    final humanText = DbzAnalyzer.toHumanText(analysis.dbz);

    // Gemini AI 分析（與 dBZ 分析平行不來，CWA fetch 已 cached，
    // 多這 1-2 秒可以接受；失敗回 null 不影響其他欄位）
    final aiAnalysis = await GeminiAnalyst.analyzeRainfall(
      session: session,
      location: '目前位置',
      timeStr: fetched.imageTime,
      basicDesc: humanText,
    );

    return NearbyRadarResult(
      ok: true,
      dbz: analysis.dbz,
      shortLabel: DbzAnalyzer.toShortLabel(analysis.dbz),
      humanText: humanText,
      stationName: station.name,
      imageTime: fetched.imageTime,
      pngBytes: ByteData.view(finalPng.buffer),
      // 紅點在「回傳的 PNG」內的座標（裁切後 = 通常 225, 225）。
      userPxX: markPxX,
      userPxY: markPxY,
      inRange: analysis.inRange,
      isBlindZone: analysis.isBlindZone,
      aiAnalysis: aiAnalysis,
    );
  }
}
