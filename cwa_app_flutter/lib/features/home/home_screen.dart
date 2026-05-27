import 'dart:typed_data';
import 'dart:ui';

import 'package:cwa_app_client/cwa_app_client.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../main.dart' show client;
import '../../theme/app_theme.dart';

/// 首頁 (Now) — 「現在這裡會不會下雨」一眼即懂。
///
/// 視覺結構（Apple Weather 風）：
///   1. 全版天空背景（CustomPainter，未來可換實拍）
///   2. 置中 hero（位置 + 大字狀態 + 條件）
///   3. 半透明玻璃卡片堆疊（摘要 / 未來一小時 / 雷達 / AI）
///
/// 資料流：
///   initState → 請權限 → Geolocator.getCurrentPosition
///              → client.radar.getNearby(lat, lon) → 更新 UI
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Phase { initial, locating, fetching, ready, error }

class _HomeScreenState extends State<HomeScreen> {
  _Phase _phase = _Phase.initial;
  String? _errorMessage;
  NearbyRadarResult? _result;
  Position? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.locating;
      _errorMessage = null;
    });

    try {
      // 1. 確認手機定位服務是否開啟
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('請先開啟手機定位服務');
        return;
      }

      // 2. 權限
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _fail('需要位置權限才能查雨勢');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _fail('位置權限已永久拒絕，請到系統設定打開');
        return;
      }

      // 3. 取 GPS
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = pos;
        _phase = _Phase.fetching;
      });

      // 4. 呼叫 server
      final res = await client.radar.getNearby(pos.latitude, pos.longitude);
      if (!mounted) return;

      if (!res.ok) {
        _fail(res.errorMessage ?? '伺服器回報失敗');
        return;
      }

      setState(() {
        _result = res;
        _phase = _Phase.ready;
      });
    } catch (e) {
      _fail('取得雨勢失敗：$e');
    }
  }

  void _fail(String msg) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.error;
      _errorMessage = msg;
    });
  }

  String get _heroLabel {
    switch (_phase) {
      case _Phase.ready:
        return _result?.shortLabel ?? '無資料';
      case _Phase.locating:
        return '定位中…';
      case _Phase.fetching:
        return '讀取中…';
      case _Phase.error:
        return '取得失敗';
      case _Phase.initial:
        return '—';
    }
  }

  String get _heroSub {
    switch (_phase) {
      case _Phase.ready:
        final t = _result?.humanText ?? '';
        final time = _result?.imageTime;
        if (time != null && time.isNotEmpty) {
          return '$t · 圖資 $time';
        }
        return t;
      case _Phase.error:
        return _errorMessage ?? '請稍後再試';
      default:
        return ' ';
    }
  }

  String get _heroLocation => '目前位置';

  /// GPS 座標（給 hero 下方小字顯示，方便驗證定位有沒有跑到對的地方）。
  /// TODO: 接 reverse geocoding 後改成「信義區」「內湖區」這種行政區名。
  String? get _heroCoords {
    final p = _position;
    if (p == null) return null;
    return '${p.latitude.toStringAsFixed(4)}°N, ${p.longitude.toStringAsFixed(4)}°E';
  }

  Uint8List? get _pngBytes {
    final pb = _result?.pngBytes;
    if (pb == null || pb.lengthInBytes == 0) return null;
    return Uint8List.view(pb.buffer, pb.offsetInBytes, pb.lengthInBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.skyBottom,
      body: Stack(
        children: [
          const _SkyBackground(),
          const _BottomFade(),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _Hero(
                      location: _heroLocation,
                      coords: _heroCoords,
                      label: _heroLabel,
                      sub: _heroSub,
                      onRetry: _phase == _Phase.error ? _load : null,
                    ),
                    const SizedBox(height: 28),
                    _SummaryCard(
                      humanText: _phase == _Phase.ready
                          ? _result?.humanText
                          : null,
                    ),
                    const SizedBox(height: 12),
                    const _HourlyCard(),
                    const SizedBox(height: 12),
                    _RadarCard(
                      pngBytes: _pngBytes,
                      imageTime: _result?.imageTime,
                      stationName: _result?.stationName,
                      userPxX: _result?.userPxX,
                      userPxY: _result?.userPxY,
                      inRange: _result?.inRange ?? false,
                      isLoading:
                          _phase == _Phase.locating ||
                          _phase == _Phase.fetching,
                    ),
                    const SizedBox(height: 12),
                    const _AiCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// 天空背景：垂直漸層 + 太陽光暈 + 多層雲
// ─────────────────────────────────────────────────────────
class _SkyBackground extends StatelessWidget {
  const _SkyBackground();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.skyTop,
              AppColors.skyMid,
              AppColors.skyDeep,
              AppColors.skyBottom,
            ],
            stops: [0.0, 0.38, 0.72, 1.0],
          ),
        ),
        child: CustomPaint(painter: _CloudsPainter()),
      ),
    );
  }
}

class _CloudsPainter extends CustomPainter {
  const _CloudsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 太陽光暈（右上）
    final sunCenter = Offset(w * 0.82, h * 0.07);
    final sunHalo = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.35, 1.0],
          ).createShader(
            Rect.fromCircle(center: sunCenter, radius: w * 0.6),
          );
    canvas.drawCircle(sunCenter, w * 0.6, sunHalo);

    // 太陽核心
    canvas.drawCircle(
      sunCenter,
      28,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );

    // 高空細雲（前景，最白）
    final foreClouds = <_Cloud>[
      _Cloud(0.15, 0.10, 110, 32, 0.55, 0.35),
      _Cloud(0.50, 0.14, 150, 22, 0.50, 0.32),
      _Cloud(0.85, 0.20, 90, 28, 0.50, 0.30),
      _Cloud(0.30, 0.22, 130, 38, 0.45, 0.28),
      _Cloud(0.65, 0.27, 110, 30, 0.45, 0.28),
      _Cloud(0.10, 0.32, 140, 40, 0.40, 0.26),
      _Cloud(0.78, 0.36, 100, 32, 0.40, 0.24),
      _Cloud(0.45, 0.40, 170, 48, 0.32, 0.22),
    ];
    for (final c in foreClouds) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: c.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c.blur);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.x * w, c.y * h),
          width: c.r * c.aspect * 4,
          height: c.r,
        ),
        p,
      );
    }

    // 後景遠雲（淡）
    final farClouds = <_Cloud>[
      _Cloud(0.20, 0.18, 60, 16, 0.25, 0.30),
      _Cloud(0.55, 0.30, 80, 18, 0.22, 0.28),
      _Cloud(0.90, 0.45, 70, 20, 0.20, 0.26),
    ];
    for (final c in farClouds) {
      final p = Paint()
        ..color = Colors.white.withValues(alpha: c.alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, c.blur);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(c.x * w, c.y * h),
          width: c.r * c.aspect * 4,
          height: c.r,
        ),
        p,
      );
    }

    // 邊角微 vignette
    final vignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.18),
        ],
        stops: const [0.7, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _Cloud {
  final double x;
  final double y;
  final double r;
  final double blur;
  final double alpha;
  final double aspect;
  const _Cloud(this.x, this.y, this.r, this.blur, this.alpha, this.aspect);
}

class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppColors.skyBottom.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero({
    required this.location,
    required this.label,
    required this.sub,
    this.coords,
    this.onRetry,
  });

  final String location;
  final String? coords;
  final String label;
  final String sub;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '我的位置',
          style: AppText.heroLabel.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Text(location, style: AppText.heroLocation),
        if (coords != null) ...[
          const SizedBox(height: 2),
          Text(
            coords!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.55),
              letterSpacing: 0.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Text(label, style: AppText.heroNumber, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            sub,
            style: AppText.heroCondition,
            textAlign: TextAlign.center,
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 16,
            ),
            label: const Text(
              '重試',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// 玻璃卡（共用容器）
// ─────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  const _GlassCard({
    this.icon,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  final IconData? icon;
  final String title;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              border: Border.all(color: AppColors.glassBorder, width: 0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  height: 0.5,
                  color: AppColors.glassDivider,
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Summary card
// ─────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({this.humanText});
  final String? humanText;

  @override
  Widget build(BuildContext context) {
    final text = humanText ?? '正在抓取雷達資料…';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassWhite,
              border: Border.all(color: AppColors.glassBorder, width: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Hourly card（mock，下一輪再串）
// ─────────────────────────────────────────────────────────
class _HourlyCard extends StatelessWidget {
  const _HourlyCard();

  @override
  Widget build(BuildContext context) {
    final slots = const [
      _Slot('現在', 0.05, AppColors.dbzNone, '0'),
      _Slot('+10', 0.12, AppColors.dbz10, '0.2'),
      _Slot('+20', 0.38, AppColors.dbz20, '2'),
      _Slot('+30', 0.72, AppColors.dbz30, '8'),
      _Slot('+40', 0.85, AppColors.dbz40, '14'),
      _Slot('+50', 0.55, AppColors.dbz30, '5'),
    ];

    return _GlassCard(
      icon: Icons.access_time_rounded,
      title: '未來一小時雨勢（推估，待接 API）',
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              height: 56,
              child: CustomPaint(
                size: const Size(double.infinity, 56),
                painter: _HourlyCurvePainter(
                  values: slots.map((s) => s.intensity).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: slots.map((s) {
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      s.time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _RainDrop(color: s.color),
                    const SizedBox(height: 6),
                    Text(
                      s.mmHr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          Text(
            '單位：mm/hr',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.5),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RainDrop extends StatelessWidget {
  const _RainDrop({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isNone = color == AppColors.dbzNone;
    return SizedBox(
      width: 18,
      height: 18,
      child: Icon(
        isNone ? Icons.cloud_outlined : Icons.water_drop_rounded,
        size: 16,
        color: isNone ? Colors.white.withValues(alpha: 0.7) : color,
      ),
    );
  }
}

class _Slot {
  final String time;
  final double intensity;
  final Color color;
  final String mmHr;
  const _Slot(this.time, this.intensity, this.color, this.mmHr);
}

class _HourlyCurvePainter extends CustomPainter {
  const _HourlyCurvePainter({required this.values});
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final stepX = w / (values.length - 1);
    final pts = <Offset>[
      for (int i = 0; i < values.length; i++)
        Offset(stepX * i, h - values[i].clamp(0.0, 1.0) * (h - 6) - 3),
    ];

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final cp1 = Offset((p0.dx + p1.dx) / 2, p0.dy);
      final cp2 = Offset((p0.dx + p1.dx) / 2, p1.dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _HourlyCurvePainter old) => old.values != values;
}

// ─────────────────────────────────────────────────────────
// Radar card — 接 NearbyRadarResult
// ─────────────────────────────────────────────────────────
class _RadarCard extends StatelessWidget {
  const _RadarCard({
    this.pngBytes,
    this.imageTime,
    this.stationName,
    this.userPxX,
    this.userPxY,
    this.inRange = false,
    this.isLoading = false,
  });

  /// CWA O-A0084-xxx 雷達圖固定為 3600×3600 px。
  /// 把 server 回的 userPxX/userPxY 從這個座標系轉到顯示尺寸用。
  static const _radarPxSize = 3600.0;

  final Uint8List? pngBytes;
  final String? imageTime;
  final String? stationName;
  final double? userPxX;
  final double? userPxY;
  final bool inRange;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final title = (imageTime != null && imageTime!.isNotEmpty)
        ? '雷達 · $imageTime'
        : '雷達 · LIVE';

    return _GlassCard(
      icon: Icons.satellite_alt_rounded,
      title: title,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1, // CWA PNG 是 3600x3600 正方
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;
                  final showDot =
                      pngBytes != null &&
                      inRange &&
                      userPxX != null &&
                      userPxY != null;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (pngBytes != null)
                        Image.memory(
                          pngBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        )
                      else
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xFF15233F)),
                          child: CustomPaint(painter: _RadarPainter()),
                        ),
                      if (isLoading)
                        Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          alignment: Alignment.center,
                          child: const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
                        ),
                      if (showDot)
                        Positioned(
                          // -14 把 28px dot 的中心對齊到 userPx 點
                          left: userPxX! / _radarPxSize * w - 14,
                          top: userPxY! / _radarPxSize * h - 14,
                          child: const _UserLocationDot(),
                        ),
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _LiveDot(),
                              SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (stationName != null && stationName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.radar_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 6),
                Text(
                  '觀測站 $stationName',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Spacer(),
                if (userPxX != null && userPxY != null)
                  Text(
                    'px (${userPxX!.toStringAsFixed(0)}, '
                    '${userPxY!.toStringAsFixed(0)})',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.danger,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 我的位置在雷達上的紅點：外光暈（透明紅）+ 紅心（白邊）。
/// 對應 cwa-tg-bot/services/radar_render.py 的 mark_location 一顆紅點。
class _UserLocationDot extends StatelessWidget {
  const _UserLocationDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger.withValues(alpha: 0.20),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.danger,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6;
    for (double x = 0; x < w; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 0; y < h; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────
// AI card（mock，下一輪再接 Gemini endpoint）
// ─────────────────────────────────────────────────────────
class _AiCard extends StatelessWidget {
  const _AiCard();

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 分析（待接 Gemini）',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '此處將顯示 Gemini 根據當前 dBZ 強度 + 周邊雨帶趨勢產生的口語化建議。',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.umbrella_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '尚未接 endpoint',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
