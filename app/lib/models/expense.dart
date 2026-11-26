import 'budget.dart';

/// BR-01: so tien tu 1 den 1.000.000.000 VND.
const maxExpenseAmount = 1000000000;

/// BR-05: toi da 5 anh moi khoan chi.
const maxPhotosPerExpense = 5;

/// Anh cua khoan chi (bang ExpensePhotos, muc 6.3).
class ExpensePhoto {
  const ExpensePhoto({required this.id, this.isReceipt = false});

  final int id;
  final bool isReceipt;

  factory ExpensePhoto.fromJson(Map<String, dynamic> json) {
    return ExpensePhoto(
      id: json['id'] as int,
      isReceipt: (json['isReceipt'] as bool?) ?? false,
    );
  }
}

/// Khoan chi (bang Expenses, muc 6.3).
class Expense {
  const Expense({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.spentAt,
    this.note,
    this.photos = const [],
  });

  final int id;
  final int categoryId;

  /// So nguyen VND (BR-01).
  final int amount;

  /// Gio local (server tra ve theo +07:00).
  final DateTime spentAt;
  final String? note;

  /// Anh theo thu tu tai len, anh dau tien la anh tai len som nhat.
  final List<ExpensePhoto> photos;

  bool get hasPhotos => photos.isNotEmpty;

  Expense copyWith({List<ExpensePhoto>? photos}) {
    return Expense(
      id: id,
      categoryId: categoryId,
      amount: amount,
      spentAt: spentAt,
      note: note,
      photos: photos ?? this.photos,
    );
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    final photos = (json['photos'] as List<dynamic>?) ?? const [];
    return Expense(
      id: json['id'] as int,
      categoryId: json['categoryId'] as int,
      amount: (json['amount'] as num).toInt(),
      spentAt: DateTime.parse(json['spentAt'] as String).toLocal(),
      note: json['note'] as String?,
      photos: photos
          .map((p) => ExpensePhoto.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Du lieu form Them khoan chi, gui len POST /api/expenses.
class ExpenseDraft {
  const ExpenseDraft({
    required this.categoryId,
    required this.amount,
    required this.spentAt,
    this.note,
  });

  final int categoryId;
  final int amount;
  final DateTime spentAt;
  final String? note;

  Map<String, dynamic> toJson() => {
        'categoryId': categoryId,
        'amount': amount,
        'spentAt': isoWithOffset(spentAt),
        'note': note,
      };
}

/// Ket qua POST /api/expenses: khoan chi vua tao + canh bao ngan sach.
class ExpenseSaveResult {
  const ExpenseSaveResult({required this.expense, this.budgetAlerts = const []});

  final Expense expense;
  final List<BudgetAlert> budgetAlerts;

  factory ExpenseSaveResult.fromJson(Map<String, dynamic> json) {
    final alerts = (json['budgetAlerts'] as List<dynamic>?) ?? const [];
    return ExpenseSaveResult(
      expense: Expense.fromJson(json),
      budgetAlerts: alerts
          .map((a) => BudgetAlert.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// ISO 8601 co mui gio, vi du 2026-11-17T07:40:00+07:00 (muc 7 dac ta).
String isoWithOffset(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final offset = d.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}'
      '$sign${two(minutes ~/ 60)}:${two(minutes % 60)}';
}