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
import '../../widgets/pressable.dart';
import '../../widgets/section_card.dart';
import '../../widgets/segmented_control.dart';
import '../photo_viewer/photo_viewer_screen.dart';

/// Man Lịch (dac ta muc 5.1, FR-13 den FR-15).
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final monthData = ref.watch(calendarMonthProvider(month));
    final mode = ref.watch(calendarViewModeProvider);
    final today = ref.watch(todayProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Khong cho sang thang tuong lai (moi ngay deu "chua toi"): ca nut lan vuot ngang
    final nextMonth = DateTime(month.year, month.month + 1);
    final hasNext = canShowMonth(nextMonth, today);

    void previous() => showCalendarMonth(ref, DateTime(month.year, month.month - 1));
    void next() => showCalendarMonth(ref, nextMonth);

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        refreshExpenseData(ref);
        await ref.read(calendarMonthProvider(month).future);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            title: const Text('Lịch'),
            actions: [
              IconButton(
                tooltip: 'Tìm kiếm',
                // TODO(FR-23): mo man Tim kiem
                onPressed: () => showComingSoon(context, 'Tìm kiếm'),
                icon: const Icon(Icons.search),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, bottomInset + AppSpacing.xl,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CalendarHeader(
                    month: month,
                    data: monthData.valueOrNull,
                    onPrevious: previous,
                    onNext: hasNext ? next : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: SizedBox(
                      width: 240,
                      child: AppSegmentedControl<CalendarViewMode>(
                        segments: const {
                          CalendarViewMode.photo: 'Ảnh',
                          CalendarViewMode.amount: 'Số tiền',
                        },
                        selected: mode,
                        onChanged: (value) =>
                            ref.read(calendarViewModeProvider.notifier).set(value),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Vuot ngang luoi de doi thang
                  SectionCard(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) {
                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity < -250 && hasNext) next();
                        if (velocity > 250) previous();
                      },
                      child: AsyncView<CalendarMonth>(
                        value: monthData,
                        loadingHeight: 360,
                        onRetry: () => ref.invalidate(calendarMonthProvider(month)),
                        builder: (data) => _MonthGrid(month: month, data: data, today: today),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _DayDetail(),
                ],
              ),
            ),
          ),
        ],
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

  /// Null khi dang o thang hien tai: nut mo di, khong sang thang tuong lai.
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
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
              Text(formatMonth(month), style: AppText.tagline),
              const SizedBox(height: 2),
              Text(
                summary,
                style: AppText.caption.copyWith(color: AppColors.inkMuted48),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tháng sau',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Luoi ngay: 7 cot T2-CN
// ---------------------------------------------------------------------------

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid({required this.month, required this.data, required this.today});

  final DateTime month;
  final CalendarMonth data;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Khong watch ngay dang chon o day: chon ngay khac chi ve lai 2 o (xem _DayCell),
    // khong dung lai ca luoi 42 o.
    final mode = ref.watch(calendarViewModeProvider);
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
                    style: AppText.finePrint.copyWith(
                      color: AppColors.inkMuted48,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: AppSpacing.xxs,
            crossAxisSpacing: AppSpacing.xxs,
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

/// Do dam cua ink theo muc (don sac, khong them mau nhan thu hai).
const _amountAlpha = [0, 18, 46, 110, 200];

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.date,
    required this.info,
    required this.mode,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final DateTime date;
  final CalendarDay? info;
  final CalendarViewMode mode;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // select: o chi build lai khi CHINH no duoc chon / bo chon
    final isSelected = ref.watch(
      selectedDateProvider.select((selected) => isSameDay(selected, date)),
    );
    final day = info;
    final cover = mode == CalendarViewMode.photo ? day?.coverPhotoId : null;
    Widget content;

    if (isFuture) {
      // Ngay tuong lai: chi co so, mau nhat
      content = Center(
        child: Text(
          '${date.day}',
          style: AppText.finePrint.copyWith(
            color: AppColors.inkMuted48.withAlpha(110),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (day == null) {
      // Ngay khong chi: vien net dut, hien 0
      content = DashedBox(
        color: AppColors.inkMuted48.withAlpha(140),
        child: _DayLabels(
          day: date.day,
          amount: '0',
          color: AppColors.inkMuted48,
          isToday: isToday,
        ),
      );
    } else if (cover != null) {
      // O co anh: anh dai dien; so ngay va tong tien nam tren chip trong suot
      content = Stack(
        fit: StackFit.expand,
        children: [
          PhotoThumb(photoId: cover, borderRadius: 0, showIcon: false),
          Positioned(
            left: 3,
            top: 3,
            child: OverlayChip(label: '${date.day}', small: true),
          ),
          Positioned(
            left: 2,
            right: 2,
            bottom: 3,
            child: Center(
              child: OverlayChip(label: formatShort(day.total), small: true),
            ),
          ),
        ],
      );
    } else {
      // O khong anh (hoac kieu xem So tien)
      final level = mode == CalendarViewMode.amount ? _amountLevel(day.total) : 0;
      final background = level == 0
          ? AppColors.parchment
          : AppColors.ink.withAlpha(_amountAlpha[level]);
      content = ColoredBox(
        color: background,
        child: _DayLabels(
          day: date.day,
          amount: formatShort(day.total),
          color: level >= 3 ? AppColors.bodyOnDark : AppColors.ink,
          isToday: isToday && level < 3,
        ),
      );
    }

    final border =
        isSelected ? Border.all(color: AppColors.primaryFocus, width: 2) : null;

    return Pressable(
      // Ngay tuong lai khong chon duoc (FR-13: lam mo)
      onTap: isFuture ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
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
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$day',
            style: AppText.finePrint.copyWith(
              fontWeight: FontWeight.w600,
              color: isToday ? AppColors.primary : color,
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
              style: AppText.micro.copyWith(
                fontWeight: FontWeight.w600,
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
    final today = ref.watch(todayProvider);
    final categories =
        ref.watch(categoryMapProvider).valueOrNull ?? const <int, ExpenseCategory>{};

    Widget header(int? total) => Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: Text(formatFullDay(day), style: AppText.tagline)),
            if (total != null) Text(formatVnd(total), style: AppText.tagline),
          ],
        );

    if (day.isAfter(today)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(null),
          const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: 2),
            Text(
              '${items.length} khoản chi',
              style: AppText.caption.copyWith(color: AppColors.inkMuted48),
            ),
            const SizedBox(height: AppSpacing.md),
            if (items.isEmpty) const _EmptyDay(message: 'Không có khoản chi nào'),
            if (withPhoto.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: withPhoto.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.xs,
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
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Không có ảnh',
                style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
              ),
              const SizedBox(height: AppSpacing.xs),
              SectionCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < withoutPhoto.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          indent: 68,
                          color: AppColors.hairline,
                        ),
                      _NoPhotoRow(
                        expense: withoutPhoto[i],
                        category: categories[withoutPhoto[i].categoryId] ??
                            ExpenseCategory.unknown,
                      ),
                    ],
                  ],
                ),
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
          child: Pressable(
            semanticLabel: 'Xem ảnh',
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
        const SizedBox(height: 6),
        // Cham ten: mo man Sua khoan chi
        Pressable(
          // TODO(FR-08): mo man Sua khoan chi
          onTap: () => showComingSoon(context, 'Sửa khoản chi'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expense.note ?? category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.captionStrong,
              ),
              const SizedBox(height: 2),
              Text(
                formatVnd(expense.amount),
                style: AppText.finePrint.copyWith(color: AppColors.inkMuted48),
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
    return Pressable(
      // TODO(FR-08): mo man Sua khoan chi
      onTap: () => showComingSoon(context, 'Sửa khoản chi'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.xxs, AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: category.color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(category.icon, color: category.color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.note ?? category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${category.name} · ${formatTime(expense.spentAt)}',
                    style: AppText.finePrint.copyWith(color: AppColors.inkMuted48),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(formatVnd(expense.amount), style: AppText.captionStrong),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
        radius: AppRadius.lg,
        child: Center(
          child: Text(
            message,
            style: AppText.caption.copyWith(color: AppColors.inkMuted48),
          ),
        ),
      ),
    );
  }
}