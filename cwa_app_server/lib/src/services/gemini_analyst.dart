import 'dart:io';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:serverpod/serverpod.dart';

/// Gemini 雨勢分析。
///
/// 對應 cwa-tg-bot/services/llm_rainfall.py：
///   - 把雷達 dBZ 描述丟給 Gemini，要 2 句繁中口語化建議
///   - 沒設 GEMINI_API_KEY 環境變數 → 直接回 null（endpoint 視為 aiAnalysis 欄位為 null）
///
/// 模型用 gemini-2.5-flash-lite（cwa-tg-bot 用的 gemini-3.1-flash-lite 在
/// google_generative_ai Dart SDK 還沒 expose，選最接近的快、便宜的）。
class GeminiAnalyst {
  static const _model = 'gemini-2.5-flash-lite';

  static GenerativeModel? _client;
  static bool _initFailed = false;

  static GenerativeModel? _getClient() {
    if (_initFailed) return null;
    if (_client != null) return _client;
    final apiKey = Platform.environment['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _initFailed = true;
      return null;
    }
    _client = GenerativeModel(model: _model, apiKey: apiKey);
    return _client;
  }

  /// 傳入位置 + 時間 + dBZ 強度文字描述，回傳 Gemini 寫的 2 句繁中說明。
  /// 失敗（沒 key、API 掛、超時）一律回 null，呼叫端自行 fallback。
  static Future<String?> analyzeRainfall({
    required Session session,
    required String location,
    required String timeStr,
    required String basicDesc,
  }) async {
    final client = _getClient();
    if (client == null) {
      session.log(
        '[gemini] GEMINI_API_KEY 未設定，跳過 AI 分析',
        level: LogLevel.warning,
      );
      return null;
    }

    final prompt =
        '''
你是台灣氣象雷達分析助理。根據以下雷達回波資料，用繁體中文寫出 2 句話的降雨說明。

規則：
- 只根據提供的雷達回波資料說明，不要推測或捏造其他資訊
- 不提紫外線、氣溫、濕度、空氣品質等雷達以外的數據
- 可根據降雨強度給出是否需要帶傘的建議
- 口語化、簡潔，不要有標題或符號

位置：$location
時間：$timeStr
雷達回波分析：$basicDesc
''';

    try {
      final response = await client
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 10));
      final text = response.text?.trim();
      if (text == null || text.isEmpty) return null;
      session.log('[gemini] ok (${text.length} chars)');
      return text;
    } catch (e) {
      session.log('[gemini] 分析失敗：$e', level: LogLevel.warning);
      return null;
    }
  }
}
