import 'dart:io';
import 'dart:math';

import 'package:flutter/painting.dart';

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

  /// "nam-thang" -> ngay cuoi cung da sinh du lieu mau cua thang do.
  final Map<String, DateTime> _generatedUntil = {};
  int _nextExpenseId = 1;
  int _nextPhotoId = 3000;

  /// Anh nguoi dung chup that: photoId -> duong dan file da nen.
  final Map<int, String> _photoPaths = {};

  /// BR-04: moi nguong chi bao mot lan moi thang. Khoa: nam-thang-danhmuc-muc.
  final Set<String> _warned = {};

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

  /// Muc tieu thang mac dinh cua du lieu mau (pet thuong o muc "Khoe manh").
  /// Nguoi dung doi trong phong pet; muc tieu thap (vi du 3 trieu) se lam pet gay di.
  static const _totalLimit = 6000000;

  /// Muc tieu nguoi dung tu dat: "nam-thang" -> so tien.
  final Map<String, int> _totalLimitOverrides = {};
  static const _categoryLimits = {1: 1500000, 2: 800000, 3: 2500000, 5: 250000};

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
    return _budgetOverview(month);
  }

  @override
  Future<void> setMonthlyBudget(DateTime month, int limit) async {
    await Future<void>.delayed(_latency);
    if (limit <= 0) throw ArgumentError('Mục tiêu phải lớn hơn 0');
    _totalLimitOverrides['${month.year}-${month.month}'] = limit;
    // BR-04: doi han muc thi duoc canh bao lai tu dau
    _warned.removeWhere((k) => k.startsWith('${month.year}-${month.month}-null-'));
  }

  @override
  Future<ExpenseSaveResult> addExpense(ExpenseDraft draft) async {
    await Future<void>.delayed(_latency);
    // Server la noi kiem tra cuoi cung (muc 8): BR-01, BR-02
    if (draft.amount < 1 || draft.amount > maxExpenseAmount) {
      throw ArgumentError('Số tiền phải từ 1 đến 1.000.000.000 ₫');
    }
    if (draft.spentAt.isAfter(_clock().add(const Duration(minutes: 1)))) {
      throw ArgumentError('Không chọn được thời điểm sau hiện tại');
    }

    final expense = Expense(
      id: _nextExpenseId++,
      categoryId: draft.categoryId,
      amount: draft.amount,
      spentAt: draft.spentAt,
      note: draft.note,
    );
    final list = _monthData(draft.spentAt.year, draft.spentAt.month)..add(expense);
    list.sort((a, b) => a.spentAt.compareTo(b.spentAt));

    // Canh bao ngan sach tong va ngan sach cua danh muc vua chi (BR-04)
    final overview = _budgetOverview(draft.spentAt);
    final total = overview.total;
    final alerts = <BudgetAlert>[];
    for (final line in [if (total != null) total, ...overview.categories]) {
      if (line.categoryId != null && line.categoryId != draft.categoryId) continue;
      if (line.level == BudgetLevel.normal) continue;
      final key = '${draft.spentAt.year}-${draft.spentAt.month}-${line.categoryId}-${line.level.name}';
      if (_warned.add(key)) {
        alerts.add(BudgetAlert(
          categoryId: line.categoryId,
          level: line.level,
          percent: line.percent,
        ));
      }
    }
    return ExpenseSaveResult(expense: expense, budgetAlerts: alerts);
  }

  @override
  Future<ExpensePhoto> uploadPhoto(
    int expenseId,
    String filePath, {
    bool isReceipt = false,
  }) async {
    await Future<void>.delayed(_latency);
    for (final list in _cache.values) {
      final index = list.indexWhere((e) => e.id == expenseId);
      if (index < 0) continue;
      final expense = list[index];
      if (expense.photos.length >= maxPhotosPerExpense) {
        throw StateError('Khoản chi đã đủ $maxPhotosPerExpense ảnh'); // API tra 409
      }
      final photo = ExpensePhoto(id: _nextPhotoId++, isReceipt: isReceipt);
      _photoPaths[photo.id] = filePath;
      list[index] = expense.copyWith(photos: [...expense.photos, photo]);
      return photo;
    }
    throw StateError('Không tìm thấy khoản chi $expenseId'); // API tra 404
  }

  @override
  ImageProvider? photoImage(int photoId) {
    final path = _photoPaths[photoId];
    return path == null ? null : FileImage(File(path));
  }

  BudgetOverview _budgetOverview(DateTime month) {
    final items = _monthData(month.year, month.month);
    int spentOf(int? categoryId) => items
        .where((e) => categoryId == null || e.categoryId == categoryId)
        .fold<int>(0, (sum, e) => sum + e.amount);

    return BudgetOverview(
      month: monthOf(month),
      total: BudgetLine(
        limit: _totalLimitOverrides['${month.year}-${month.month}'] ?? _totalLimit,
        spent: spentOf(null),
      ),
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

  /// Du lieu cua mot thang (ca khoan chi nguoi dung vua them).
  /// Thang hien tai: qua nua dem thi sinh them du lieu mau cho ngay moi, khong
  /// sinh lai ca thang, de khoan chi nguoi dung da them trong phien van con.
  List<Expense> _monthData(int year, int month) {
    final key = '$year-$month';
    final items = _cache.putIfAbsent(key, () => <Expense>[]);
    final now = _clock();
    final today = dateOnly(now);
    final lastDay = DateTime(year, month, daysInMonth(year, month));
    final target = today.isBefore(lastDay) ? today : lastDay;
    final done = _generatedUntil[key];

    // Thang tuong lai (target truoc ngay 1) thi chua co gi de sinh
    if (target.isBefore(DateTime(year, month, 1))) return items;
    if (done != null && !target.isAfter(done)) return items;

    items
      ..addAll(_generate(year, month, done == null ? 1 : done.day + 1, target.day, now))
      ..sort((a, b) => a.spentAt.compareTo(b.spentAt));
    _generatedUntil[key] = target;
    return items;
  }

  /// Sinh du lieu mau tu ngay [fromDay] den [toDay] cua thang.
  List<Expense> _generate(int year, int month, int fromDay, int toDay, DateTime now) {
    final today = dateOnly(now);
    final items = <Expense>[];

    for (var d = fromDay; d <= toDay; d++) {
      final day = DateTime(year, month, d);
      if (day.isAfter(today)) break;
      final isToday = isSameDay(day, today);
      // Seed theo tung ngay: sinh them ngay moi khong lam doi du lieu cac ngay truoc
      final rnd = Random(year * 10000 + month * 100 + d);

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