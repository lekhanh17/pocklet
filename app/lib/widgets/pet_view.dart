import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';

/// Pet co hoat anh: tho nhe, nhun len khi cham, to/nho va beo/gay theo trang thai.
/// Ca 3 pet deu tu ve bang code (khong dung hinh cua app khac).
class PetView extends StatefulWidget {
  const PetView({
    super.key,
    required this.kind,
    required this.mood,
    this.size = 200,
    this.onTap,
  });

  final PetKind kind;
  final PetMood mood;

  /// Chieu ngang khi pet o kich thuoc lon nhat.
  final double size;
  final VoidCallback? onTap;

  @override
  State<PetView> createState() => _PetViewState();
}

class _PetViewState extends State<PetView> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _breath.dispose();
    _hop.dispose();
    super.dispose();
  }

  void _onTap() {
    _hop.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.mood;
    // Pet doi lả thi nhun thap hon
    final hopHeight = mood == PetMood.starving ? 5.0 : 16.0;

    return Semantics(
      label: '${widget.kind.label}, ${mood.label}',
      button: widget.onTap != null,
      child: GestureDetector(
        onTap: _onTap,
        child: AnimatedScale(
          scale: mood.scale,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          alignment: Alignment.bottomCenter,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: mood.bodyWidth),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            builder: (context, width, _) => AnimatedBuilder(
              animation: Listenable.merge([_breath, _hop]),
              builder: (context, _) {
                final lift = math.sin(math.pi * _hop.value) * hopHeight;
                return Transform.translate(
                  offset: Offset(0, -lift),
                  child: CustomPaint(
                    size: Size(widget.size, widget.size * 110 / 120),
                    painter: PetPainter(
                      kind: widget.kind,
                      mood: mood,
                      bodyWidth: width,
                      breath: Curves.easeInOut.transform(_breath.value),
                      shadowShrink: lift / 40,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ve pet trong khung logic 120 x 110, tu co gian theo kich thuoc that.
class PetPainter extends CustomPainter {
  PetPainter({
    required this.kind,
    required this.mood,
    required this.bodyWidth,
    this.breath = 0,
    this.shadowShrink = 0,
  });

  final PetKind kind;
  final PetMood mood;

  /// 1 = tron nhat, ~0.54 = gay nhat.
  final double bodyWidth;

  /// 0..1, lam than phinh xep nhu dang tho.
  final double breath;

  /// 0..1, bong mo nho lai khi pet nhay len.
  final double shadowShrink;

  static const _outline = Color(0xFF4A2A12);
  static const _eye = Color(0xFF3A1E0A);
  static const _blush = Color(0x66E0607E);
  static const _sweat = Color(0xFF85B7EB);
  static const _pale = Color(0xFFEDE6DC);

  Color get _baseColor => switch (kind) {
        PetKind.pig => const Color(0xFFF4A3C0),
        PetKind.cat => const Color(0xFFF7C589),
        PetKind.dog => const Color(0xFFE8B27A),
      };

  /// Heo: mui; meo: trong tai; cho: tai.
  Color get _accentColor => switch (kind) {
        PetKind.pig => const Color(0xFFE77FA4),
        PetKind.cat => const Color(0xFFF4A3C0),
        PetKind.dog => const Color(0xFFB9773F),
      };

  static const _dogMuzzle = Color(0xFFFFF1DC);
  static const _tongue = Color(0xFFF08AA8);
  static const _collar = Color(0xFFD85A30);
  static const _coinTag = Color(0xFFEF9F27);

  /// Pet cang doi thi mau cang nhat.
  Color get _bodyColor => switch (mood) {
        PetMood.tired => Color.lerp(_baseColor, _pale, 0.35)!,
        PetMood.starving => Color.lerp(_baseColor, _pale, 0.65)!,
        _ => _baseColor,
      };

  bool get _droopy => mood == PetMood.tired || mood == PetMood.starving;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 110);

    final w = bodyWidth;
    final body = _bodyColor;
    final fill = Paint()..color = body;
    final stroke = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const cx = 60.0;
    const cy = 66.0;
    final rx = 38 * w;
    final ry = (30 - (1 - w) * 6) * (1 + 0.035 * breath);

    // Bong tren san
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(cx, 102),
        width: (rx * 2 + 8) * (1 - 0.3 * shadowShrink),
        height: 9,
      ),
      Paint()..color = const Color(0x2E4A2A12),
    );

    // Duoi va tai phia sau than
    _drawTail(canvas, cx, cy, rx, ry, fill, stroke);

    // Chan
    _drawFeet(canvas, cx, cy, ry, w, fill, stroke);

    // Than
    final bodyRect = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
    canvas.drawOval(bodyRect, fill);
    canvas.drawOval(bodyRect, stroke);

    // Tai phia truoc + dac diem rieng
    switch (kind) {
      case PetKind.pig:
        _drawPigEars(canvas, cx, cy - ry, w, fill, stroke);
        _drawCoinSlot(canvas, cx, cy - ry);
      case PetKind.cat:
        _drawCatEars(canvas, cx, cy - ry, w, fill, stroke);
        _drawCatStripes(canvas, cx, cy - ry, stroke);
      case PetKind.dog:
        _drawDogEars(canvas, cx, cy - ry, w, stroke);
        _drawCollar(canvas, cx, cy, rx, stroke);
    }

    _drawFace(canvas, cx, cy, w, stroke);
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Than va chi tiet
  // ---------------------------------------------------------------------------

  void _drawTail(Canvas canvas, double cx, double cy, double rx, double ry, Paint fill, Paint stroke) {
    final x = cx + rx - 2;
    switch (kind) {
      case PetKind.pig:
        final path = Path()
          ..moveTo(x, cy)
          ..quadraticBezierTo(x + 10, cy - 4, x + 7, cy - 10)
          ..quadraticBezierTo(x + 3, cy - 13, x + 1, cy - 7);
        canvas.drawPath(path, stroke);
      case PetKind.cat:
        final path = Path()
          ..moveTo(x - 4, cy + ry * 0.5)
          ..quadraticBezierTo(x + 16, cy + ry * 0.3, x + 12, cy - ry * 0.6)
          ..quadraticBezierTo(x + 10, cy - ry * 0.9, x + 6, cy - ry * 0.8);
        canvas.drawPath(path, Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
        canvas.drawPath(path, Paint()
          ..color = fill.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
      case PetKind.dog:
        // Vay duoi theo nhip tho; doi lả thi duoi cup xuong
        final wag = _droopy ? 10.0 : (breath - 0.5) * 10;
        final path = Path()
          ..moveTo(x - 3, cy + 4)
          ..quadraticBezierTo(x + 9, cy + 2, x + 12, cy - 10 + wag);
        canvas.drawPath(path, Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round);
        canvas.drawPath(path, Paint()
          ..color = fill.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round);
    }
  }

  void _drawFeet(Canvas canvas, double cx, double cy, double ry, double w, Paint fill, Paint stroke) {
    final bottom = cy + ry;
    if (kind == PetKind.pig) {
      for (final dx in const [-24.0, -11.0, 5.0, 18.0]) {
        final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dx * w, bottom - 8, 7, 12),
          const Radius.circular(3),
        );
        canvas.drawRRect(r, fill);
        canvas.drawRRect(r, stroke);
      }
    } else {
      for (final dx in const [-13.0, 13.0]) {
        final r = Rect.fromCenter(center: Offset(cx + dx * w, bottom - 1), width: 16, height: 10);
        canvas.drawOval(r, fill);
        canvas.drawOval(r, stroke);
      }
    }
  }

  void _drawPigEars(Canvas canvas, double cx, double top, double w, Paint fill, Paint stroke) {
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx + side * 21 * w, top + 4);
      canvas.rotate(side * (_droopy ? 0.9 : 0.45));
      final r = Rect.fromCenter(center: Offset.zero, width: 14, height: 18);
      canvas.drawOval(r, fill);
      canvas.drawOval(r, stroke);
      canvas.restore();
    }
  }

  void _drawCoinSlot(Canvas canvas, double cx, double top) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, top + 5), width: 14, height: 3.6),
        const Radius.circular(1.8),
      ),
      Paint()..color = _outline,
    );
  }

  void _drawCatEars(Canvas canvas, double cx, double top, double w, Paint fill, Paint stroke) {
    for (final side in const [-1.0, 1.0]) {
      final droop = _droopy ? 5.0 : 0.0;
      final outer = Path()
        ..moveTo(cx + side * 30 * w, top + 12)
        ..lineTo(cx + side * (24 * w + droop), top - 14 + droop)
        ..lineTo(cx + side * 9 * w, top + 4)
        ..close();
      canvas.drawPath(outer, fill);
      canvas.drawPath(outer, stroke);
      final inner = Path()
        ..moveTo(cx + side * 26 * w, top + 9)
        ..lineTo(cx + side * (23 * w + droop), top - 6 + droop)
        ..lineTo(cx + side * 14 * w, top + 5)
        ..close();
      canvas.drawPath(inner, Paint()..color = _accentColor);
    }
  }

  void _drawCatStripes(Canvas canvas, double cx, double top, Paint stroke) {
    final p = Paint()
      ..color = const Color(0xFFD9893A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (final dx in const [-6.0, 0.0, 6.0]) {
      canvas.drawLine(Offset(cx + dx, top + 4), Offset(cx + dx, top + 10), p);
    }
  }

  /// Tai cup hai ben dau; met / doi thi rủ thang xuong.
  void _drawDogEars(Canvas canvas, double cx, double top, double w, Paint stroke) {
    final ear = Paint()..color = Color.lerp(_accentColor, _bodyColor, _droopy ? 0.3 : 0)!;
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(cx + side * 27 * w, top + 6);
      canvas.rotate(side * (_droopy ? 0.08 : 0.42));
      final r = Rect.fromLTWH(-7.5, -2, 15, 27);
      canvas.drawOval(r, ear);
      canvas.drawOval(r, stroke);
      canvas.restore();
    }
  }

  /// Vong co do co the dong xu vang (hop chu de tiet kiem).
  void _drawCollar(Canvas canvas, double cx, double cy, double rx, Paint stroke) {
    final band = Path()
      ..moveTo(cx - rx * 0.82, cy + 11)
      ..quadraticBezierTo(cx, cy + 23, cx + rx * 0.82, cy + 11);
    canvas.drawPath(band, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.4
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(band, Paint()
      ..color = _collar
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round);
    final tag = Offset(cx, cy + 21);
    canvas.drawCircle(tag, 4.6, Paint()..color = _coinTag);
    canvas.drawCircle(tag, 4.6, Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6);
  }

  // ---------------------------------------------------------------------------
  // Khuon mat theo tam trang
  // ---------------------------------------------------------------------------

  void _drawFace(Canvas canvas, double cx, double cy, double w, Paint stroke) {
    final eyeY = cy - 9;
    final left = cx - 14 * w;
    final right = cx + 14 * w;
    final eyePaint = Paint()..color = _eye;
    final line = Paint()
      ..color = _eye
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    // Mat
    switch (mood) {
      case PetMood.chubby:
        for (final x in [left, right]) {
          canvas.drawPath(
            Path()
              ..moveTo(x - 4, eyeY + 1)
              ..quadraticBezierTo(x, eyeY - 5, x + 4, eyeY + 1),
            line,
          );
        }
      case PetMood.starving:
        for (final x in [left, right]) {
          canvas.drawLine(Offset(x - 4, eyeY + 1), Offset(x + 4, eyeY + 1), line);
        }
      default:
        final r = switch (mood) {
          PetMood.thin => 2.9,
          PetMood.tired => 2.7,
          _ => 3.3,
        };
        for (final x in [left, right]) {
          canvas.drawCircle(Offset(x, eyeY), r, eyePaint);
          canvas.drawCircle(Offset(x + 1, eyeY - 1), 0.9, Paint()..color = const Color(0xFFFFFFFF));
        }
        if (mood == PetMood.tired) {
          canvas.drawLine(Offset(left - 4, eyeY - 7), Offset(left + 3, eyeY - 5), line);
          canvas.drawLine(Offset(right + 4, eyeY - 7), Offset(right - 3, eyeY - 5), line);
        }
    }

    // Ma hong khi vui
    if (mood == PetMood.chubby || mood == PetMood.healthy || mood == PetMood.unknown) {
      for (final x in [cx - 25 * w, cx + 25 * w]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, cy + 2), width: 9, height: 5),
          Paint()..color = _blush,
        );
      }
    }

    // Mui
    double mouthY;
    if (kind == PetKind.pig) {
      final snout = Rect.fromCenter(
        center: Offset(cx, cy + 1),
        width: 22 * math.max(w, 0.75),
        height: 15,
      );
      canvas.drawOval(snout, Paint()..color = _accentColor);
      canvas.drawOval(snout, stroke..strokeWidth = 2);
      stroke.strokeWidth = 2.2;
      for (final dx in const [-3.5, 3.5]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx + dx, cy + 1), width: 3.2, height: 4.8),
          Paint()..color = _outline,
        );
      }
      mouthY = cy + 13;
    } else if (kind == PetKind.dog) {
      // Mom kem + mui den
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 3), width: 27 * math.max(w, 0.75), height: 17),
        Paint()..color = _dogMuzzle,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy - 1.5), width: 8, height: 5.5),
        Paint()..color = _outline,
      );
      mouthY = cy + 4;
    } else {
      final nose = Path()
        ..moveTo(cx - 3.2, cy - 2)
        ..lineTo(cx + 3.2, cy - 2)
        ..lineTo(cx, cy + 1.6)
        ..close();
      canvas.drawPath(nose, Paint()..color = _accentColor);
      canvas.drawPath(nose, stroke..strokeWidth = 1.6);
      stroke.strokeWidth = 2.2;
      mouthY = cy + 5;

      if (kind == PetKind.cat) {
        final whisker = Paint()
          ..color = _outline
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round;
        for (final side in const [-1.0, 1.0]) {
          for (final dy in const [-1.5, 2.5]) {
            canvas.drawLine(
              Offset(cx + side * 9, cy + dy),
              Offset(cx + side * (9 + 13 * w), cy + dy - 2 + dy * 0.4),
              whisker,
            );
          }
        }
      }
    }

    // Mieng
    final mouth = Path();
    switch (mood) {
      case PetMood.chubby:
        mouth
          ..moveTo(cx - 6, mouthY)
          ..quadraticBezierTo(cx, mouthY + 7, cx + 6, mouthY);
      case PetMood.healthy:
      case PetMood.unknown:
        mouth
          ..moveTo(cx - 5, mouthY + 1)
          ..quadraticBezierTo(cx, mouthY + 5, cx + 5, mouthY + 1);
      case PetMood.thin:
        mouth
          ..moveTo(cx - 4, mouthY + 2)
          ..lineTo(cx + 4, mouthY + 2);
      case PetMood.tired:
        mouth
          ..moveTo(cx - 5, mouthY + 4)
          ..quadraticBezierTo(cx, mouthY - 1, cx + 5, mouthY + 4);
      case PetMood.starving:
        mouth
          ..moveTo(cx - 6, mouthY + 3)
          ..quadraticBezierTo(cx - 3, mouthY, cx, mouthY + 3)
          ..quadraticBezierTo(cx + 3, mouthY + 6, cx + 6, mouthY + 3);
    }
    // Cho le luoi khi vui
    if (kind == PetKind.dog &&
        (mood == PetMood.chubby || mood == PetMood.healthy || mood == PetMood.unknown)) {
      final tongue = RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx, mouthY + 5), width: 7, height: 7),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(tongue, Paint()..color = _tongue);
      canvas.drawRRect(tongue, Paint()
        ..color = _outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4);
    }
    canvas.drawPath(mouth, line..strokeWidth = 2);

    // Giot mo hoi khi met / doi
    if (_droopy) {
      _drawSweat(canvas, Offset(cx + 30 * w, cy - 26));
      if (mood == PetMood.starving) _drawSweat(canvas, Offset(cx - 33 * w, cy - 22));
    }
  }

  void _drawSweat(Canvas canvas, Offset at) {
    final drop = Path()
      ..moveTo(at.dx, at.dy)
      ..quadraticBezierTo(at.dx + 5, at.dy + 7, at.dx, at.dy + 10)
      ..quadraticBezierTo(at.dx - 5, at.dy + 7, at.dx, at.dy)
      ..close();
    canvas.drawPath(drop, Paint()..color = _sweat);
  }

  @override
  bool shouldRepaint(PetPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.mood != mood ||
      oldDelegate.bodyWidth != bodyWidth ||
      oldDelegate.breath != breath ||
      oldDelegate.shadowShrink != shadowShrink;
}