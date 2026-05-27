import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:serverpod/serverpod.dart';

import '../config/radar_config.dart';

/// 抓 CWA S3 雷達 PNG + JSON metadata，附 in-memory cache。
///
/// 對應 cwa-tg-bot/services/radar_fetch.py，但用 Dart 重寫。
class RadarFetcher {
  static final Map<String, _CacheEntry> _cache = {};

  /// 從 CWA S3 抓指定資料集的 PNG。
  /// 回傳 (bytes, imageTime)；失敗時 bytes 為 null。
  static Future<({Uint8List? bytes, String imageTime})> fetch(
    Session session,
    String datasetId, {
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    final cached = _cache[datasetId];
    if (!forceRefresh &&
        cached != null &&
        now.difference(cached.fetchedAt).inSeconds <
            RadarConfig.cacheTtlSeconds) {
      session.log(
        '[radar_fetcher] cache hit $datasetId '
        '(age=${now.difference(cached.fetchedAt).inSeconds}s)',
      );
      return (bytes: cached.bytes, imageTime: cached.imageTime);
    }

    final imgUrl = '${RadarConfig.cwaS3BaseUrl}/$datasetId.png';
    final jsonUrl = '${RadarConfig.cwaS3BaseUrl}/$datasetId.json';

    try {
      session.log('[radar_fetcher] GET $imgUrl');
      final imgResp = await http.get(Uri.parse(imgUrl));
      if (imgResp.statusCode != 200) {
        session.log(
          '[radar_fetcher] PNG ${imgResp.statusCode} for $datasetId',
          level: LogLevel.warning,
        );
        return (bytes: null, imageTime: '');
      }
      final bytes = imgResp.bodyBytes;

      var imageTime = '未知時間';
      try {
        final jsonResp = await http.get(Uri.parse(jsonUrl));
        if (jsonResp.statusCode == 200) {
          final data = jsonDecode(jsonResp.body) as Map<String, dynamic>;
          final dt =
              ((data['cwaopendata'] as Map?)?['dataset'] as Map?)?['DateTime'];
          if (dt is String) {
            final parsed = DateTime.tryParse(dt);
            if (parsed != null) {
              // CWA 給的是 +08:00；DateTime.parse 會轉成 UTC（.hour 變成
              // 少 8 小時）。顯式 +8 還原台灣時間後再 format，避免顯示成
              // 「早上 8:56」這種看似 8 小時前的舊圖。
              final taipei = parsed.toUtc().add(const Duration(hours: 8));
              imageTime = _formatTime(taipei);
            }
          }
        }
      } catch (e) {
        session.log(
          '[radar_fetcher] metadata parse failed: $e',
          level: LogLevel.warning,
        );
      }

      _cache[datasetId] = _CacheEntry(bytes, imageTime, now);
      return (bytes: bytes, imageTime: imageTime);
    } catch (e) {
      session.log(
        '[radar_fetcher] S3 fetch failed: $e',
        level: LogLevel.error,
      );
      return (bytes: null, imageTime: '');
    }
  }

  static String _formatTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${pad(dt.month)}-${pad(dt.day)} '
        '${pad(dt.hour)}:${pad(dt.minute)}';
  }
}

class _CacheEntry {
  final Uint8List bytes;
  final String imageTime;
  final DateTime fetchedAt;
  const _CacheEntry(this.bytes, this.imageTime, this.fetchedAt);
}
