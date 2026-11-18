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
