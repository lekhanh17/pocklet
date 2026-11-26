import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';
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
  // Chan vi tri mo dau trong khoang hop le (tranh loi khi danh sach anh thay doi).
  late int _index = widget.photos.isEmpty
      ? 0
      : widget.initialIndex.clamp(0, widget.photos.length - 1);
  late final PageController _controller = PageController(initialPage: _index);

  /// Dang phong to anh: khoa vuot trang de keo xem anh khong bi nhay sang anh khac.
  bool _zoomed = false;

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
        physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
        itemCount: photos.length,
        onPageChanged: (i) => setState(() {
          _index = i;
          _zoomed = false;
        }),
        itemBuilder: (context, i) => _ZoomablePhoto(
          key: ValueKey(photos[i].id),
          photo: photos[i],
          onZoomChanged: (zoomed) {
            if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
          },
        ),
      ),
    );
  }
}

/// Mot anh co the chum de phong; bao ra ngoai khi dang phong hay da tra ve co goc.
class _ZoomablePhoto extends ConsumerStatefulWidget {
  const _ZoomablePhoto({super.key, required this.photo, required this.onZoomChanged});

  final ExpensePhoto photo;
  final ValueChanged<bool> onZoomChanged;

  @override
  ConsumerState<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends ConsumerState<_ZoomablePhoto> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Khung soc thay the khi chua co anh that (du lieu mau) hoac anh tai loi
    final placeholder = Center(
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: PhotoThumb(
          photoId: widget.photo.id,
          isReceipt: widget.photo.isReceipt,
          borderRadius: 0,
        ),
      ),
    );
    final image = ref.watch(expenseRepositoryProvider).photoImage(widget.photo.id);

    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: 4,
      onInteractionEnd: (_) =>
          widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01),
      // Anh that: hien TRON anh (contain), khong cat nhu o thumbnail, de doc duoc
      // ca hoa don dai hay anh ngang (FR-11).
      child: image == null
          ? placeholder
          : SizedBox.expand(
              child: Image(
                image: image,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => placeholder,
              ),
            ),
    );
  }
}
