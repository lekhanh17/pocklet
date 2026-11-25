import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Vien net dut bo goc, dung cho ngay khong chi va o "Chup khoan moi".
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({
    required this.color,
    this.radius = AppRadius.sm,
    this.strokeWidth = 1,
    this.dash = 4,
    this.gap = 3,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  /// Duong net dut da tinh, dung chung cho moi o cung kich thuoc (cac o lich giong nhau):
  /// tinh PathMetric mot lan thay vi moi lan ve lai ca luoi.
  static final _cache = <(double, double, double, double, double, double), Path>{};

  Path _dashedPath(Size size) {
    final key = (size.width, size.height, radius, strokeWidth, dash, gap);
    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.length > 64) _cache.clear();

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    ).deflate(strokeWidth / 2);
    final source = Path()..addRRect(rrect);
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        dashed.addPath(metric.extractPath(distance, next), Offset.zero);
        distance = next + gap;
      }
    }
    return _cache[key] = dashed;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    // Mot lenh ve cho ca duong vien thay vi mot lenh cho tung doan.
    canvas.drawPath(_dashedPath(size), paint);
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dash != dash ||
      oldDelegate.gap != gap;
}

/// Hop net dut voi noi dung o giua.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.color = AppColors.inkMuted48,
    this.radius = AppRadius.sm,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}
