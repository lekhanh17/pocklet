import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../calendar/calendar_screen.dart';
import '../capture/capture_flow.dart';
import '../placeholder/coming_soon_screen.dart';
import '../today/today_screen.dart';

/// Khung app voi thanh dieu huong 5 muc (dac ta muc 5):
/// Hôm nay, Lịch, nút Chụp ở giữa, Thống kê, Ngân sách.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _captureIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(tabIndexProvider);

    return Scaffold(
      // Noi dung cuon xuyen xuong duoi thanh tab mo
      extendBody: true,
      body: IndexedStack(
        index: index,
        children: const [
          TodayScreen(),
          CalendarScreen(),
          SizedBox.shrink(), // nut Chup khong co man rieng
          ComingSoonScreen(
            title: 'Thống kê',
            icon: Icons.pie_chart_outline,
            requirements: 'FR-20, FR-21',
          ),
          ComingSoonScreen(
            title: 'Ngân sách',
            icon: Icons.account_balance_wallet_outlined,
            requirements: 'FR-16 đến FR-18',
          ),
        ],
      ),
      bottomNavigationBar: _FrostedBar(
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          selectedIndex: index,
          onDestinationSelected: (i) {
            HapticFeedback.selectionClick();
            if (i == _captureIndex) {
              startCaptureFlow(context, ref);
              return;
            }
            ref.read(tabIndexProvider.notifier).select(i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Hôm nay',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month),
              label: 'Lịch',
            ),
            NavigationDestination(
              icon: _CaptureIcon(),
              label: 'Chụp',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline),
              selectedIcon: Icon(Icons.pie_chart),
              label: 'Thống kê',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Ngân sách',
            ),
          ],
        ),
      ),
    );
  }
}

/// Nen mo (frosted glass): parchment 80% + blur, ngan cach bang mot duong hairline.
class _FrostedBar extends StatelessWidget {
  const _FrostedBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.parchment.withAlpha(204),
            border: const Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Nut Chup: vien thuoc xanh, thao tac chinh cua app.
class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Icon(Icons.photo_camera, color: Colors.white, size: 20),
    );
  }
}