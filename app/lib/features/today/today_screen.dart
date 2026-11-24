import 'dart:math' as math;

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
import '../../models/pet.dart';
import '../../providers/app_providers.dart';
import '../../providers/pet_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/pet_view.dart';
import '../../widgets/photo_thumb.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_card.dart';
import '../../widgets/section_header.dart';
import '../capture/capture_flow.dart';
import '../pet/pet_picker.dart';
import 'budget_goal_sheet.dart';

/// Man Hom nay = phong cua ban dong hanh.
/// Pet beo / gay theo nhip chi so voi muc tieu thang (models/pet.dart).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petKindProvider);
    return pet.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (error, _) => Center(child: Text('Không tải được bạn đồng hành: $error')),
      data: (kind) => kind == null
          ? PetPickerScreen(
              onChosen: (k) => ref.read(petKindProvider.notifier).choose(k),
            )
          : _PetRoom(kind: kind),
    );
  }
}

class _PetRoom extends ConsumerWidget {
  const _PetRoom({required this.kind});

  final PetKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final month = monthOf(today);
    final budget = ref.watch(budgetOverviewProvider(month)).valueOrNull;
    final week = ref.watch(last7DaysProvider).valueOrNull;
    final expenses = ref.watch(dayExpensesProvider(today));
    final status = budget == null
        ? const PetStatus(mood: PetMood.unknown)
        : petStatusFor(budget, today);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        refreshExpenseData(ref);
        await ref.read(budgetOverviewProvider(month).future);
      },
      child: ListView(
        padding: EdgeInsets.only(bottom: bottomInset + AppSpacing.xl),
        children: [
          _RoomScene(
            kind: kind,
            status: status,
            budget: budget,
            week: week,
            today: today,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: 'Hôm nay đã chi',
                  actionLabel: 'Xem lịch',
                  onAction: () => openDayInCalendar(ref, today),
                ),
                AsyncView<List<Expense>>(
                  value: expenses,
                  onRetry: () => ref.invalidate(dayExpensesProvider(today)),
                  builder: (items) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayTotals(items: items),
                      const SizedBox(height: AppSpacing.md),
                      _TodayStrip(items: items),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Can phong: tuong, cua so, rem, san go, tham, pet
// ---------------------------------------------------------------------------

class _RoomScene extends ConsumerWidget {
  const _RoomScene({
    required this.kind,
    required this.status,
    required this.budget,
    required this.week,
    required this.today,
  });

  final PetKind kind;
  final PetStatus status;
  final BudgetOverview? budget;
  final List<CalendarDay>? week;
  final DateTime today;

  static const _wallHeight = 250.0;
  static const _floorHeight = 230.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    final month = monthOf(today);
    final daysLeft = daysInMonth(month.year, month.month) - today.day;

    return SizedBox(
      height: top + _wallHeight + _floorHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Tuong
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: top + _wallHeight,
            child: const ColoredBox(color: AppColors.roomWall),
          ),
          // Cua so
          Positioned(
            top: top + 36,
            left: 0,
            right: 0,
            child: const Center(child: _Window()),
          ),
          // Rem hai ben
          Positioned(left: 0, top: top, child: const _Curtain()),
          Positioned(right: 0, top: top, child: const _Curtain()),
          // San go
          Positioned(
            left: 0,
            right: 0,
            top: top + _wallHeight,
            bottom: 0,
            child: const CustomPaint(painter: _FloorPainter()),
          ),
          // Tham tron
          const Positioned(
            left: 0,
            right: 0,
            bottom: 38,
            child: Center(
              child: SizedBox(
                width: 250,
                height: 70,
                child: CustomPaint(painter: _RugPainter()),
              ),
            ),
          ),
          // Pet
          Positioned(
            left: 0,
            right: 0,
            bottom: 52,
            child: Center(
              child: PetView(kind: kind, mood: status.mood, size: 190),
            ),
          ),
          // Bong bong loi noi
          Positioned(
            right: AppSpacing.md,
            top: top + 196,
            child: _SpeechBubble(text: status.mood.speech),
          ),
          // Thanh tren: thang, nut tai khoan
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: top + AppSpacing.xs,
            child: Row(
              children: [
                const SizedBox(width: 36),
                Expanded(
                  child: Center(
                    child: _RoomPill(
                      icon: Icons.calendar_month,
                      label: daysLeft > 0
                          ? 'Tháng ${month.month} · còn $daysLeft ngày'
                          : 'Ngày cuối tháng ${month.month}',
                    ),
                  ),
                ),
                const _AccountButton(),
              ],
            ),
          ),
          // The muc tieu thang
          Positioned(
            left: AppSpacing.md,
            top: top + 56,
            width: 178,
            child: _GoalCard(
              budget: budget,
              status: status,
              week: week,
              today: today,
            ),
          ),
          // Nut ben trai tren san
          Positioned(
            left: AppSpacing.md,
            top: top + _wallHeight + 14,
            child: Column(
              children: [
                _RoomButton(
                  icon: Icons.history,
                  label: 'Lịch sử',
                  onTap: () => ref.read(tabIndexProvider.notifier).select(1),
                ),
                const SizedBox(height: AppSpacing.sm),
                _RoomButton(
                  icon: Icons.pets,
                  label: 'Đổi bạn',
                  onTap: () => showPetPickerSheet(
                    context,
                    current: kind,
                    onChosen: (k) => ref.read(petKindProvider.notifier).choose(k),
                  ),
                ),
              ],
            ),
          ),
          // Nut chup ben phai
          Positioned(
            right: AppSpacing.md,
            top: top + _wallHeight + 14,
            child: _RoomButton(
              icon: Icons.photo_camera,
              label: 'Chụp',
              highlighted: true,
              onTap: () => startCaptureFlow(context, ref),
            ),
          ),
          // Nhan ten + trang thai
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: _RoomPill(
                icon: Icons.favorite,
                label: [
                  kind.label,
                  status.mood.label,
                  if (status.pacePercent != null) 'nhịp ${status.pacePercent}%',
                ].join(' · '),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Window extends StatelessWidget {
  const _Window();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: AppColors.roomWindow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.roomWindowFrame, width: 8),
      ),
      child: Stack(
        children: [
          // May
          Positioned(
            right: 14,
            top: 18,
            child: Container(
              width: 46,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.roomWindowFrame,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          // Khung chu thap
          const Center(
            child: SizedBox(
              width: 6,
              height: double.infinity,
              child: ColoredBox(color: AppColors.roomWindowFrame),
            ),
          ),
          const Center(
            child: SizedBox(
              width: double.infinity,
              height: 6,
              child: ColoredBox(color: AppColors.roomWindowFrame),
            ),
          ),
        ],
      ),
    );
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 230,
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.roomCurtain)),
          // Day buoc rem
          Positioned(
            left: 0,
            right: 0,
            top: 150,
            height: 14,
            child: Container(color: AppColors.roomCurtainShade),
          ),
        ],
      ),
    );
  }
}

class _FloorPainter extends CustomPainter {
  const _FloorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.roomFloor);
    final line = Paint()
      ..color = AppColors.roomFloorLine
      ..strokeWidth = 2;
    // Chan tuong
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, 6),
      Paint()..color = AppColors.roomFloorLine,
    );
    // Van go
    const rowHeight = 46.0;
    var row = 0;
    for (var y = rowHeight; y < size.height; y += rowHeight) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
      final offset = row.isEven ? 0.0 : 70.0;
      for (var x = offset + 40; x < size.width; x += 140) {
        canvas.drawLine(Offset(x, y - rowHeight + 6), Offset(x, y), line);
      }
      row++;
    }
  }

  @override
  bool shouldRepaint(_FloorPainter oldDelegate) => false;
}

class _RugPainter extends CustomPainter {
  const _RugPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(2);
    canvas.drawOval(rect, Paint()..color = const Color(0x33EF9F27));
    // Vien net dut quanh tham
    final path = Path()..addOval(rect);
    final paint = Paint()
      ..color = AppColors.roomRug
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 7, metric.length)), paint);
        d += 13;
      }
    }
  }

  @override
  bool shouldRepaint(_RugPainter oldDelegate) => false;
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(text),
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.roomBorder, width: 1.5),
        ),
        child: Text(text, style: AppText.finePrint.copyWith(height: 1.35)),
      ),
    );
  }
}

class _RoomPill extends StatelessWidget {
  const _RoomPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.roomBorder, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.roomTrim),
          const SizedBox(width: 6),
          Text(label, style: AppText.finePrint.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RoomButton extends StatelessWidget {
  const _RoomButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: label,
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: highlighted ? AppColors.primary : AppColors.canvas,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? AppColors.primary : AppColors.roomBorder,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: highlighted ? Colors.white : AppColors.roomTrim,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppText.finePrint.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.roomTrim,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountButton extends ConsumerWidget {
  const _AccountButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(currentUserNameProvider);
    return Pressable(
      semanticLabel: 'Tài khoản',
      // TODO(FR-04): mo man Tai khoan
      onTap: () => showComingSoon(context, 'Tài khoản'),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.canvas,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.roomBorder, width: 1.5),
        ),
        child: Text(initialOf(name), style: AppText.captionStrong),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The muc tieu thang: muc tieu, thanh da chi, hom nay duoc chi, 5 dong xu
// ---------------------------------------------------------------------------

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.budget,
    required this.status,
    required this.week,
    required this.today,
  });

  final BudgetOverview? budget;
  final PetStatus status;
  final List<CalendarDay>? week;
  final DateTime today;

  Color get _barColor => switch (status.mood) {
        PetMood.chubby || PetMood.healthy || PetMood.unknown => AppColors.primaryFocus,
        PetMood.thin => AppColors.coin,
        PetMood.tired || PetMood.starving => AppColors.danger,
      };

  @override
  Widget build(BuildContext context) {
    final month = monthOf(today);
    final total = budget?.total;

    void openSheet() => showBudgetGoalSheet(context, month: month, current: total?.limit);

    final Widget content;
    if (total == null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mục tiêu tháng ${month.month}',
            style: AppText.finePrint.copyWith(color: AppColors.inkMuted48),
          ),
          const SizedBox(height: 4),
          Text(
            'Chạm để đặt mục tiêu',
            style: AppText.captionStrong.copyWith(color: AppColors.primary),
          ),
        ],
      );
    } else {
      final daily = budget!.dailyAllowance(today);
      final dailyLimit = total.limit / daysInMonth(month.year, month.month);
      // 5 ngay gan nhat: dong xu vang = ngay chi khong qua muc trung binh/ngay
      final recent = (week ?? const <CalendarDay>[]).reversed.take(5).toList().reversed;
      final String hint;
      if (total.remaining < 0) {
        hint = 'Đã vượt ${formatShort(-total.remaining)}';
      } else if (daily == null) {
        hint = 'Còn ${formatShort(total.remaining)} cho hôm nay';
      } else {
        hint = 'Hôm nay được chi ${formatShort(daily)}';
      }

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mục tiêu ${formatVnd(total.limit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.finePrint.copyWith(color: AppColors.inkMuted48),
                ),
              ),
              const Icon(Icons.edit, size: 13, color: AppColors.inkMuted48),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: total.ratio.clamp(0.0, 1.0).toDouble(),
              minHeight: 9,
              color: _barColor,
              backgroundColor: AppColors.dividerSoft,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Đã chi ${formatShort(total.spent)}',
            style: AppText.finePrint.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(hint, style: AppText.finePrint),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                for (final day in recent)
                  Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Icon(
                      Icons.monetization_on,
                      size: 18,
                      color: day.total <= dailyLimit ? AppColors.coin : AppColors.hairline,
                    ),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return Pressable(
      semanticLabel: 'Mục tiêu chi tháng',
      onTap: openSheet,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 10, AppSpacing.sm, 10),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.roomBorder, width: 1.5),
        ),
        child: content,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hom nay da chi: tong + dai anh
// ---------------------------------------------------------------------------

class _TodayTotals extends StatelessWidget {
  const _TodayTotals({required this.items});

  final List<Expense> items;

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, e) => sum + e.amount);
    final photos = items.fold<int>(0, (sum, e) => sum + e.photos.length);
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(formatGrouped(total), style: AppText.tagline.copyWith(fontSize: 26)),
          const SizedBox(width: 4),
          Text('₫', style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48)),
          const Spacer(),
          Text(
            '${items.length} khoản · $photos ảnh',
            style: AppText.caption.copyWith(color: AppColors.inkMuted48),
          ),
        ],
      ),
    );
  }
}

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
        clipBehavior: Clip.none,
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

class _CaptureTile extends ConsumerWidget {
  const _CaptureTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Pressable(
      semanticLabel: 'Chụp khoản mới',
      onTap: () => startCaptureFlow(context, ref),
      child: SizedBox(
        width: 116,
        child: Column(
          children: [
            Expanded(
              child: DashedBox(
                color: AppColors.primary,
                radius: AppRadius.lg,
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Chụp khoản mới',
              style: AppText.captionStrong.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: 2),
            const Text(' ', style: AppText.finePrint),
          ],
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