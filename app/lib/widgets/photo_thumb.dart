import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../models/category.dart';

const _palette = [
  Color(0xFFE07A5F),
  Color(0xFF3D85C6),
  Color(0xFF81B29A),
  Color(0xFFE0A458),
  Color(0xFF9C6ADE),
  Color(0xFF5E8C8A),
];

Color placeholderColorFor(int photoId) => _palette[photoId % _palette.length];

/// Anh cua khoan chi. Hien tai la khung soc (giong mockup) vi chua co API.
///
/// TODO(API): thay CustomPaint bang
///   Image.network('$baseUrl/api/photos/$photoId',
///       headers: {'Authorization': 'Bearer $token'}, fit: BoxFit.cover)
/// Chi can sua o day, moi man hinh deu dung PhotoThumb.
/// PhotoThumb phai nam trong khung co kich thuoc xac dinh.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.photoId,
    this.isReceipt = false,
    this.borderRadius = AppRadius.sm,
    this.showIcon = true,
  });

  final int photoId;
  final bool isReceipt;
  final double borderRadius;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final color = placeholderColorFor(photoId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: _StripePainter(color),
        child: SizedBox.expand(
          child: showIcon
              ? Center(
                  child: Icon(
                    isReceipt ? Icons.receipt_long : Icons.image_outlined,
                    color: color.withAlpha(220),
                    size: 28,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = color.withAlpha(55));
    final stripe = Paint()
      ..color = color.withAlpha(95)
      ..strokeWidth = 6;
    canvas.save();
    canvas.clipRect(rect);
    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.color != color;
}

/// O thay anh cho khoan chi khong co anh: bieu tuong danh muc.
class CategoryTile extends StatelessWidget {
  const CategoryTile({
    super.key,
    required this.category,
    this.borderRadius = AppRadius.sm,
  });

  final ExpenseCategory category;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: category.color.withAlpha(30),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(category.icon, color: category.color, size: 36),
    );
  }
}

/// Nhan vien thuoc trong suot de len anh (#d2d2d7 ~64%), chu mau ink.
class OverlayChip extends StatelessWidget {
  const OverlayChip({super.key, required this.label, this.small = false});

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 5 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.chipTranslucent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: (small ? AppText.micro : AppText.finePrint)
            .copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// So tien de len anh.
class AmountChip extends StatelessWidget {
  const AmountChip({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => OverlayChip(label: formatVnd(amount));
}

/// Nhan "+1" khi khoan chi co nhieu anh.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.extra});

  final int extra;

  @override
  Widget build(BuildContext context) => OverlayChip(label: '+$extra');
}
