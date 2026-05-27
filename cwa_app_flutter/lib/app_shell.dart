import 'package:flutter/material.dart';

import 'features/home/home_screen.dart';
import 'theme/app_theme.dart';

/// 主框架：底部 4 個 tab。
/// 目前只有 Home 有實作，其餘為「敬請期待」占位，
/// 視覺先到位、之後各 tab 再依序開發。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec('Now', '現在', Icons.umbrella_outlined, Icons.umbrella_rounded),
    _TabSpec(
      'Radar',
      '雷達',
      Icons.satellite_alt_outlined,
      Icons.satellite_alt_rounded,
    ),
    _TabSpec('Route', '路徑', Icons.alt_route_outlined, Icons.alt_route_rounded),
    _TabSpec('Favorites', '喜愛', Icons.star_outline_rounded, Icons.star_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.bgDark,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          _ComingSoon(title: '雷達', emoji: '🛰️'),
          _ComingSoon(title: '路徑降雨', emoji: '🧭'),
          _ComingSoon(title: '我的地點', emoji: '★'),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        tabs: _tabs,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TabSpec {
  final String code;
  final String label;
  final IconData icon;
  final IconData iconActive;
  const _TabSpec(this.code, this.label, this.icon, this.iconActive);
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.tabs,
    required this.onChanged,
  });

  final int index;
  final List<_TabSpec> tabs;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: AppColors.strokeSoft, width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final t = tabs[i];
              final active = i == index;
              return Expanded(
                child: InkResponse(
                  onTap: () => onChanged(i),
                  radius: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? t.iconActive : t.icon,
                        color: active
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.label,
                        style: AppText.captionTab.copyWith(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title, required this.emoji});
  final String title;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: AppText.titleLg),
          const SizedBox(height: AppSpacing.sm),
          const Text('敬請期待', style: AppText.bodyMuted),
        ],
      ),
    );
  }
}
