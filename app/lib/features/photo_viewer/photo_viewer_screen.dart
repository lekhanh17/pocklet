import 'package:flutter/material.dart';

import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../widgets/photo_thumb.dart';

/// Xem anh toan man hinh: nen den, vuot qua lai, chum hai ngon de phong (FR-11).
class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  final List<ExpensePhoto> photos;
  final int initialIndex;

  static Future<void> open(
    BuildContext context,
    List<ExpensePhoto> photos,
    int initialIndex,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PhotoViewerScreen(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;

    return Scaffold(
      backgroundColor: AppColors.surfaceBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceBlack,
        foregroundColor: AppColors.bodyOnDark,
        title: Text(
          '${_index + 1}/${photos.length}',
          style: AppText.bodyStrong.copyWith(color: AppColors.bodyOnDark),
        ),
        actions: [
          IconButton(
            tooltip: 'Xoá ảnh',
            // Tren nen toi dung xanh sang (primaryOnDark)
            color: AppColors.primaryOnDark,
            icon: const Icon(Icons.delete_outline),
            // TODO(FR-12): goi DELETE /api/photos/{id}
            onPressed: () => showComingSoon(context, 'Xoá ảnh'),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: PhotoThumb(
                photoId: photos[i].id,
                isReceipt: photos[i].isReceipt,
                borderRadius: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
