import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../models/pet.dart';
import '../../widgets/pet_view.dart';
import '../../widgets/pressable.dart';

/// Chon ban dong hanh: Heo dat, Meo, Tho. Dung o lan mo app dau tien
/// (thay cho man Hom nay) va trong sheet "Doi ban".
class PetPickerView extends StatefulWidget {
  const PetPickerView({super.key, required this.onChosen, this.initial});

  final ValueChanged<PetKind> onChosen;
  final PetKind? initial;

  @override
  State<PetPickerView> createState() => _PetPickerViewState();
}

class _PetPickerViewState extends State<PetPickerView> {
  late PetKind _selected = widget.initial ?? PetKind.pig;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Chọn bạn đồng hành', style: AppText.displayMd, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Bạn ấy béo tròn khi bạn chi đúng nhịp, và gầy dần nếu tiêu quá tay.',
          textAlign: TextAlign.center,
          style: AppText.body.copyWith(color: AppColors.inkMuted48),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 190,
          child: Center(
            child: PetView(
              key: ValueKey(_selected),
              kind: _selected,
              mood: PetMood.chubby,
              size: 190,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            for (final kind in PetKind.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                  child: _PetChoice(
                    kind: kind,
                    selected: kind == _selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = kind);
                    },
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => widget.onChosen(_selected),
            child: Text('Nuôi ${_selected.label}'),
          ),
        ),
      ],
    );
  }
}

class _PetChoice extends StatelessWidget {
  const _PetChoice({required this.kind, required this.selected, required this.onTap});

  final PetKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: kind.label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? AppColors.primaryFocus : AppColors.roomBorder,
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: CustomPaint(
                size: const Size(70, 64),
                painter: PetPainter(kind: kind, mood: PetMood.healthy, bodyWidth: 0.88),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              kind.label,
              style: AppText.captionStrong.copyWith(
                color: selected ? AppColors.primary : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Man chon pet lan dau, nam trong tab Hom nay.
class PetPickerScreen extends StatelessWidget {
  const PetPickerScreen({super.key, required this.onChosen});

  final ValueChanged<PetKind> onChosen;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return ColoredBox(
      color: AppColors.roomWall,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomInset + AppSpacing.lg,
            ),
            child: PetPickerView(onChosen: onChosen),
          ),
        ),
      ),
    );
  }
}

/// Sheet "Doi ban" tu trong phong.
Future<void> showPetPickerSheet(
  BuildContext context, {
  required PetKind current,
  required ValueChanged<PetKind> onChosen,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.roomWall,
    builder: (sheetContext) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl,
      ),
      child: PetPickerView(
        initial: current,
        onChosen: (kind) {
          onChosen(kind);
          Navigator.of(sheetContext).pop();
        },
      ),
    ),
  );
}