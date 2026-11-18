import 'dart:math';

import '../core/date_utils.dart';
import '../models/budget.dart';
import '../models/calendar.dart';
import '../models/category.dart';
import '../models/expense.dart';
import 'expense_repository.dart';

/// Du lieu mau de lam giao dien truoc khi co API.
/// Sinh ngau nhien nhung co dinh theo thang (cung seed), tu ngay 1 den hom nay.
class MockExpenseRepository implements ExpenseRepository {
  MockExpenseRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, List<Expense>> _cache = {};
  int _nextExpenseId = 1;
  int _nextPhotoId = 3000;

  static const _latency = Duration(milliseconds: 250);

  /// 8 danh muc mac dinh (FR-05).
  static const defaultCategories = <ExpenseCategory>[
    ExpenseCategory(id: 1, name: 'Ăn uống', iconName: 'restaurant', colorHex: '#E07A5F'),
    ExpenseCategory(id: 2, name: 'Di chuyển', iconName: 'directions_car', colorHex: '#3D85C6'),
    ExpenseCategory(id: 3, name: 'Mua sắm', iconName: 'shopping_bag', colorHex: '#C2185B'),
    ExpenseCategory(id: 4, name: 'Hoá đơn', iconName: 'receipt_long', colorHex: '#6D4C41'),
    ExpenseCategory(id: 5, name: 'Giải trí', iconName: 'sports_esports', colorHex: '#7E57C2'),
    ExpenseCategory(id: 6, name: 'Sức khoẻ', iconName: 'medical_services', colorHex: '#D32F2F'),
    ExpenseCategory(id: 7, name: 'Học tập', iconName: 'school', colorHex: '#F9A825'),
    ExpenseCategory(id: 8, name: 'Khác', iconName: 'more_horiz', colorHex: '#78716C'),
  ];

  /// Han muc mau: Ăn uống dat nguong 80% va Giải trí de vuot (FR-18).
  static const _totalLimit = 5000000;
  static const _categoryLimits = {1: 1000000, 2: 600000, 3: 1000000, 5: 100000};

  @override
  Future<List<ExpenseCategory>> getCategories() async {
    await Future<void>.delayed(_latency);
    return defaultCategories;
  }

  @override
  Future<List<Expense>> getExpenses({
    required DateTime from,
    required DateTime to,
  }) async {
    await Future<void>.delayed(_latency);
    final start = dateOnly(from);
    final end = DateTime(to.year, to.month, to.day + 1);
    final result = <Expense>[];
    var m = monthOf(start);
    final lastMonth = monthOf(to);
    while (!m.isAfter(lastMonth)) {
      result.addAll(_monthData(m.year, m.month).where(
        (e) => !e.spentAt.isBefore(start) && e.spentAt.isBefore(end),
      ));
      m = DateTime(m.year, m.month + 1);
    }
    result.sort((a, b) => b.spentAt.compareTo(a.spentAt));
    return result;
  }

  @override
  Future<CalendarMonth> getCalendar(DateTime month) async {
    await Future<void>.delayed(_latency);
    final items = _monthData(month.year, month.month);
    final days = <CalendarDay>[];
    for (var d = 1; d <= daysInMonth(month.year, month.month); d++) {
      final day = DateTime(month.year, month.month, d);
      final ofDay = items.where((e) => isSameDay(e.spentAt, day)).toList();
      if (ofDay.isNotEmpty) days.add(summarizeDay(day, ofDay));
    }
    return CalendarMonth(
      month: monthOf(month),
      total: items.fold<int>(0, (sum, e) => sum + e.amount),
      days: days,
    );
  }

  @override
  Future<BudgetOverview> getBudgets(DateTime month) async {
    await Future<void>.delayed(_latency);
    final items = _monthData(month.year, month.month);
    int spentOf(int? categoryId) => items
        .where((e) => categoryId == null || e.categoryId == categoryId)
        .fold<int>(0, (sum, e) => sum + e.amount);

    return BudgetOverview(
      month: monthOf(month),
      total: BudgetLine(limit: _totalLimit, spent: spentOf(null)),
      categories: [
        for (final entry in _categoryLimits.entries)
          BudgetLine(
            categoryId: entry.key,
            limit: entry.value,
            spent: spentOf(entry.key),
          ),
      ],
    );
  }

  List<Expense> _monthData(int year, int month) {
    return _cache.putIfAbsent('$year-$month', () => _generate(year, month));
  }

  List<Expense> _generate(int year, int month) {
    final now = _clock();
    final today = dateOnly(now);
    final rnd = Random(year * 100 + month);
    final items = <Expense>[];

    for (var d = 1; d <= daysInMonth(year, month); d++) {
      final day = DateTime(year, month, d);
      if (day.isAfter(today)) break;
      final isToday = isSameDay(day, today);

      final picks = <_Sample>[
        if (d == 5) const _Sample(4, 'Tiền điện', 300000, 450000, receipt: true),
        if (d == 10) const _Sample(4, 'Tiền mạng', 220000, 220000, receipt: true),
      ];
      final n = isToday ? 4 : rnd.nextInt(5);
      for (var i = 0; i < n; i++) {
        picks.add(_samples[rnd.nextInt(_samples.length)]);
      }

      for (var i = 0; i < picks.length; i++) {
        final s = picks[i];
        final maxHour = isToday ? now.hour : 22;
        final hour =
            maxHour <= 6 ? rnd.nextInt(maxHour + 1) : 6 + rnd.nextInt(maxHour - 5);
        var spentAt = DateTime(year, month, d, hour, rnd.nextInt(60));
        if (spentAt.isAfter(now)) spentAt = now;

        final steps = (s.max - s.min) ~/ 1000;
        final amount = s.min + rnd.nextInt(steps + 1) * 1000;
        final withPhoto = isToday ? i < 3 : rnd.nextDouble() < 0.55;
        final photoCount = withPhoto ? (rnd.nextDouble() < 0.2 ? 2 : 1) : 0;

        items.add(Expense(
          id: _nextExpenseId++,
          categoryId: s.categoryId,
          amount: amount,
          spentAt: spentAt,
          note: s.note,
          photos: [
            for (var p = 0; p < photoCount; p++)
              ExpensePhoto(id: _nextPhotoId++, isReceipt: s.receipt && p == 0),
          ],
        ));
      }
    }

    items.sort((a, b) => a.spentAt.compareTo(b.spentAt));
    return items;
  }
}

class _Sample {
  const _Sample(this.categoryId, this.note, this.min, this.max,
      {this.receipt = false});

  final int categoryId;
  final String note;
  final int min;
  final int max;
  final bool receipt;
}

const _samples = <_Sample>[
  _Sample(1, 'Phở bò', 35000, 60000),
  _Sample(1, 'Bánh mì', 15000, 30000),
  _Sample(1, 'Cà phê sữa', 20000, 45000),
  _Sample(1, 'Cơm trưa', 30000, 55000),
  _Sample(1, 'Trà sữa', 30000, 60000),
  _Sample(1, 'Đi chợ', 80000, 250000, receipt: true),
  _Sample(2, 'Grab về nhà', 25000, 90000),
  _Sample(2, 'Đổ xăng', 50000, 100000),
  _Sample(3, 'Áo thun', 120000, 350000),
  _Sample(3, 'Đồ dùng cá nhân', 40000, 200000, receipt: true),
  _Sample(5, 'Xem phim', 60000, 120000),
  _Sample(6, 'Thuốc cảm', 30000, 90000, receipt: true),
  _Sample(7, 'Sách tiếng Nhật', 80000, 250000),
  _Sample(8, 'Linh tinh', 10000, 50000),
];
