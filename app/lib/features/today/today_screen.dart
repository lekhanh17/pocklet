import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coming_soon.dart';
import '../../core/date_utils.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/budget.dart';
import '../../models/calendar.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/photo_thumb.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_card.dart';

/// Man Hôm nay (dac ta muc 5.1, FR-19).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final month = monthOf(today);
    final expenses = ref.watch(dayExpensesProvider(today));
    final budget = ref.watch(budgetOverviewProvider(month));
    final week = ref.watch(last7DaysProvider);

    return SafeArea(
      child: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(dayExpensesProvider(today));
          ref.invalidate(budgetOverviewProvider(month));
          ref.invalidate(last7DaysProvider);
          await ref.read(dayExpensesProvider(today).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl,
          ),
          children: [
            _Header(today: today),
            const SizedBox(height: AppSpacing.lg),
            AsyncView<List<Expense>>(
              value: expenses,
              onRetry: () => ref.invalidate(dayExpensesProvider(today)),
              builder: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TodaySummary(items: items),
                  const SizedBox(height: AppSpacing.md),
                  _TodayStrip(items: items),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AsyncView<BudgetOverview>(
              value: budget,
              onRetry: () => ref.invalidate(budgetOverviewProvider(month)),
              builder: (data) => _BudgetCard(overview: data, today: today),
            ),
            const SizedBox(height: AppSpacing.xl),
            AsyncView<List<CalendarDay>>(
              value: week,
              onRetry: () => ref.invalidate(last7DaysProvider),
              builder: (days) => _Last7Days(days: days, today: today),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dau trang: thu, ngay; tieu de lon; nut tron chu cai dau cua ten
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserNameProvider);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatFullDay(today),
                style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text('Hôm nay', style: AppText.displayMd),
            ],
          ),
        ),
        // Nut tron 44px tren nen chip trong suot
        Pressable(
          semanticLabel: 'Tài khoản',
          // TODO(FR-04): mo man Tai khoan
          onTap: () => showComingSoon(context, 'Tài khoản'),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.chipTranslucent,
              shape: BoxShape.circle,
            ),
            child: Text(initialOf(name), style: AppText.bodyStrong),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chi hom nay: the toi, tong tien lon, so khoan, so anh
// ---------------------------------------------------------------------------

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, e) => sum + e.amount);
    final photoCount = items.fold<int>(0, (sum, e) => sum + e.photos.length);

    return SectionCard(
      dark: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi hôm nay',
            style: AppText.captionStrong.copyWith(color: AppColors.bodyMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatVnd(total),
            style: AppText.displayLg.copyWith(color: AppColors.bodyOnDark),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${items.length} khoản · $photoCount ảnh',
            style: AppText.caption.copyWith(color: AppColors.bodyMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dai anh hom nay: o "Chup khoan moi", roi the anh moi nhat truoc
// ---------------------------------------------------------------------------

class _TodayStrip extends ConsumerWidget {
  const _TodayStrip({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <int, ExpenseCategory>{};

    return SizedBox(
      height: 214,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == 0) return const _CaptureTile();
          final expense = items[index - 1];
          return _ExpenseCard(
            expense: expense,
            category: categories[expense.categoryId] ?? ExpenseCategory.unknown,
          );
        },
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      // TODO(FR-10): mo man Camera
      onTap: () => showComingSoon(context, 'Camera'),
      child: SizedBox(
        width: 120,
        child: DashedBox(
          color: AppColors.primary,
          radius: AppRadius.lg,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Chụp khoản mới',
                  textAlign: TextAlign.center,
                  style: AppText.captionStrong.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.expense, required this.category});

  final Expense expense;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      // TODO(FR-08): mo man Sua khoan chi
      onTap: () => showComingSoon(context, 'Sửa khoản chi'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (expense.hasPhotos)
                    PhotoThumb(
                      photoId: expense.photos.first.id,
                      isReceipt: expense.photos.first.isReceipt,
                      borderRadius: AppRadius.lg,
                    )
                  else
                    CategoryTile(category: category, borderRadius: AppRadius.lg),
                  Positioned(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                    child: AmountChip(amount: expense.amount),
                  ),
                  if (expense.photos.length > 1)
                    Positioned(
                      right: AppSpacing.xs,
                      top: AppSpacing.xs,
                      child: CountBadge(extra: expense.photos.length - 1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              expense.note ?? category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.captionStrong,
            ),
            const SizedBox(height: 2),
            Text(
              '${category.name} · ${formatTime(expense.spentAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.finePrint.copyWith(color: AppColors.inkMuted48),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ngan sach thang (FR-16, FR-18, BR-04)
// ---------------------------------------------------------------------------

/// Mau trang thai: binh thuong dung ink (khong phai mau tuong tac).
Color _levelColor(BudgetLevel level) => switch (level) {
      BudgetLevel.normal => AppColors.ink,
      BudgetLevel.warning => AppColors.warning,
      BudgetLevel.over => AppColors.danger,
    };

class _BudgetCard extends ConsumerWidget {
  const _BudgetCard({required this.overview, required this.today});

  final BudgetOverview overview;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <int, ExpenseCategory>{};
    final total = overview.total;
    // TODO(FR-16): mo man Ngan sach thay vi chuyen tab
    void openBudget() => ref.read(tabIndexProvider.notifier).select(4);

    if (total == null) {
      return SectionCard(
        onTap: openBudget,
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Chưa đặt ngân sách tháng ${overview.month.month}',
                style: AppText.bodyStrong,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      );
    }

    final color = _levelColor(total.level);
    final left = overview.daysLeftAfter(today);
    final daily = overview.dailyAllowance(today);
    final String hint;
    if (total.remaining < 0) {
      hint = 'Đã vượt ${formatVnd(-total.remaining)}';
    } else if (daily == null || left <= 0) {
      hint = 'Còn ${formatVnd(total.remaining)} cho hôm nay';
    } else {
      hint = 'Còn ${formatVnd(total.remaining)} · nên chi '
          '${formatVnd(daily)}/ngày cho $left ngày còn lại';
    }

    return SectionCard(
      onTap: openBudget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngân sách tháng ${overview.month.month}',
                  style: AppText.tagline,
                ),
              ),
              Text(
                '${total.percent}%',
                style: AppText.tagline.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xxs),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total.ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Đã chi ${formatVnd(total.spent)} / ${formatVnd(total.limit)}',
            style: AppText.caption.copyWith(color: AppColors.inkMuted48),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(hint, style: AppText.caption),
          if (overview.alerts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final line in overview.alerts)
                  _AlertChip(
                    line: line,
                    category: categories[line.categoryId] ?? ExpenseCategory.unknown,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({required this.line, required this.category});

  final BudgetLine line;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(line.level);
    final label = line.level == BudgetLevel.over ? 'vượt' : 'sắp hết';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '${category.name} · $label ${line.percent}%',
            style: AppText.finePrint.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7 ngay qua: o co anh hien anh, duoi la tong tien, hom nay vien xanh
// ---------------------------------------------------------------------------

class _Last7Days extends ConsumerWidget {
  const _Last7Days({required this.days, required this.today});

  final List<CalendarDay> days;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('7 ngày qua', style: AppText.tagline),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Pressable(
                    onTap: () => openDayInCalendar(ref, day.date),
                    child: _WeekCell(day: day, isToday: isSameDay(day.date, today)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekCell extends StatelessWidget {
  const _WeekCell({required this.day, required this.isToday});

  final CalendarDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final cover = day.coverPhotoId;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 0.8,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: isToday ? AppColors.primaryFocus : AppColors.hairline,
                width: isToday ? 2 : 1,
              ),
            ),
            child: cover != null
                ? PhotoThumb(photoId: cover, borderRadius: 0, showIcon: false)
                : Center(
                    child: Text(
                      '${day.date.day}',
                      style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          weekdayShort(day.date),
          style: AppText.finePrint.copyWith(
            color: isToday ? AppColors.primary : AppColors.inkMuted48,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          formatShort(day.total),
          style: AppText.finePrint.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
