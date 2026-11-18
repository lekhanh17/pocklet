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
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dayExpensesProvider(today));
          ref.invalidate(budgetOverviewProvider(month));
          ref.invalidate(last7DaysProvider);
          await ref.read(dayExpensesProvider(today).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _Header(today: today),
            const SizedBox(height: 16),
            AsyncView<List<Expense>>(
              value: expenses,
              onRetry: () => ref.invalidate(dayExpensesProvider(today)),
              builder: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TodaySummary(items: items),
                  const SizedBox(height: 16),
                  _TodayStrip(items: items),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AsyncView<BudgetOverview>(
              value: budget,
              onRetry: () => ref.invalidate(budgetOverviewProvider(month)),
              builder: (data) => _BudgetCard(overview: data, today: today),
            ),
            const SizedBox(height: 24),
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
// Dau trang: thu, ngay; tieu de; nut chu cai dau cua ten
// ---------------------------------------------------------------------------

class _Header extends ConsumerWidget {
  const _Header({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserNameProvider);
    final text = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatFullDay(today),
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              Text(
                'Hôm nay',
                style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Tài khoản',
          child: InkWell(
            customBorder: const CircleBorder(),
            // TODO(FR-04): mo man Tai khoan
            onTap: () => showComingSoon(context, 'Tài khoản'),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent,
              child: Text(
                initialOf(name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chi hom nay: tong tien, so khoan, so anh
// ---------------------------------------------------------------------------

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, e) => sum + e.amount);
    final photoCount = items.fold<int>(0, (sum, e) => sum + e.photos.length);
    final text = Theme.of(context).textTheme;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi hôm nay',
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            formatVnd(total),
            style: text.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${items.length} khoản · $photoCount ảnh',
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
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
      height: 210,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
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
    return SizedBox(
      width: 120,
      child: DashedBox(
        color: AppColors.accent,
        radius: 16,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // TODO(FR-10): mo man Camera
          onTap: () => showComingSoon(context, 'Camera'),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppColors.accent, size: 32),
                SizedBox(height: 8),
                Text(
                  'Chụp khoản mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
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
    final text = Theme.of(context).textTheme;

    return SizedBox(
      width: 140,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // TODO(FR-08): mo man Sua khoan chi
        onTap: () => showComingSoon(context, 'Sửa khoản chi'),
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
                      borderRadius: 16,
                    )
                  else
                    CategoryTile(category: category, borderRadius: 16),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: AmountChip(amount: expense.amount),
                  ),
                  if (expense.photos.length > 1)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: CountBadge(extra: expense.photos.length - 1),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              expense.note ?? category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              '${category.name} · ${formatTime(expense.spentAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: AppColors.textMuted),
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

Color _levelColor(BudgetLevel level) => switch (level) {
      BudgetLevel.normal => AppColors.accent,
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
    final text = Theme.of(context).textTheme;
    final total = overview.total;
    // TODO(FR-16): mo man Ngan sach thay vi chuyen tab
    void openBudget() => ref.read(tabIndexProvider.notifier).select(4);

    if (total == null) {
      return SectionCard(
        onTap: openBudget,
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chưa đặt ngân sách tháng ${overview.month.month}',
                style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
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
                  style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${total.percent}%',
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total.ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.border,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Đã chi ${formatVnd(total.spent)} / ${formatVnd(total.limit)}',
            style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(hint, style: text.bodyMedium),
          if (overview.alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${category.name} · $label ${line.percent}%',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
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
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '7 ngày qua',
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
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
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToday ? AppColors.accent : AppColors.border,
                width: isToday ? 2 : 1,
              ),
            ),
            child: cover != null
                ? PhotoThumb(photoId: cover, borderRadius: 0, showIcon: false)
                : Center(
                    child: Text(
                      '${day.date.day}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          weekdayShort(day.date),
          style: TextStyle(
            fontSize: 12,
            color: isToday ? AppColors.accent : AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          formatShort(day.total),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
