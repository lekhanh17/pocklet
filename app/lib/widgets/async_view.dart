import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors.dart';
import '../core/theme.dart';

/// Hien thi AsyncValue: dang tai, loi (kem nut Thu lai) hoac du lieu.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.onRetry,
    this.loadingHeight = 120,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final double loadingHeight;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => SizedBox(
        height: loadingHeight,
        child: const Center(
          child: CircularProgressIndicator.adaptive(strokeWidth: 2),
        ),
      ),
      error: (error, stack) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Không tải được dữ liệu', style: AppText.bodyStrong),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              // Ban debug hien loi goc de sua; ban release hien loi de hieu cho nguoi dung.
              friendlyError(error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: AppColors.inkMuted48),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xs),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}
