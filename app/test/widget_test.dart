// Kiem thu logic thuan (khong can giao dien): dinh dang tien BR-01,
// anh dai dien BR-06, ngan sach BR-04 va du lieu mau.
// Ten file giu la widget_test.dart de lenh `flutter create .` khong sinh de file mau.

import 'package:flutter_test/flutter_test.dart';
import 'package:pocklet/core/format.dart';
import 'package:pocklet/data/mock_expense_repository.dart';
import 'package:pocklet/features/expense_form/amount_keypad.dart';
import 'package:pocklet/models/budget.dart';
import 'package:pocklet/models/calendar.dart';
import 'package:pocklet/models/expense.dart';
import 'package:pocklet/models/pet.dart';

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

  group('Ban phim so tien (BR-01)', () {
    test('phim 000 va xoa', () {
      expect(applyKeypadKey('45', '000'), '45000');
      expect(applyKeypadKey('45000', keypadDelete), '4500');
      expect(applyKeypadKey('', keypadDelete), '');
    });

    test('khong cho 0 o dau va khong vuot 1 ty', () {
      expect(applyKeypadKey('', '0'), isNull);
      expect(applyKeypadKey('', '000'), isNull);
      expect(applyKeypadKey('100000000', '0'), '1000000000');
      expect(applyKeypadKey('1000000000', '0'), isNull);
      expect(applyKeypadKey('100000000', '1'), isNull);
    });
  });

  test('Them khoan chi kem anh, canh bao chi bao mot lan (BR-04)', () async {
    final now = DateTime(2026, 11, 28, 20, 0);
    final repo = MockExpenseRepository(clock: () => now);

    final first = await repo.addExpense(ExpenseDraft(
      categoryId: 5,
      amount: 500000,
      spentAt: now,
      note: 'Xem hoà nhạc',
    ));
    // 500.000 vuot han muc Giai tri 250.000 -> co canh bao "vuot"
    expect(
      first.budgetAlerts.any((a) => a.categoryId == 5 && a.level == BudgetLevel.over),
      isTrue,
    );

    final second = await repo.addExpense(ExpenseDraft(
      categoryId: 5,
      amount: 10000,
      spentAt: now,
    ));
    expect(second.budgetAlerts.where((a) => a.categoryId == 5), isEmpty);

    final photo = await repo.uploadPhoto(first.expense.id, '/tmp/a.jpg', isReceipt: true);
    expect(repo.photoImage(photo.id), isNotNull);

    final day = await repo.getExpenses(from: now, to: now);
    final saved = day.firstWhere((e) => e.id == first.expense.id);
    expect(saved.photos.single.isReceipt, isTrue);
  });

  test('Khong nhan qua 5 anh (BR-05) va so tien ngoai khoang (BR-01)', () async {
    final now = DateTime(2026, 11, 17, 10, 30);
    final repo = MockExpenseRepository(clock: () => now);
    final result = await repo.addExpense(
      ExpenseDraft(categoryId: 1, amount: 45000, spentAt: now),
    );
    for (var i = 0; i < maxPhotosPerExpense; i++) {
      await repo.uploadPhoto(result.expense.id, '/tmp/$i.jpg');
    }
    await expectLater(
      repo.uploadPhoto(result.expense.id, '/tmp/6.jpg'),
      throwsStateError,
    );
    await expectLater(
      repo.addExpense(ExpenseDraft(categoryId: 1, amount: 0, spentAt: now)),
      throwsArgumentError,
    );
  });

  group('Pet theo nhip chi', () {
    BudgetOverview overview(int limit, int spent) => BudgetOverview(
          month: DateTime(2026, 11),
          total: BudgetLine(limit: limit, spent: spent),
        );

    test('dung nhip giua thang van khoe, khong phai gay', () {
      // 3 trieu / 30 ngay, ngay 15 chi 1,5 trieu -> nhip 100%
      final status = petStatusFor(overview(3000000, 1500000), DateTime(2026, 11, 15));
      expect(status.pacePercent, 100);
      expect(status.mood, PetMood.healthy);
    });

    test('cac nguong trang thai', () {
      final day = DateTime(2026, 11, 15); // nen chi 1.500.000
      expect(petStatusFor(overview(3000000, 1000000), day).mood, PetMood.chubby);
      expect(petStatusFor(overview(3000000, 1700000), day).mood, PetMood.thin);
      expect(petStatusFor(overview(3000000, 2100000), day).mood, PetMood.tired);
      expect(petStatusFor(overview(3000000, 2400000), day).mood, PetMood.starving);
    });

    test('vuot muc tieu ca thang thi doi la', () {
      final status = petStatusFor(overview(3000000, 3100000), DateTime(2026, 11, 30));
      expect(status.mood, PetMood.starving);
    });

    test('chua dat muc tieu', () {
      final status = petStatusFor(BudgetOverview(month: DateTime(2026, 11)), DateTime(2026, 11, 15));
      expect(status.mood, PetMood.unknown);
      expect(status.pacePercent, isNull);
    });

    test('dat muc tieu thang moi trong du lieu mau', () async {
      final now = DateTime(2026, 11, 20, 9, 0);
      final repo = MockExpenseRepository(clock: () => now);
      await repo.setMonthlyBudget(DateTime(2026, 11), 3000000);
      final budgets = await repo.getBudgets(DateTime(2026, 11));
      expect(budgets.total?.limit, 3000000);
      await expectLater(repo.setMonthlyBudget(DateTime(2026, 11), 0), throwsArgumentError);
    });
  });
}