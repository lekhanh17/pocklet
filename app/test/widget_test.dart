// Kiem thu logic thuan (khong can giao dien): dinh dang tien BR-01,
// anh dai dien BR-06, ngan sach BR-04 va du lieu mau.
// Ten file giu la widget_test.dart de lenh `flutter create .` khong sinh de file mau.

import 'package:flutter_test/flutter_test.dart';
import 'package:pocklet/core/format.dart';
import 'package:pocklet/data/mock_expense_repository.dart';
import 'package:pocklet/models/budget.dart';
import 'package:pocklet/models/calendar.dart';
import 'package:pocklet/models/expense.dart';

void main() {
  group('BR-01 dinh dang tien', () {
    test('formatVnd co dau cham ngan nghin va ₫', () {
      expect(formatVnd(45000), '45.000 ₫');
      expect(formatVnd(1000000000), '1.000.000.000 ₫');
      expect(formatVnd(0), '0 ₫');
    });

    test('formatShort viet gon tren o lich', () {
      expect(formatShort(0), '0');
      expect(formatShort(180000), '180k');
      expect(formatShort(1200000), '1,2tr');
      expect(formatShort(2000000), '2tr');
    });
  });

  test('BR-06 anh dai dien la anh dau cua khoan chi co anh muon nhat', () {
    final day = DateTime(2026, 11, 17);
    final items = [
      Expense(
        id: 1,
        categoryId: 1,
        amount: 45000,
        spentAt: DateTime(2026, 11, 17, 7, 40),
        photos: const [ExpensePhoto(id: 10)],
      ),
      Expense(
        id: 2,
        categoryId: 1,
        amount: 30000,
        spentAt: DateTime(2026, 11, 17, 12, 0),
        photos: const [ExpensePhoto(id: 20), ExpensePhoto(id: 21)],
      ),
      Expense(
        id: 3,
        categoryId: 2,
        amount: 50000,
        spentAt: DateTime(2026, 11, 17, 18, 0),
      ),
    ];

    final summary = summarizeDay(day, items);
    expect(summary.total, 125000);
    expect(summary.count, 3);
    expect(summary.coverPhotoId, 20);
  });

  test('BR-04 nguong canh bao ngan sach', () {
    expect(const BudgetLine(limit: 2000000, spent: 1500000).level, BudgetLevel.normal);
    expect(const BudgetLine(limit: 2000000, spent: 1600000).level, BudgetLevel.warning);
    expect(const BudgetLine(limit: 2000000, spent: 2000000).level, BudgetLevel.warning);
    expect(const BudgetLine(limit: 2000000, spent: 2000001).level, BudgetLevel.over);

    final overview = BudgetOverview(
      month: DateTime(2026, 11),
      total: const BudgetLine(limit: 5000000, spent: 3000000),
    );
    // Ngay 20/11: con 10 ngay sau hom nay -> 2.000.000 / 10
    expect(overview.dailyAllowance(DateTime(2026, 11, 20)), 200000);
  });

  test('Du lieu mau khong co khoan chi trong tuong lai', () async {
    final now = DateTime(2026, 11, 17, 10, 30);
    final repo = MockExpenseRepository(clock: () => now);
    final items = await repo.getExpenses(
      from: DateTime(2026, 11, 1),
      to: DateTime(2026, 11, 30),
    );
    expect(items, isNotEmpty);
    expect(items.every((e) => !e.spentAt.isAfter(now)), isTrue);

    final calendar = await repo.getCalendar(DateTime(2026, 11));
    final sum = items.fold<int>(0, (s, e) => s + e.amount);
    expect(calendar.total, sum);
  });
}
