import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Cong tac chon kieu iOS: nen chip xam, thanh truot trang chay sang phan duoc chon.
/// Can dat trong khung co chieu ngang xac dinh (vi du SizedBox(width: 240)).
class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  /// Gia tri -> nhan hien thi, theo thu tu tu trai sang phai.
  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final values = segments.keys.toList();
    final index = values.indexOf(selected).clamp(0, values.length - 1);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.dividerSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / values.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.canvas,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.hairline),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final value in values)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: value == selected,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (value == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(value);
                          },
                          child: Center(
                            child: Text(
                              segments[value]!,
                              style: value == selected
                                  ? AppText.captionStrong
                                  : AppText.caption.copyWith(color: AppColors.inkMuted80),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}