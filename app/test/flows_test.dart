// Test luong du lieu nhu khi dung app (khong can giao dien): dat muc tieu thi pet
// doi trang thai, them khoan chi thi tong ngay / lich / 7 ngay / ngan sach cung
// cap nhat sau khi lam moi provider.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocklet/core/date_utils.dart';
import 'package:pocklet/data/mock_expense_repository.dart';
import 'package:pocklet/models/expense.dart';
import 'package:pocklet/models/pet.dart';
import 'package:pocklet/providers/app_providers.dart';

class _FixedToday extends TodayNotifier {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

/// Giong refreshExpenseData(ref) cua app, nhung goi tren ProviderContainer.
void _refresh(ProviderContainer c) {
  c.invalidate(dayExpensesProvider);
  c.invalidate(calendarMonthProvider);
  c.invalidate(budgetOverviewProvider);
  c.invalidate(last7DaysProvider);
}

void main() {
  final now = DateTime(2026, 11, 20, 21, 0);
  final today = dateOnly(now);
  final month = monthOf(today);

  late MockExpenseRepository repo;
  late ProviderContainer c;

  setUp(() {
    repo = MockExpenseRepository(clock: () => now);
    c = ProviderContainer(overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
      todayProvider.overrideWith(() => _FixedToday(today)),
    ]);
  });
  tearDown(() => c.dispose());

  test('Dat muc tieu thap thi pet gay di, muc tieu cao thi beo lai (FR-16, FR-30)', () async {
    final spent = (await c.read(budgetOverviewProvider(month).future)).total!.spent;

    // Muc tieu = 1,1 lan so da chi, ngay 20/30: nhip ~ 1,5 / 1,1 ~ 136% -> Gay, met
    await repo.setMonthlyBudget(month, (spent * 1.1).round());
    _refresh(c);
    var status = petStatusFor(await c.read(budgetOverviewProvider(month).future), today);
    expect(status.mood, PetMood.tired);
    expect(status.pacePercent! > 120 && status.pacePercent! < 150, isTrue);

    // Muc tieu gap 3 lan: nhip 50% -> Beo tron
    await repo.setMonthlyBudget(month, spent * 3);
    _refresh(c);
    status = petStatusFor(await c.read(budgetOverviewProvider(month).future), today);
    expect(status.mood, PetMood.chubby);
  });

  test('Them khoan chi: tong ngay, lich, 7 ngay, ngan sach deu tang dung so tien', () async {
    final dayBefore = await c.read(dayExpensesProvider(today).future);
    final calBefore = await c.read(calendarMonthProvider(month).future);
    final weekBefore = await c.read(last7DaysProvider.future);
    final budgetBefore = await c.read(budgetOverviewProvider(month).future);

    final saved = await repo.addExpense(ExpenseDraft(
      categoryId: 2,
      amount: 65000,
      spentAt: now.subtract(const Duration(minutes: 5)),
      note: 'Grab',
    ));
    _refresh(c);

    final dayAfter = await c.read(dayExpensesProvider(today).future);
    final calAfter = await c.read(calendarMonthProvider(month).future);
    final weekAfter = await c.read(last7DaysProvider.future);
    final budgetAfter = await c.read(budgetOverviewProvider(month).future);

    expect(dayAfter.length, dayBefore.length + 1);
    expect(dayAfter.any((e) => e.id == saved.expense.id), isTrue);
    // Danh sach ngay xep moi nhat truoc
    for (var i = 1; i < dayAfter.length; i++) {
      expect(dayAfter[i - 1].spentAt.isBefore(dayAfter[i].spentAt), isFalse);
    }
    expect(calAfter.total, calBefore.total + 65000);
    expect(calAfter.byDay[today.day]!.count, calBefore.byDay[today.day]!.count + 1);
    expect(weekAfter.last.total, weekBefore.last.total + 65000);
    expect(budgetAfter.total!.spent, budgetBefore.total!.spent + 65000);
    // So tren o lich khop tong danh sach ngay (FR-14)
    expect(calAfter.byDay[today.day]!.total, dayAfter.fold<int>(0, (s, e) => s + e.amount));
  });

  test('Khong co ngay tuong lai trong 7 ngay qua va trong lich', () async {
    final week = await c.read(last7DaysProvider.future);
    expect(week.every((d) => !d.date.isAfter(today)), isTrue);
    final cal = await c.read(calendarMonthProvider(month).future);
    expect(cal.days.every((d) => !d.date.isAfter(today)), isTrue);
  });

  test('Ngay dang chon va thang dang xem mac dinh la hom nay (FR-14)', () {
    expect(c.read(selectedDateProvider), today);
    expect(c.read(visibleMonthProvider), month);
  });
}
