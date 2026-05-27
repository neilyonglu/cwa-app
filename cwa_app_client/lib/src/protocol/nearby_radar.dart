/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod_client/serverpod_client.dart' as _i1;
import 'dart:typed_data' as _i2;

/// GPS 雨勢查詢回傳結果（對應 cwa-tg-bot 的「查看現在位置」）。
abstract class NearbyRadarResult implements _i1.SerializableModel {
  NearbyRadarResult._({
    required this.ok,
    this.dbz,
    required this.shortLabel,
    required this.humanText,
    required this.stationName,
    required this.imageTime,
    required this.pngBytes,
    required this.userPxX,
    required this.userPxY,
    required this.inRange,
    required this.isBlindZone,
    this.errorMessage,
    this.aiAnalysis,
  });

  factory NearbyRadarResult({
    required bool ok,
    int? dbz,
    required String shortLabel,
    required String humanText,
    required String stationName,
    required String imageTime,
    required _i2.ByteData pngBytes,
    required double userPxX,
    required double userPxY,
    required bool inRange,
    required bool isBlindZone,
    String? errorMessage,
    String? aiAnalysis,
  }) = _NearbyRadarResultImpl;

  factory NearbyRadarResult.fromJson(Map<String, dynamic> jsonSerialization) {
    return NearbyRadarResult(
      ok: _i1.BoolJsonExtension.fromJson(jsonSerialization['ok']),
      dbz: jsonSerialization['dbz'] as int?,
      shortLabel: jsonSerialization['shortLabel'] as String,
      humanText: jsonSerialization['humanText'] as String,
      stationName: jsonSerialization['stationName'] as String,
      imageTime: jsonSerialization['imageTime'] as String,
      pngBytes: _i1.ByteDataJsonExtension.fromJson(
        jsonSerialization['pngBytes'],
      ),
      userPxX: (jsonSerialization['userPxX'] as num).toDouble(),
      userPxY: (jsonSerialization['userPxY'] as num).toDouble(),
      inRange: _i1.BoolJsonExtension.fromJson(jsonSerialization['inRange']),
      isBlindZone: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['isBlindZone'],
      ),
      errorMessage: jsonSerialization['errorMessage'] as String?,
      aiAnalysis: jsonSerialization['aiAnalysis'] as String?,
    );
  }

  /// 是否查詢成功（S3 抓得到 PNG）。
  bool ok;

  /// dBZ 值（0–65）。null 表示色表沒命中或落在影像外。
  int? dbz;

  /// 短標籤（Hero 大字）：沒下雨 / 微雨 / 小雨 / 中雨 / 大雨。
  String shortLabel;

  /// 人類描述（卡片內文）：目前無明顯降雨 / 正在下雨 / 強降雨 ...
  String humanText;

  /// 雷達站名稱（北部(樹林) / 中部(南屯) / 南部(林園)）。
  String stationName;

  /// 雷達圖時戳（CWA 提供，格式：YYYY-MM-DD HH:mm）。
  String imageTime;

  /// 原始 3600×3600 雷達 PNG bytes。前端用 Image.memory 顯示。
  _i2.ByteData pngBytes;

  /// 觀測點在 PNG 上的像素座標（前端做疊點 / 縮放標註用）。
  double userPxX;

  double userPxY;

  /// 觀測點是否落在雷達影像範圍內。
  bool inRange;

  /// 是否落在盲區（dBZ == 0，通常表資料缺）。
  bool isBlindZone;

  /// 失敗時的訊息（ok == false 才有用）。
  String? errorMessage;

  /// Gemini 寫的 2 句口語化分析。沒設 GEMINI_API_KEY / API 掛 → null。
  String? aiAnalysis;

  /// Returns a shallow copy of this [NearbyRadarResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  NearbyRadarResult copyWith({
    bool? ok,
    int? dbz,
    String? shortLabel,
    String? humanText,
    String? stationName,
    String? imageTime,
    _i2.ByteData? pngBytes,
    double? userPxX,
    double? userPxY,
    bool? inRange,
    bool? isBlindZone,
    String? errorMessage,
    String? aiAnalysis,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'NearbyRadarResult',
      'ok': ok,
      if (dbz != null) 'dbz': dbz,
      'shortLabel': shortLabel,
      'humanText': humanText,
      'stationName': stationName,
      'imageTime': imageTime,
      'pngBytes': pngBytes.toJson(),
      'userPxX': userPxX,
      'userPxY': userPxY,
      'inRange': inRange,
      'isBlindZone': isBlindZone,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (aiAnalysis != null) 'aiAnalysis': aiAnalysis,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _NearbyRadarResultImpl extends NearbyRadarResult {
  _NearbyRadarResultImpl({
    required bool ok,
    int? dbz,
    required String shortLabel,
    required String humanText,
    required String stationName,
    required String imageTime,
    required _i2.ByteData pngBytes,
    required double userPxX,
    required double userPxY,
    required bool inRange,
    required bool isBlindZone,
    String? errorMessage,
    String? aiAnalysis,
  }) : super._(
         ok: ok,
         dbz: dbz,
         shortLabel: shortLabel,
         humanText: humanText,
         stationName: stationName,
         imageTime: imageTime,
         pngBytes: pngBytes,
         userPxX: userPxX,
         userPxY: userPxY,
         inRange: inRange,
         isBlindZone: isBlindZone,
         errorMessage: errorMessage,
         aiAnalysis: aiAnalysis,
       );

  /// Returns a shallow copy of this [NearbyRadarResult]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  NearbyRadarResult copyWith({
    bool? ok,
    Object? dbz = _Undefined,
    String? shortLabel,
    String? humanText,
    String? stationName,
    String? imageTime,
    _i2.ByteData? pngBytes,
    double? userPxX,
    double? userPxY,
    bool? inRange,
    bool? isBlindZone,
    Object? errorMessage = _Undefined,
    Object? aiAnalysis = _Undefined,
  }) {
    return NearbyRadarResult(
      ok: ok ?? this.ok,
      dbz: dbz is int? ? dbz : this.dbz,
      shortLabel: shortLabel ?? this.shortLabel,
      humanText: humanText ?? this.humanText,
      stationName: stationName ?? this.stationName,
      imageTime: imageTime ?? this.imageTime,
      pngBytes: pngBytes ?? this.pngBytes.clone(),
      userPxX: userPxX ?? this.userPxX,
      userPxY: userPxY ?? this.userPxY,
      inRange: inRange ?? this.inRange,
      isBlindZone: isBlindZone ?? this.isBlindZone,
      errorMessage: errorMessage is String? ? errorMessage : this.errorMessage,
      aiAnalysis: aiAnalysis is String? ? aiAnalysis : this.aiAnalysis,
    );
  }
}
