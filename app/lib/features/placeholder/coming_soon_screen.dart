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
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(title: Text(title)),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: AppColors.inkMuted48),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Màn này sẽ làm ở đợt sau ($requirements).',
                  textAlign: TextAlign.center,
                  style: AppText.body.copyWith(color: AppColors.inkMuted48),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}