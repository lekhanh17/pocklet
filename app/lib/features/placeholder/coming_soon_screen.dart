import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Man tam cho cac tab chua lam trong dot nay.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.requirements,
  });

  final String title;
  final IconData icon;
  final String requirements;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: AppColors.inkMuted48),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppText.displayMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Màn này sẽ làm ở đợt sau ($requirements).',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.inkMuted48),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
