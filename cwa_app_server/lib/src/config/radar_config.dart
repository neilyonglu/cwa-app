/// 雷達相關常數：站點座標、dBZ 色碼表、區域邊界、投影參數。
///
/// 純資料，照搬自 cwa-tg-bot/config/settings.py，數值一字不漏。
class RadarStation {
  final String datasetId;
  final String name;
  final double centerLon;
  final double centerLat;

  const RadarStation({
    required this.datasetId,
    required this.name,
    required this.centerLon,
    required this.centerLat,
  });
}

class RadarConfig {
  // 雷達站
  static const stations = <String, RadarStation>{
    'north': RadarStation(
      datasetId: 'O-A0084-001',
      name: '北部(樹林)',
      centerLon: 121.400,
      centerLat: 25.000,
    ),
    'central': RadarStation(
      datasetId: 'O-A0084-002',
      name: '中部(南屯)',
      centerLon: 120.579,
      centerLat: 24.144,
    ),
    'south': RadarStation(
      datasetId: 'O-A0084-003',
      name: '南部(林園)',
      centerLon: 120.379,
      centerLat: 22.526,
    ),
  };

  // 區域判斷：依緯度分界
  static const regionBoundaryNorth = 24.6;
  static const regionBoundaryCentral = 23.3;

  // 影像 / 投影參數（O-A0084-xxx 系列固定）
  static const imageSize = 3600;
  static const imageCenterPx = 1800;
  static const pixelPerKm = 11.96;

  // 快取
  static const cacheTtlSeconds = 300;

  // CWA S3
  static const cwaS3BaseUrl =
      'https://cwaopendata.s3.ap-northeast-1.amazonaws.com/Observation';

  // 單站盲區時的互補站順序
  static const backupOrder = <String, List<String>>{
    'north': ['central', 'south'],
    'central': ['north', 'south'],
    'south': ['central', 'north'],
  };

  /// 給定緯度，回傳應使用的雷達站 key。
  static String stationKeyForLatitude(double lat) {
    if (lat > regionBoundaryNorth) return 'north';
    if (lat > regionBoundaryCentral) return 'central';
    return 'south';
  }

  /// dBZ 色碼表：index = dBZ 值，value = (R, G, B)。
  static const dbzColorScale = <(int, int, int)>[
    (0, 255, 255), (0, 236, 255), (0, 218, 255), (0, 200, 255), (0, 182, 255),
    (0, 163, 255), (0, 145, 255), (0, 127, 255), (0, 109, 255), (0, 91, 255),
    (0, 72, 255), (0, 54, 255), (0, 36, 255), (0, 18, 255), (0, 0, 255),
    (0, 255, 0), (0, 244, 0), (0, 233, 0), (0, 222, 0), (0, 211, 0),
    (0, 200, 0), (0, 190, 0), (0, 180, 0), (0, 170, 0), (0, 160, 0),
    (0, 150, 0), (51, 171, 0), (102, 192, 0), (153, 213, 0), (204, 234, 0),
    (255, 255, 0), (255, 244, 0), (255, 233, 0), (255, 222, 0), (255, 211, 0),
    (255, 200, 0), (255, 184, 0), (255, 168, 0), (255, 152, 0), (255, 136, 0),
    (255, 120, 0), (255, 96, 0), (255, 72, 0), (255, 48, 0), (255, 24, 0),
    (255, 0, 0), (244, 0, 0), (233, 0, 0), (222, 0, 0), (211, 0, 0),
    (200, 0, 0), (190, 0, 0), (180, 0, 0), (170, 0, 0), (160, 0, 0),
    (150, 0, 0), (171, 0, 51), (192, 0, 102), (213, 0, 153), (234, 0, 204),
    (255, 0, 255), (234, 0, 255), (213, 0, 255), (192, 0, 255), (171, 0, 255),
    (150, 0, 255),
  ];
}
