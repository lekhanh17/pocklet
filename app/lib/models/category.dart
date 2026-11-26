import 'package:flutter/material.dart';

/// Danh muc chi tieu (bang Categories, muc 6.3).
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.isDefault = true,
  });

  final int id;
  final String name;

  /// Ten bieu tuong Material, vi du "restaurant".
  final String iconName;

  /// Dang #RRGGBB.
  final String colorHex;

  /// Danh muc mac dinh (UserId null) thi khong sua, khong xoa (BR-03).
  final bool isDefault;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      iconName: json['icon'] as String,
      colorHex: json['color'] as String,
      // API tra san isDefault (CategoryDto), khong tra userId.
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  Color get color =>
      Color(int.parse(colorHex.substring(1), radix: 16) | 0xFF000000);

  IconData get icon => _icons[iconName] ?? Icons.category_outlined;

  static const unknown = ExpenseCategory(
    id: 0,
    name: 'Khác',
    iconName: 'more_horiz',
    colorHex: '#78716C',
  );

  static const Map<String, IconData> _icons = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'sports_esports': Icons.sports_esports,
    'medical_services': Icons.medical_services,
    'school': Icons.school,
    'more_horiz': Icons.more_horiz,
  };
}
