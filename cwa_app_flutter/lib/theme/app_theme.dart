import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 設計 token：色彩 / 字級 / 間距 / 圓角。
/// 全 app 共用，畫面內不可硬寫 hex。
class AppColors {
  // 底層
  static const bgDark = Color(0xFF0B1220);
  static const bgGradientTop = Color(0xFF111B36);
  static const bgGradientBottom = Color(0xFF0B1220);

  // surface 層
  static const surface = Color(0xFF131C36);
  static const surfaceElevated = Color(0xFF1A2547);
  static const surfaceMuted = Color(0xFF0F1730);
  static const stroke = Color(0xFF24305A);
  static const strokeSoft = Color(0xFF1B2547);

  // 文字
  static const textPrimary = Color(0xFFE8ECFF);
  static const textSecondary = Color(0xFF9AA4CC);
  static const textTertiary = Color(0xFF5B6593);

  // 品牌 / 語意
  static const primary = Color(0xFF4FA3FF);
  static const primarySoft = Color(0xFF1D3A66);
  static const accent = Color(0xFF7DD3FC);
  static const warning = Color(0xFFFFB454);
  static const danger = Color(0xFFFF6B6B);
  static const success = Color(0xFF4ADE80);

  // Sky / glass（iOS Weather 風格）
  static const skyTop = Color(0xFF7CB4E8);
  static const skyMid = Color(0xFF4E84BE);
  static const skyDeep = Color(0xFF2A4F82);
  static const skyBottom = Color(0xFF13294A);
  static const glassWhite = Color(0x14FFFFFF); // 8% white
  static const glassBorder = Color(0x2EFFFFFF); // 18% white
  static const glassDivider = Color(0x1FFFFFFF); // 12% white

  // dBZ 色階（對應 CWA 雷達色表，簡化版）
  static const dbzNone = Color(0xFF1A2547);
  static const dbz10 = Color(0xFF3E8DE0);
  static const dbz20 = Color(0xFF2EC4B6);
  static const dbz30 = Color(0xFFFFD23F);
  static const dbz40 = Color(0xFFFF8A3D);
  static const dbz50 = Color(0xFFFF4D6D);
  static const dbz60 = Color(0xFFB349E0);
}

class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const pill = 999.0;
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class AppText {
  // hero number：狀態大字（沒下雨 / 中雨）。縮小自原本 80。
  static const heroNumber = TextStyle(
    fontSize: 54,
    fontWeight: FontWeight.w300,
    height: 1.05,
    letterSpacing: -1,
    color: Colors.white,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const heroLocation = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w400,
    height: 1.15,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const heroCondition = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const heroLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: Color(0xFFD8E2F2),
    letterSpacing: 0.5,
  );

  // hero：用於頂部大狀態
  static const hero = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.5,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const titleLg = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const titleMd = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const bodyMuted = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const captionTab = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.4,
  );

  static const numeric = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    color: AppColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    // Inter（英數）+ Noto Sans TC（中文 fallback）。
    // 全 app 透過 textTheme 繼承：所有沒指定 fontFamily 的 TextStyle
    // （含 AppText.* 與畫面內 inline TextStyle）merge 後都吃到 Inter，
    // 遇中文字自動 fallback 到 Noto Sans TC。
    final notoTc = GoogleFonts.notoSansTc().fontFamily;
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
      fontFamilyFallback: notoTc != null ? [notoTc] : null,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bgDark,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 22),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }

  static SystemUiOverlayStyle get systemOverlay => const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgDark,
    systemNavigationBarIconBrightness: Brightness.light,
  );
}
