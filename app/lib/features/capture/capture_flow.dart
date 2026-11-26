import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/budget.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';
import 'capture_screen.dart';

/// Luong ghi khoan chi (dac ta muc 4.1): mo Camera -> form -> luu.
/// Luu xong thi bao ket qua va canh bao ngan sach ngay (FR-18).
Future<void> startCaptureFlow(BuildContext context, WidgetRef ref) async {
  final result = await Navigator.of(context).push<ExpenseSaveResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const CaptureScreen(),
    ),
  );
  if (result == null || !context.mounted) return;

  final categories =
      ref.read(categoryMapProvider).valueOrNull ?? const <int, ExpenseCategory>{};
  String nameOf(int? id) => id == null
      ? 'Ngân sách tháng'
      : (categories[id] ?? ExpenseCategory.unknown).name;

  final lines = [
    'Đã lưu ${formatVnd(result.expense.amount)} · ${nameOf(result.expense.categoryId)}',
    for (final alert in result.budgetAlerts)
      alert.level == BudgetLevel.over
          ? '${nameOf(alert.categoryId)} đã vượt (${alert.percent}%)'
          : '${nameOf(alert.categoryId)} sắp hết (${alert.percent}%)',
  ];

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(lines.join('\n')),
      duration: Duration(seconds: result.budgetAlerts.isEmpty ? 3 : 6),
    ));
}