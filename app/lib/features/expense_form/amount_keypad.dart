import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../widgets/pressable.dart';

/// Phim xoa tren ban phim so.
const keypadDelete = 'del';

/// Ap mot phim vao chuoi so hien tai. Tra ve null neu phim bi tu choi
/// (vuot BR-01 hoac nhap so 0 o dau).
String? applyKeypadKey(String digits, String key) {
  if (key == keypadDelete) {
    return digits.isEmpty ? digits : digits.substring(0, digits.length - 1);
  }
  if (digits.isEmpty && (key == '0' || key == '000')) return null;
  final next = digits + key;
  if (next.length > 10 || int.parse(next) > maxExpenseAmount) return null;
  return next;
}

/// Ban phim so lon co phim "000" (dac ta muc 5.2, man Them khoan chi).
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({super.key, required this.onKey});

  final ValueChanged<String> onKey;

  static const _keys = [
    '1', '2', '3',
    '4', '5', '6',
    '7', '8', '9',
    '000', '0', keypadDelete,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.parchment,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, AppSpacing.xs,
      ),
      child: SafeArea(
        top: false,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 2.4,
          children: [
            for (final key in _keys) _Key(value: key, onTap: () => onKey(key)),
          ],
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.value, required this.onTap});

  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDelete = value == keypadDelete;
    return Pressable(
      semanticLabel: isDelete ? 'Xoá' : value,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDelete ? Colors.transparent : AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: isDelete
            ? const Icon(Icons.backspace_outlined, color: AppColors.ink, size: 24)
            : Text(
                value,
                style: AppText.displayLg.copyWith(fontSize: 26, fontWeight: FontWeight.w400),
              ),
      ),
    );
  }
}