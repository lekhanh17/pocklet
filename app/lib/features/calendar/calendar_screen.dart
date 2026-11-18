import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coming_soon.dart';
import '../../core/date_utils.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/calendar.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/photo_thumb.dart';
import '../photo_viewer/photo_viewer_screen.dart';

/// Man Lịch (dac ta muc 5.1, FR-13 den FR-15).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final monthData = ref.watch(calendarMonthProvider(month));

    void previous() => showCalendarMonth(ref, DateTime(month.year, month.month - 1));
    void next() => showCalendarMonth(ref, DateTime(month.year, month.month + 1));

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(calendarMonthProvider(month));
          ref.invalidate(dayExpensesProvider(ref.read(selectedDateProvider)));
          await ref.read(calendarMonthProvider(month).future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _CalendarHeader(
              month: month,
              data: monthData.valueOrNull,
              onPrevious: previous,
              onNext: next,
            ),
            const SizedBox(height: 8),
            const Center(child: _ViewModeSwitch()),
            const SizedBox(height: 12),
            // Vuot ngang luoi de doi thang
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -250) next();
                if (velocity > 250) previous();
              },
              child: AsyncView<CalendarMonth>(
                value: monthData,
                loadingHeight: 360,
                onRetry: () => ref.invalidate(calendarMonthProvider(month)),
                builder: (data) => _MonthGrid(month: month, data: data),
              ),
            ),
            const SizedBox(height: 20),
            const _DayDetail(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dau trang: thang, tong thang, so ngay co anh; nut tim
// ---------------------------------------------------------------------------

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.month,
    required this.data,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final CalendarMonth? data;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final summary = data == null
        ? ' '
        : '${formatVnd(data!.total)} · ${data!.daysWithPhoto} ngày có ảnh';

    return Row(
      children: [
        IconButton(
          tooltip: 'Tháng trước',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                formatMonth(month),
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                summary,
                style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          tooltip: 'Tìm kiếm',
          // TODO(FR-23): mo man Tim kiem
          onPressed: () => showComingSoon(context, 'Tìm kiếm'),
          icon: const Icon(Icons.search),
        ),
      ],
    );
  }
}

class _ViewModeSwitch extends ConsumerWidget {
  const _ViewModeSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);

    return SegmentedButton<CalendarViewMode>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: CalendarViewMode.photo,
          icon: Icon(Icons.photo_outlined),
          label: Text('Ảnh'),
        ),
        ButtonSegment(
          value: CalendarViewMode.amount,
          icon: Icon(Icons.payments_outlined),
          label: Text('Số tiền'),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) =>
          ref.read(calendarViewModeProvider.notifier).set(selection.first),
    );
  }
}

// ---------------------------------------------------------------------------
// Luoi ngay: 7 cot T2-CN
// ---------------------------------------------------------------------------

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.month, required this.data});

  final DateTime month;
  final CalendarMonth data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDateProvider);
    final mode = ref.watch(calendarViewModeProvider);
    final today = dateOnly(DateTime.now());
    final byDay = data.byDay;

    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final count = daysInMonth(month.year, month.month);
    final cellCount = ((leading + count) / 7).ceil() * 7;

    return Column(
      children: [
        Row(
          children: [
            for (final name in weekdayShortNames)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (context, i) {
            final dayNumber = i - leading + 1;
            if (dayNumber < 1 || dayNumber > count) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, dayNumber);
            return _DayCell(
              date: date,
              info: byDay[dayNumber],
              mode: mode,
              isToday: isSameDay(date, today),
              isSelected: isSameDay(date, selected),
              isFuture: date.isAfter(today),
              onTap: () => ref.read(selectedDateProvider.notifier).select(date),
            );
          },
        ),
      ],
    );
  }
}

/// Muc to mau cho kieu xem So tien: duoi 100k, 200k, 400k, tu 400k.
int _amountLevel(int total) {
  if (total < 100000) return 1;
  if (total < 200000) return 2;
  if (total < 400000) return 3;
  return 4;
}

const _amountAlpha = [0, 40, 90, 160, 230];

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.info,
    required this.mode,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;
  final CalendarDay? info;
  final CalendarViewMode mode;
  final bool isToday;
  final bool isSelected;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final day = info;
    final cover = mode == CalendarViewMode.photo ? day?.coverPhotoId : null;
    Widget content;
    var showSolidBorder = false;

    if (isFuture) {
      // Ngay tuong lai: chi co so, mau nhat
      content = Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: AppColors.textMuted.withAlpha(110),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (day == null) {
      // Ngay khong chi: vien net dut, hien 0
      content = DashedBox(
        radius: 10,
        child: _DayLabels(
          day: date.day,
          amount: '0',
          color: AppColors.textMuted,
          isToday: isToday,
        ),
      );
    } else if (cover != null) {
      // O co anh: anh dai dien, so ngay, tong tien
      content = Stack(
        fit: StackFit.expand,
        children: [
          PhotoThumb(photoId: cover, borderRadius: 0, showIcon: false),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x22000000), Color(0x99000000)],
              ),
            ),
          ),
          _DayLabels(
            day: date.day,
            amount: formatShort(day.total),
            color: Colors.white,
            isToday: false,
          ),
        ],
      );
    } else {
      // O khong anh (hoac kieu xem So tien)
      final level = mode == CalendarViewMode.amount ? _amountLevel(day.total) : 0;
      final background = level == 0
          ? AppColors.surface
          : AppColors.accent.withAlpha(_amountAlpha[level]);
      showSolidBorder = level == 0;
      content = ColoredBox(
        color: background,
        child: _DayLabels(
          day: date.day,
          amount: formatShort(day.total),
          color: level >= 3 ? Colors.white : AppColors.textPrimary,
          isToday: isToday && level < 3,
        ),
      );
    }

    final Border? border;
    if (isSelected) {
      border = Border.all(color: AppColors.accent, width: 2);
    } else if (showSolidBorder) {
      border = Border.all(color: AppColors.border);
    } else {
      border = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: content,
      ),
    );
  }
}

class _DayLabels extends StatelessWidget {
  const _DayLabels({
    required this.day,
    required this.amount,
    required this.color,
    required this.isToday,
  });

  final int day;
  final String amount;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 3, 5, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isToday ? AppColors.accent : color,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: Text(
              amount,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chi tiet ngay: thu, ngay, tong; luoi anh 3 cot; khoan khong anh la mot dong
// ---------------------------------------------------------------------------

class _DayDetail extends ConsumerWidget {
  const _DayDetail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDateProvider);
    final today = dateOnly(DateTime.now());
    final categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <int, ExpenseCategory>{};
    final text = Theme.of(context).textTheme;

    Widget header(int? total) => Row(
          children: [
            Expanded(
              child: Text(
                formatFullDay(day),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (total != null)
              Text(
                formatVnd(total),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
          ],
        );

    if (day.isAfter(today)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(null),
          const SizedBox(height: 12),
          const _EmptyDay(message: 'Ngày này chưa tới'),
        ],
      );
    }

    final expenses = ref.watch(dayExpensesProvider(day));
    return AsyncView<List<Expense>>(
      value: expenses,
      onRetry: () => ref.invalidate(dayExpensesProvider(day)),
      builder: (items) {
        final withPhoto = items.where((e) => e.hasPhotos).toList();
        final withoutPhoto = items.where((e) => !e.hasPhotos).toList();
        final total = items.fold<int>(0, (sum, e) => sum + e.amount);
        // Tat ca anh cua ngay, de vuot qua lai trong man xem anh
        final allPhotos = [for (final e in withPhoto) ...e.photos];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header(total),
            Text(
              '${items.length} khoản chi',
              style: text.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty) const _EmptyDay(message: 'Không có khoản chi nào'),
            if (withPhoto.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: withPhoto.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.66,
                ),
                itemBuilder: (context, i) {
                  final expense = withPhoto[i];
                  return _PhotoTile(
                    expense: expense,
                    category: categories[expense.categoryId] ?? ExpenseCategory.unknown,
                    onOpenPhoto: () => PhotoViewerScreen.open(
                      context,
                      allPhotos,
                      allPhotos.indexOf(expense.photos.first),
                    ),
                  );
                },
              ),
            if (withoutPhoto.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final expense in withoutPhoto)
                _NoPhotoRow(
                  expense: expense,
                  category: categories[expense.categoryId] ?? ExpenseCategory.unknown,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.expense,
    required this.category,
    required this.onOpenPhoto,
  });

  final Expense expense;
  final ExpenseCategory category;
  final VoidCallback onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onOpenPhoto,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PhotoThumb(
                  photoId: expense.photos.first.id,
                  isReceipt: expense.photos.first.isReceipt,
                ),
                if (expense.photos.length > 1)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: CountBadge(extra: expense.photos.length - 1),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Cham ten: mo man Sua khoan chi
        GestureDetector(
          // TODO(FR-08): mo man Sua khoan chi
          onTap: () => showComingSoon(context, 'Sửa khoản chi'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.note ?? category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              Text(
                formatVnd(expense.amount),
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoPhotoRow extends StatelessWidget {
  const _NoPhotoRow({required this.expense, required this.category});

  final Expense expense;
  final ExpenseCategory category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          // TODO(FR-08): mo man Sua khoan chi
          onTap: () => showComingSoon(context, 'Sửa khoản chi'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: category.color.withAlpha(35),
                  child: Icon(category.icon, color: category.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.note ?? category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${category.name} · ${formatTime(expense.spentAt)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        formatVnd(expense.amount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      // TODO(FR-10): them anh cho khoan chi
                      onPressed: () => showComingSoon(context, 'Thêm ảnh'),
                      icon: const Icon(Icons.add_a_photo_outlined, size: 16),
                      label: const Text('Thêm ảnh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: DashedBox(
        radius: 14,
        child: Center(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}
