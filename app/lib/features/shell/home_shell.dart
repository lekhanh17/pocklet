import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../calendar/calendar_screen.dart';
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          if (i == _captureIndex) {
            // TODO(FR-10): mo man Camera
            showComingSoon(context, 'Camera');
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
    );
  }
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.photo_camera, color: Colors.white),
    );
  }
}
