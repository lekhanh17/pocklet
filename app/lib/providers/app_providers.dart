import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_utils.dart';
import '../data/expense_repository.dart';
import '../data/mock_expense_repository.dart';
import '../models/budget.dart';
import '../models/calendar.dart';
import '../models/category.dart';
import '../models/expense.dart';

// ---------------------------------------------------------------------------
// Ngay hom nay
// ---------------------------------------------------------------------------

/// Ngay hom nay (gio may). Tu doi luc nua dem va khi app mo lai tu nen,
/// de man Hom nay, 7 ngay qua va Lich khong bi ket o ngay hom qua (FR-14, FR-19).
class TodayNotifier extends Notifier<DateTime> {
  Timer? _midnight;

  @override
  DateTime build() {
    ref.onDispose(() => _midnight?.cancel());
    _scheduleMidnight();
    return dateOnly(DateTime.now());
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now) + const Duration(seconds: 1), refresh);
  }

  /// Kiem tra lai ngay (goi khi app quay lai tu nen: timer co the bi tre khi may ngu).
  void refresh() {
    final day = dateOnly(DateTime.now());
    if (day != state) state = day;
    _scheduleMidnight();
  }
}

final todayProvider = NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

// ---------------------------------------------------------------------------
// Nguon du lieu
// ---------------------------------------------------------------------------

/// Doi MockExpenseRepository() thanh ApiExpenseRepository(...) khi API xong.
final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => MockExpenseRepository(),
);

/// Ten hien thi cua nguoi dung dang dang nhap (tam thoi la du lieu mau).
final currentUserNameProvider = Provider<String>((ref) => 'Khánh Lê');

final categoriesProvider = FutureProvider<List<ExpenseCategory>>(
  (ref) => ref.watch(expenseRepositoryProvider).getCategories(),
);

/// Tra cuu danh muc theo id.
final categoryMapProvider = FutureProvider<Map<int, ExpenseCategory>>((ref) async {
  final list = await ref.watch(categoriesProvider.future);
  return {for (final c in list) c.id: c};
});

/// Danh sach khoan chi cua mot ngay, moi nhat truoc.
final dayExpensesProvider = FutureProvider.family<List<Expense>, DateTime>(
  (ref, day) => ref
      .watch(expenseRepositoryProvider)
      .getExpenses(from: dateOnly(day), to: dateOnly(day)),
);

final calendarMonthProvider = FutureProvider.family<CalendarMonth, DateTime>(
  (ref, month) => ref.watch(expenseRepositoryProvider).getCalendar(month),
);

final budgetOverviewProvider = FutureProvider.family<BudgetOverview, DateTime>(
  (ref, month) => ref.watch(expenseRepositoryProvider).getBudgets(month),
);

/// 7 ngay qua cho Trang chu (FR-19), ngay cu nhat dung dau.
final last7DaysProvider = FutureProvider<List<CalendarDay>>((ref) async {
  final today = ref.watch(todayProvider);
  final from = DateTime(today.year, today.month, today.day - 6);
  final items = await ref
      .watch(expenseRepositoryProvider)
      .getExpenses(from: from, to: today);
  // Gom theo ngay mot lan thay vi loc lai toan bo danh sach cho tung ngay.
  final byDay = <DateTime, List<Expense>>{};
  for (final e in items) {
    (byDay[dateOnly(e.spentAt)] ??= []).add(e);
  }
  return List.generate(7, (i) {
    final day = DateTime(from.year, from.month, from.day + i);
    return summarizeDay(day, byDay[day] ?? const []);
  });
});

// ---------------------------------------------------------------------------
// Trang thai giao dien
// ---------------------------------------------------------------------------

/// Tab cua thanh dieu huong: 0 Hôm nay, 1 Lịch, 2 Chụp, 3 Thống kê, 4 Ngân sách.
class TabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final tabIndexProvider =
    NotifierProvider<TabIndexNotifier, int>(TabIndexNotifier.new);

/// Ngay dang chon tren Lich, mo app thi chon san hom nay (FR-14).
class SelectedDateNotifier extends Notifier<DateTime> {
  // Doc (khong watch) todayProvider: qua ngay moi khong lam mat ngay dang chon.
  @override
  DateTime build() => ref.read(todayProvider);

  void select(DateTime day) => state = dateOnly(day);
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// Thang dang hien tren Lich.
class VisibleMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => monthOf(ref.read(todayProvider));

  void show(DateTime month) => state = monthOf(month);
}

final visibleMonthProvider =
    NotifierProvider<VisibleMonthNotifier, DateTime>(VisibleMonthNotifier.new);

enum CalendarViewMode { photo, amount }

/// Kieu xem Lich: Anh / So tien (FR-15).
class CalendarViewModeNotifier extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.photo;

  void set(CalendarViewMode mode) => state = mode;
}

final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeNotifier, CalendarViewMode>(
  CalendarViewModeNotifier.new,
);

// ---------------------------------------------------------------------------
// Hanh dong dung chung
// ---------------------------------------------------------------------------

/// Tai lai moi du lieu khoan chi (keo de lam moi, va sau nay sau khi them, sua, xoa
/// khoan chi): invalidate ca family nen moi ngay, moi thang da mo deu lay lai.
void refreshExpenseData(WidgetRef ref) {
  ref.invalidate(dayExpensesProvider);
  ref.invalidate(calendarMonthProvider);
  ref.invalidate(budgetOverviewProvider);
  ref.invalidate(last7DaysProvider);
}

/// Qua ngay moi: neu Lich dang chon "hom nay" cu thi chuyen sang hom nay moi
/// (va sang thang moi neu vua qua thang).
void followNewDay(WidgetRef ref, DateTime previous, DateTime today) {
  if (ref.read(selectedDateProvider) != previous) return;
  ref.read(visibleMonthProvider.notifier).show(today);
  ref.read(selectedDateProvider.notifier).select(today);
}

/// Lich khong mo thang tuong lai: moi ngay trong do deu "chua toi".
bool canShowMonth(DateTime month, DateTime today) => !monthOf(month).isAfter(monthOf(today));

/// Doi thang tren Lich. Neu la thang hien tai thi chon hom nay,
/// thang khac thi chon ngay 1.
void showCalendarMonth(WidgetRef ref, DateTime month) {
  final m = monthOf(month);
  final today = ref.read(todayProvider);
  if (!canShowMonth(m, today)) return;
  ref.read(visibleMonthProvider.notifier).show(m);
  ref
      .read(selectedDateProvider.notifier)
      .select(monthOf(today) == m ? today : m);
}

/// Mo tab Lich tai mot ngay (cham o ngay o Trang chu).
void openDayInCalendar(WidgetRef ref, DateTime day) {
  ref.read(visibleMonthProvider.notifier).show(day);
  ref.read(selectedDateProvider.notifier).select(day);
  ref.read(tabIndexProvider.notifier).select(1);
}
