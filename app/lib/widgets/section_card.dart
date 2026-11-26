import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'pressable.dart';

/// The bo goc 18, nen trang vien hairline, khong do bong.
/// dark = true: the toi (#272729, chu trang) de tao nhip sang - toi.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.dark = false,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool dark;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppColors.tile1 : AppColors.canvas,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: dark ? null : Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}
