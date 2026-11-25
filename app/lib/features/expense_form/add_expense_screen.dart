import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/date_utils.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/image_compress.dart';
import '../../core/theme.dart';
import '../../models/category.dart';
import '../../models/expense.dart';
import '../../providers/app_providers.dart';
import '../../widgets/async_view.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_card.dart';
import 'amount_keypad.dart';

/// Anh dang cho trong form, chua tai len.
class _PendingPhoto {
  _PendingPhoto(this.path);

  final String path;
  bool isReceipt = false;

  /// File da nen (BR-05). Giu lai de bam "Thu lai" khong phai nen lai tu dau.
  String? compressedPath;
}

/// Man Them khoan chi (dac ta muc 5.2; FR-07, FR-10, FR-12; luong 4.1).
/// Chi can so tien + danh muc la luu duoc; thoi diem mac dinh la bay gio.
/// Pop ve ExpenseSaveResult khi luu xong.
class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({
    super.key,
    this.initialPhotos = const [],
    this.initialNote = '',
  });

  /// Duong dan anh goc (chua nen) tu man Camera.
  final List<String> initialPhotos;

  /// Ghi chu da go tren anh o man Camera (kieu Locket).
  final String initialNote;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final List<_PendingPhoto> _photos = [
    for (final path in widget.initialPhotos.take(maxPhotosPerExpense)) _PendingPhoto(path),
  ];
  late final _noteController = TextEditingController(text: widget.initialNote);
  final _noteFocus = FocusNode();

  String _digits = '';
  int? _categoryId;
  DateTime _spentAt = DateTime.now();
  bool _saving = false;

  int get _amount => _digits.isEmpty ? 0 : int.parse(_digits);

  bool get _canSave => _amount >= 1 && _categoryId != null && !_saving;

  @override
  void initState() {
    super.initState();
    // An ban phim so khi dang go ghi chu. Kiem tra mounted: focus doi ca luc man dang dong.
    _noteFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocus.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    final next = applyKeypadKey(_digits, key);
    if (next == null) {
      HapticFeedback.heavyImpact(); // vuot 1.000.000.000 ₫ (BR-01)
      return;
    }
    setState(() => _digits = next);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // -------------------------------------------------------------------------
  // Anh (FR-10, FR-12)
  // -------------------------------------------------------------------------

  Future<void> _addPhotos() async {
    final remaining = maxPhotosPerExpense - _photos.length;
    if (remaining <= 0) {
      _showMessage('Tối đa $maxPhotosPerExpense ảnh mỗi khoản chi');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.canvas,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
              title: const Text('Chụp ảnh'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final paths = <String>[];
    try {
      // maxWidth/maxHeight: may tu doi HEIC sang JPEG va thu nho (xem pickerMaxSide)
      if (source == ImageSource.gallery && remaining > 1) {
        final files = await picker.pickMultiImage(
          limit: remaining,
          maxWidth: pickerMaxSide,
          maxHeight: pickerMaxSide,
        );
        paths.addAll(files.take(remaining).map((f) => f.path));
      } else {
        final file = await picker.pickImage(
          source: source,
          maxWidth: pickerMaxSide,
          maxHeight: pickerMaxSide,
        );
        if (file != null) paths.add(file.path);
      }
    } on PlatformException {
      // Thuong la chua cap quyen camera / thu vien anh
      if (mounted) _showMessage('Không mở được ${source == ImageSource.camera ? 'camera' : 'thư viện ảnh'}. Kiểm tra quyền trong Cài đặt.');
      return;
    }
    if (!mounted || paths.isEmpty) return;
    setState(() => _photos.addAll(paths.map(_PendingPhoto.new)));
  }

  // -------------------------------------------------------------------------
  // Thoi gian (BR-02: khong cho chon sau hien tai)
  // -------------------------------------------------------------------------

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_spentAt),
    );
    if (!mounted) return;
    final t = time ?? TimeOfDay.fromDateTime(_spentAt);
    var picked = DateTime(date.year, date.month, date.day, t.hour, t.minute);
    if (picked.isAfter(DateTime.now())) {
      picked = DateTime.now();
      _showMessage('Không chọn được thời điểm sau hiện tại');
    }
    setState(() => _spentAt = picked);
  }

  String _spentAtLabel() {
    final today = dateOnly(DateTime.now());
    final day = dateOnly(_spentAt);
    final String dayLabel;
    if (day == today) {
      dayLabel = 'Hôm nay';
    } else if (day == DateTime(today.year, today.month, today.day - 1)) {
      dayLabel = 'Hôm qua';
    } else {
      dayLabel = formatFullDay(_spentAt);
    }
    return '$dayLabel, ${formatTime(_spentAt)}';
  }

  // -------------------------------------------------------------------------
  // Luu (luong 4.1): luu khoan chi truoc, nen va tai tung anh sau
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    final categoryId = _categoryId;
    if (!_canSave || categoryId == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final repo = ref.read(expenseRepositoryProvider);
    final note = _noteController.text.trim();
    final ExpenseSaveResult result;
    try {
      result = await repo.addExpense(ExpenseDraft(
        categoryId: categoryId,
        amount: _amount,
        spentAt: _spentAt,
        note: note.isEmpty ? null : note,
      ));
    } catch (e) {
      // NFR-08: giu nguyen du lieu tren form de thu lai
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage('Không lưu được khoản chi. ${friendlyError(e)}');
      return;
    }

    var pending = List<_PendingPhoto>.of(_photos);
    var unreadable = 0;
    while (pending.isNotEmpty) {
      final failed = <_PendingPhoto>[];
      for (final photo in pending) {
        // Buoc 1: nen (BR-05). Anh khong doc duoc thi bo qua: thu lai cung vo ich.
        var compressed = photo.compressedPath;
        if (compressed == null) {
          try {
            compressed = (await compressPhoto(photo.path)).path;
            photo.compressedPath = compressed;
          } catch (_) {
            // PhotoUnreadableException (anh hong, dinh dang la) hoac file tam da bi xoa
            unreadable++;
            continue;
          }
        }
        // Buoc 2: tai len. Loi o day thuong do mang -> cho thu lai.
        try {
          await repo.uploadPhoto(
            result.expense.id,
            compressed,
            isReceipt: photo.isReceipt,
          );
        } catch (_) {
          failed.add(photo);
        }
      }
      if (failed.isEmpty || !mounted) break;
      // Khoan chi da luu; chi hoi thu lai nhung anh loi (NFR-08)
      final retry = await _askRetry(failed.length);
      if (!retry) break;
      pending = failed;
    }

    if (!mounted) return;
    refreshExpenseData(ref);
    if (unreadable > 0) await _showUnreadable(unreadable);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  /// Bao truoc khi dong form: snackbar o day se bi thong bao "Da luu" de len mat.
  Future<void> _showUnreadable(int count) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bỏ qua ảnh không đọc được'),
        content: Text(
          'Khoản chi đã được lưu, nhưng $count ảnh bị hỏng hoặc có định dạng '
          'không hỗ trợ nên không tải lên. Bạn có thể thêm ảnh khác sau.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<bool> _askRetry(int count) async {
    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Chưa tải được ảnh'),
        content: Text(
          'Khoản chi đã được lưu, nhưng $count ảnh chưa tải lên được. '
          'Kiểm tra mạng rồi thử lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Bỏ qua'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
    return retry ?? false;
  }

  // -------------------------------------------------------------------------
  // Giao dien
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leadingWidth: 80,
          leading: TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Huỷ'),
          ),
          title: const Text('Khoản chi mới'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  minimumSize: const Size(64, 36),
                ),
                onPressed: _canSave ? _save : null,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Lưu'),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.lg,
                ),
                children: [
                  _PhotoStrip(
                    photos: _photos,
                    enabled: !_saving,
                    onAdd: _addPhotos,
                    onRemove: (photo) => setState(() => _photos.remove(photo)),
                    onToggleReceipt: (photo) =>
                        setState(() => photo.isReceipt = !photo.isReceipt),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _AmountDisplay(amount: _amount),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Danh mục',
                    style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SectionCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.sm,
                    ),
                    child: AsyncView<List<ExpenseCategory>>(
                      value: categories,
                      onRetry: () => ref.invalidate(categoriesProvider),
                      builder: (list) => _CategoryGrid(
                        categories: list,
                        selectedId: _categoryId,
                        onSelect: (id) => setState(() => _categoryId = id),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Thoi gian + ghi chu gom mot nhom kieu Cai dat cua iPhone
                  SectionCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _TimeRow(label: _spentAtLabel(), onTap: _pickDateTime),
                        const Divider(height: 1, indent: 52, color: AppColors.hairline),
                        _noteField(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!_noteFocus.hasFocus) AmountKeypad(onKey: _saving ? (_) {} : _onKey),
          ],
        ),
      ),
    );
  }

  Widget _noteField() {
    return TextField(
      controller: _noteController,
      focusNode: _noteFocus,
      maxLength: 200,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      style: AppText.body,
      decoration: InputDecoration(
        hintText: 'Ghi chú (không bắt buộc)',
        hintStyle: AppText.body.copyWith(color: AppColors.inkMuted48),
        counterText: '',
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        prefixIcon: const Icon(Icons.edit_note, color: AppColors.inkMuted48),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dai anh: toi da 5, xoa tung anh, danh dau hoa don
// ---------------------------------------------------------------------------

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleReceipt,
  });

  final List<_PendingPhoto> photos;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<_PendingPhoto> onRemove;
  final ValueChanged<_PendingPhoto> onToggleReceipt;

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < maxPhotosPerExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ảnh (${photos.length}/$maxPhotosPerExpense)',
          style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 128,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final photo in photos)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: _PhotoItem(
                    photo: photo,
                    enabled: enabled,
                    onRemove: () => onRemove(photo),
                    onToggleReceipt: () => onToggleReceipt(photo),
                  ),
                ),
              if (canAdd)
                Align(
                  alignment: Alignment.topLeft,
                  child: Pressable(
                    semanticLabel: 'Thêm ảnh',
                    onTap: enabled ? onAdd : null,
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: DashedBox(
                        color: AppColors.primary,
                        radius: AppRadius.lg,
                        child: const Center(
                          child: Icon(Icons.add_a_photo_outlined, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoItem extends StatelessWidget {
  const _PhotoItem({
    required this.photo,
    required this.enabled,
    required this.onRemove,
    required this.onToggleReceipt,
  });

  final _PendingPhoto photo;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onToggleReceipt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  // cacheWidth: khong giai ma anh 12 MP o kich thuoc goc
                  child: Image.file(File(photo.path), fit: BoxFit.cover, cacheWidth: 300),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Pressable(
                    semanticLabel: 'Xoá ảnh',
                    onTap: enabled ? onRemove : null,
                    // Vung cham 44 dp (NFR-07) bao quanh nut tron 26 dp
                    child: SizedBox.square(
                      dimension: 44,
                      child: Align(
                        alignment: const Alignment(0.6, -0.6),
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: const BoxDecoration(
                            color: AppColors.chipTranslucent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: AppColors.ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Cong tac "la hoa don" cho tung anh
          Pressable(
            semanticLabel: 'Đánh dấu là hoá đơn',
            onTap: enabled ? onToggleReceipt : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 5),
              decoration: BoxDecoration(
                color: photo.isReceipt ? AppColors.primary : AppColors.canvas,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: photo.isReceipt ? AppColors.primary : AppColors.hairline,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 12,
                    color: photo.isReceipt ? Colors.white : AppColors.inkMuted48,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Hoá đơn',
                    style: AppText.finePrint.copyWith(
                      fontWeight: FontWeight.w600,
                      color: photo.isReceipt ? Colors.white : AppColors.inkMuted48,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// So tien lon
// ---------------------------------------------------------------------------

class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final color = amount == 0 ? AppColors.inkMuted48 : AppColors.ink;
    return Column(
      children: [
        Text(
          'Số tiền',
          style: AppText.captionStrong.copyWith(color: AppColors.inkMuted48),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: Text(
                  formatGrouped(amount),
                  key: ValueKey(amount),
                  maxLines: 1,
                  style: AppText.displayLg.copyWith(
                    fontSize: 48,
                    letterSpacing: -0.8,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text('₫', style: AppText.tagline.copyWith(color: AppColors.inkMuted48)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Luoi 8 danh muc
// ---------------------------------------------------------------------------

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ExpenseCategory> categories;
  final int? selectedId;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: 0.9,
      children: [
        for (final category in categories)
          Pressable(
            semanticLabel: category.name,
            onTap: () => onSelect(category.id),
            child: _CategoryItem(
              category: category,
              selected: category.id == selectedId,
            ),
          ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  const _CategoryItem({required this.category, required this.selected});

  final ExpenseCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: category.color.withAlpha(selected ? 60 : 30),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primaryFocus : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(category.icon, color: category.color, size: 24),
        ),
        const SizedBox(height: 6),
        Text(
          category.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.finePrint.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.ink : AppColors.inkMuted80,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dong chon thoi gian
// ---------------------------------------------------------------------------

class _TimeRow extends StatelessWidget {
  const _TimeRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: AppColors.inkMuted48),
            const SizedBox(width: AppSpacing.sm),
            const Text('Thời gian', style: AppText.body),
            const Spacer(),
            Text(label, style: AppText.body.copyWith(color: AppColors.primary)),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}