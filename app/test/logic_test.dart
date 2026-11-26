// Test cho dot sua loi tren nhanh phong-pet: dinh dang so tien nho, chu cai dau,
// qua ngay moi, 7 ngay qua, gioi han thang tren Lich, muc canh bao tu API,
// nen anh (BR-05) va thong bao loi.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pocklet/core/errors.dart';
import 'package:pocklet/core/format.dart';
import 'package:pocklet/core/image_compress.dart';
import 'package:pocklet/data/mock_expense_repository.dart';
import 'package:pocklet/models/budget.dart';
import 'package:pocklet/models/calendar.dart';
import 'package:pocklet/models/expense.dart';
import 'package:pocklet/providers/app_providers.dart';

/// Hom nay co dinh cho test (khong phu thuoc dong ho may).
class _FixedToday extends TodayNotifier {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

void main() {
  group('formatShort', () {
    test('duoi 1.000 giu nguyen so, khong thanh "0k" hay "1k"', () {
      expect(formatShort(500), '500');
      expect(formatShort(999), '999');
      expect(formatShort(1000), '1k');
      expect(formatShort(45500), '46k');
    });
  });

  group('initialOf', () {
    test('chu co dau, khoang trang, emoji', () {
      expect(initialOf('đức'), 'Đ');
      expect(initialOf('  Khánh Lê '), 'K');
      expect(initialOf('   '), '?');
      expect(initialOf('😀 An'), '😀');
    });
  });

  test('Lich khong mo thang tuong lai', () {
    final today = DateTime(2026, 11, 25);
    expect(canShowMonth(DateTime(2026, 11), today), isTrue);
    expect(canShowMonth(DateTime(2026, 10), today), isTrue);
    expect(canShowMonth(DateTime(2026, 12), today), isFalse);
    expect(canShowMonth(DateTime(2027, 1, 15), today), isFalse);
  });

  test('CalendarMonth.byDay tinh mot lan', () {
    final m = CalendarMonth(
      month: DateTime(2026, 11),
      total: 30000,
      days: [
        CalendarDay(date: DateTime(2026, 11, 3), total: 10000, count: 1, coverPhotoId: 5),
        CalendarDay(date: DateTime(2026, 11, 9), total: 20000, count: 2),
      ],
    );
    expect(identical(m.byDay, m.byDay), isTrue);
    expect(m.byDay[9]?.total, 20000);
    expect(m.daysWithPhoto, 1);
  });

  group('Muc ngan sach tu API (api/README.md)', () {
    test('"exceeded" la vuot, "warning" la sap het', () {
      final over = BudgetAlert.fromJson({'categoryId': 5, 'level': 'exceeded', 'percent': 200});
      final warn = BudgetAlert.fromJson({'categoryId': null, 'level': 'warning', 'percent': 85});
      expect(over.level, BudgetLevel.over);
      expect(warn.level, BudgetLevel.warning);
      expect(warn.categoryId, isNull);
    });

    test('phan tram lam tron xuong giong server', () {
      // 79,6%: chua toi nguong 80% nen khong duoc hien "80%"
      const line = BudgetLine(limit: 1000000, spent: 796000);
      expect(line.percent, 79);
      expect(line.level, BudgetLevel.normal);
    });

    test('doc GET /api/budgets', () {
      final o = BudgetOverview.fromJson({
        'month': '2026-11',
        'total': {'categoryId': null, 'limitAmount': 5000000, 'spent': 1200000},
        'categories': [
          {'categoryId': 1, 'limitAmount': 1500000, 'spent': 1300000},
        ],
      });
      expect(o.month, DateTime(2026, 11));
      expect(o.total?.limit, 5000000);
      expect(o.alerts.single.categoryId, 1);
    });
  });

  test('Du lieu mau: qua ngay moi co du lieu hom nay, khoan vua them van con', () async {
    var now = DateTime(2026, 11, 24, 23, 50);
    final repo = MockExpenseRepository(clock: () => now);
    final added = await repo.addExpense(
      ExpenseDraft(categoryId: 1, amount: 45000, spentAt: now, note: 'Bún bò'),
    );

    now = DateTime(2026, 11, 25, 8, 0);
    final today = await repo.getExpenses(from: DateTime(2026, 11, 25), to: DateTime(2026, 11, 25));
    expect(today, isNotEmpty);
    expect(today.every((e) => !e.spentAt.isAfter(now)), isTrue);

    final yesterday = await repo.getExpenses(from: DateTime(2026, 11, 24), to: DateTime(2026, 11, 24));
    expect(yesterday.any((e) => e.id == added.expense.id), isTrue);
  });

  test('7 ngay qua: dung 7 o, tong tung ngay khop danh sach khoan chi', () async {
    final today = DateTime(2026, 11, 25);
    final repo = MockExpenseRepository(clock: () => DateTime(2026, 11, 25, 21, 0));
    final container = ProviderContainer(overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
      todayProvider.overrideWith(() => _FixedToday(today)),
    ]);
    addTearDown(container.dispose);

    final days = await container.read(last7DaysProvider.future);
    expect(days.length, 7);
    expect(days.first.date, DateTime(2026, 11, 19));
    expect(days.last.date, today);

    for (final d in days) {
      final items = await repo.getExpenses(from: d.date, to: d.date);
      expect(d.total, items.fold<int>(0, (s, e) => s + e.amount));
      expect(d.count, items.length);
    }
  });

  group('Nen anh (BR-05)', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pocklet_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('anh lon thu ve canh dai 1280 px, JPEG duoi 2 MB', () async {
      final source = img.Image(width: 2000, height: 1000);
      for (final p in source) {
        p.setRgb(p.x % 256, p.y % 256, (p.x + p.y) % 256);
      }
      final file = File('${dir.path}/a.png')..writeAsBytesSync(img.encodePng(source));

      final out = await compressPhoto(file.path);
      final decoded = img.decodeJpg(out.readAsBytesSync())!;
      expect(decoded.width, maxPhotoSide);
      expect(decoded.height, 640);
      expect(out.lengthSync() <= maxPhotoBytes, isTrue);
    });

    test('file khong phai anh: bao loi rieng, khong phai loi mang', () async {
      final file = File('${dir.path}/b.heic')..writeAsBytesSync(List.filled(64, 7));
      await expectLater(compressPhoto(file.path), throwsA(isA<PhotoUnreadableException>()));
    });
  });

  test('Thong bao loi: loi kiem tra du lieu hien nguyen van', () {
    expect(
      friendlyError(ArgumentError('Số tiền phải từ 1 đến 1.000.000.000 ₫')),
      'Số tiền phải từ 1 đến 1.000.000.000 ₫',
    );
  });
}
