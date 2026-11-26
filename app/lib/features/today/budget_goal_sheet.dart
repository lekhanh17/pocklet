import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../widgets/pressable.dart';
import '../expense_form/amount_keypad.dart';

/// Sheet dat muc tieu chi cua thang (ngan sach tong, FR-16).
Future<void> showBudgetGoalSheet(
  BuildContext context, {
  required DateTime month,
  int? current,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.parchment,
    builder: (_) => _BudgetGoalSheet(month: month, current: current),
  );
}

class _BudgetGoalSheet extends ConsumerStatefulWidget {
  const _BudgetGoalSheet({required this.month, this.current});

  final DateTime month;
  final int? current;

  @override
  ConsumerState<_BudgetGoalSheet> createState() => _BudgetGoalSheetState();
}

class _BudgetGoalSheetState extends ConsumerState<_BudgetGoalSheet> {
  late String _digits = widget.current?.toString() ?? '';
  bool _saving = false;

  static const _presets = [2000000, 3000000, 5000000];

  int get _amount => _digits.isEmpty ? 0 : int.parse(_digits);

  void _onKey(String key) {
    final next = applyKeypadKey(_digits, key);
    if (next == null) {
      HapticFeedback.heavyImpact();
      return;
    }
    setState(() => _digits = next);
  }

  Future<void> _save() async {
    if (_amount <= 0 || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(expenseRepositoryProvider).setMonthlyBudget(widget.month, _amount);
      if (!mounted) return;
      refreshExpenseData(ref);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được mục tiêu. ${friendlyError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          child: Column(
            children: [
              Text('Mục tiêu chi tháng ${widget.month.month}', style: AppText.tagline),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Chi đúng nhịp mục tiêu thì bạn đồng hành sẽ luôn khoẻ mạnh.',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.inkMuted48),
              ),
              const SizedBox(height: AppSpacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      formatGrouped(_amount),
                      style: AppText.displayLg.copyWith(
                        color: _amount == 0 ? AppColors.inkMuted48 : AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('₫', style: AppText.tagline.copyWith(color: AppColors.inkMuted48)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final preset in _presets)
                    Pressable(
                      onTap: () => setState(() => _digits = preset.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _amount == preset ? AppColors.primary : AppColors.canvas,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(color: AppColors.roomBorder, width: 1.5),
                        ),
                        child: Text(
                          formatShort(preset),
                          style: AppText.captionStrong.copyWith(
                            color: _amount == preset ? Colors.white : AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _amount > 0 && !_saving ? _save : null,
                  child: Text(_saving ? 'Đang lưu…' : 'Lưu mục tiêu'),
                ),
              ),
            ],
          ),
        ),
        AmountKeypad(onKey: _saving ? (_) {} : _onKey),
      ],
    );
  }
}