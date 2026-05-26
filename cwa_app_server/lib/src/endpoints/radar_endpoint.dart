import 'dart:typed_data';

import 'package:serverpod/serverpod.dart';

import '../algorithm/dbz_analyzer.dart';
import '../config/radar_config.dart';
import '../generated/protocol.dart';
import '../services/radar_fetcher.dart';

/// 雷達相關 endpoint。
///
/// `getNearby(lat, lon)` 等同 cwa-tg-bot 的「查看現在位置」：
/// 依緯度挑站 → 抓 PNG → 投影 + dBZ 分析 → 回傳結構化結果。
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

    return NearbyRadarResult(
      ok: true,
      dbz: analysis.dbz,
      shortLabel: DbzAnalyzer.toShortLabel(analysis.dbz),
      humanText: DbzAnalyzer.toHumanText(analysis.dbz),
      stationName: station.name,
      imageTime: fetched.imageTime,
      pngBytes: ByteData.view(fetched.bytes!.buffer),
      userPxX: analysis.pxX,
      userPxY: analysis.pxY,
      inRange: analysis.inRange,
      isBlindZone: analysis.isBlindZone,
    );
  }
}
