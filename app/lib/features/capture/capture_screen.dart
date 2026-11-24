import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../models/expense.dart';
import '../../widgets/photo_thumb.dart';
import '../../widgets/pressable.dart';
import '../expense_form/add_expense_screen.dart';

/// Man Camera (dac ta muc 5.2, FR-10) theo kieu Locket:
/// 1. Chup (hoac chon tu thu vien) trong khung vuong.
/// 2. Xem lai anh, go ghi chu ngay tren anh (muc tieu 1: "chup xong ghi chu luon tren anh").
/// 3. Bam Tiep -> form chi con so tien + danh muc.
/// Tra ve ExpenseSaveResult khi nguoi dung luu xong khoan chi.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  String? _error;
  bool _initializing = false;
  bool _busy = false;

  /// Chop trang ngan khi bam chup.
  bool _flash = false;

  /// Anh vua chup / chon dang xem lai. Null la dang o che do chup.
  List<String>? _reviewPaths;
  final _noteController = TextEditingController();
  final _noteFocus = FocusNode();

  bool get _reviewing => _reviewPaths != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Camera
  // -------------------------------------------------------------------------

  /// Tat camera khi app vao nen, mo lai khi quay ve.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final controller = _controller;
      if (controller == null || _initializing) return;
      setState(() => _controller = null);
      controller.dispose();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        !_initializing &&
        _cameras.isNotEmpty &&
        _error == null) {
      _startCamera();
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = _messageFor(e));
      return;
    }
    if (_cameras.isEmpty) {
      if (mounted) setState(() => _error = 'Không tìm thấy camera trên máy.');
      return;
    }
    final back = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    _cameraIndex = back < 0 ? 0 : back;
    await _startCamera();
  }

  Future<void> _startCamera() async {
    _initializing = true;
    final old = _controller;
    if (old != null) {
      setState(() => _controller = null);
      await old.dispose();
    }

    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on CameraException catch (e) {
      await controller.dispose();
      _initializing = false;
      if (mounted) setState(() => _error = _messageFor(e));
      return;
    }
    _initializing = false;
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _error = null;
    });
    // Dang xem lai anh thi tam dung khung xem truoc
    if (_reviewing) await controller.pausePreview();
  }

  String _messageFor(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Chưa cấp quyền camera. Bật trong Cài đặt của máy, '
            'hoặc chọn ảnh từ thư viện.';
      default:
        return 'Không mở được camera (${e.code}).';
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _initializing) return;
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _startCamera();
  }

  Future<void> _pausePreview() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.pausePreview();
    }
  }

  Future<void> _resumePreview() async {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      await controller.resumePreview();
    }
  }

  // -------------------------------------------------------------------------
  // Chup -> xem lai + ghi chu -> form
  // -------------------------------------------------------------------------

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _flash = true;
    });
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (mounted) setState(() => _flash = false);
    });
    try {
      final file = await controller.takePicture();
      await _pausePreview();
      if (!mounted) return;
      _startReview([file.path]);
    } on CameraException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không chụp được ảnh (${e.code})')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final files = await ImagePicker().pickMultiImage(limit: maxPhotosPerExpense);
    if (files.isEmpty || !mounted) return;
    await _pausePreview();
    if (!mounted) return;
    _startReview(files.take(maxPhotosPerExpense).map((f) => f.path).toList());
  }

  void _startReview(List<String> paths) {
    setState(() => _reviewPaths = paths);
    // Mo ban phim ngay de go ghi chu, giong Locket
    _noteFocus.requestFocus();
  }

  /// Bo anh vua chup, quay lai che do chup.
  Future<void> _retake() async {
    _noteFocus.unfocus();
    setState(() {
      _reviewPaths = null;
      _noteController.clear();
    });
    await _resumePreview();
  }

  /// Mo form so tien + danh muc. Luu xong thi dong man Camera va tra ket qua.
  Future<void> _openForm() async {
    _noteFocus.unfocus();
    final paths = _reviewPaths ?? const <String>[];
    if (!_reviewing) await _pausePreview();
    if (!mounted) return;

    final result = await Navigator.of(context).push<ExpenseSaveResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AddExpenseScreen(
          initialPhotos: paths,
          initialNote: _noteController.text.trim(),
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      Navigator.of(context).pop(result);
      return;
    }
    // Huy form: dang xem lai anh thi giu nguyen anh + ghi chu;
    // nhap khong anh thi quay lai chup
    if (!_reviewing) await _resumePreview();
  }

  // -------------------------------------------------------------------------
  // Giao dien
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceBlack,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.close,
                    label: 'Đóng',
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      _reviewing ? 'Thêm ghi chú' : 'Chụp khoản chi',
                      textAlign: TextAlign.center,
                      style: AppText.bodyStrong.copyWith(color: AppColors.bodyOnDark),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg * 2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ColoredBox(
                            color: AppColors.tile1,
                            child: _reviewing ? _buildReview() : _buildPreview(),
                          ),
                          IgnorePointer(
                            child: AnimatedOpacity(
                              opacity: _flash ? 0.85 : 0,
                              duration: Duration(milliseconds: _flash ? 40 : 220),
                              child: const ColoredBox(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_reviewing) _buildReviewControls() else _buildCaptureControls(),
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
      ),
    );
  }

  /// Che do chup: Quet hoa don, Thu vien - Chup - Doi camera, Nhap khong anh.
  Widget _buildCaptureControls() {
    return Column(
      children: [
        Pressable(
          // TODO(FR-22): quet hoa don bang OCR
          onTap: () => showComingSoon(context, 'Quét hoá đơn'),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.tile1,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.document_scanner_outlined,
                    color: AppColors.bodyOnDark, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Quét hoá đơn',
                  style: AppText.captionStrong.copyWith(color: AppColors.bodyOnDark),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.photo_library_outlined,
              label: 'Chọn từ thư viện',
              onTap: _pickFromGallery,
            ),
            _ShutterButton(
              busy: _busy,
              onTap: _controller == null ? null : _takePicture,
            ),
            _RoundButton(
              icon: Icons.cameraswitch_outlined,
              label: 'Đổi camera',
              onTap: _cameras.length > 1 ? _switchCamera : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryOnDark),
          onPressed: _openForm,
          child: const Text('Nhập không có ảnh'),
        ),
      ],
    );
  }

  /// Che do xem lai: Chup lai - Tiep.
  Widget _buildReviewControls() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RoundButton(
            icon: Icons.refresh,
            label: 'Chụp lại',
            onTap: _retake,
          ),
          _NextButton(onTap: _openForm),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  /// Anh vua chup + o ghi chu nam tren anh.
  Widget _buildReview() {
    final paths = _reviewPaths!;
    return GestureDetector(
      // Cham ra ngoai o ghi chu thi an ban phim
      onTap: () => _noteFocus.unfocus(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(File(paths.first), fit: BoxFit.cover, cacheWidth: 1080),
          if (paths.length > 1)
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: OverlayChip(label: '+${paths.length - 1} ảnh'),
            ),
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: Center(child: _NoteOnPhoto(controller: _noteController, focusNode: _noteFocus)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final error = _error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_outlined, color: AppColors.bodyMuted, size: 40),
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(color: AppColors.bodyMuted),
            ),
          ],
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    // Cat anh xem truoc thanh hinh vuong. previewSize theo chieu ngang nen dao lai.
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.height,
        height: size.width,
        child: CameraPreview(controller),
      ),
    );
  }
}

/// O ghi chu vien thuoc nam tren anh (kieu Locket).
class _NoteOnPhoto extends StatelessWidget {
  const _NoteOnPhoto({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.chipTranslucent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        maxLength: 200, // Expenses.Note nvarchar(200)
        maxLines: 1,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => focusNode.unfocus(),
        style: AppText.bodyStrong,
        cursorColor: AppColors.primary,
        decoration: InputDecoration.collapsed(
          hintText: 'Thêm ghi chú…',
          hintStyle: AppText.body.copyWith(color: AppColors.inkMuted80),
        ).copyWith(counterText: ''),
      ),
    );
  }
}

/// Nut tron 48px tren nen toi.
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: label,
      child: Pressable(
        semanticLabel: label,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: AppColors.tile1,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.bodyOnDark : AppColors.inkMuted48,
          ),
        ),
      ),
    );
  }
}

/// Nut chup: vong trang ngoai, hinh tron trang ben trong.
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Chụp',
      onTap: busy ? null : onTap,
      child: Container(
        width: 78,
        height: 78,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bodyOnDark, width: 4),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: busy || onTap == null ? AppColors.inkMuted48 : AppColors.bodyOnDark,
          ),
        ),
      ),
    );
  }
}

/// Nut Tiep (sau khi xem lai anh): tron xanh co mui ten.
class _NextButton extends StatelessWidget {
  const _NextButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'Tiếp',
      onTap: onTap,
      child: Container(
        width: 78,
        height: 78,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_forward, color: Colors.white, size: 32),
      ),
    );
  }
}