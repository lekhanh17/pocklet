// Dinh dang hien thi theo BR-01 (tien) va tieng Viet (ngay gio).

const _weekdayNames = [
  'Thứ Hai',
  'Thứ Ba',
  'Thứ Tư',
  'Thứ Năm',
  'Thứ Sáu',
  'Thứ Bảy',
  'Chủ Nhật',
];

/// Nhan cot cua luoi lich, tuan bat dau thu Hai (FR-13).
const weekdayShortNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// 45000 -> "45.000 ₫"
String formatVnd(num amount) {
  final digits = amount.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buf ₫';
}

/// Viet gon tren o lich: duoi 1 trieu la "180k", tu 1 trieu la "1,2tr".
String formatShort(num amount) {
  if (amount <= 0) return '0';
  final k = (amount / 1000).round();
  if (k < 1000) return '${k}k';
  var tr = (amount / 1000000).toStringAsFixed(1).replaceAll('.', ',');
  if (tr.endsWith(',0')) tr = tr.substring(0, tr.length - 2);
  return '${tr}tr';
}

String _two(int n) => n.toString().padLeft(2, '0');

String weekdayName(DateTime d) => _weekdayNames[d.weekday - 1];

String weekdayShort(DateTime d) => weekdayShortNames[d.weekday - 1];

/// "17/11"
String formatDayMonth(DateTime d) => '${_two(d.day)}/${_two(d.month)}';

/// "Thứ Ba, 17/11"
String formatFullDay(DateTime d) => '${weekdayName(d)}, ${formatDayMonth(d)}';

/// "07:40"
String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "Tháng 11, 2026"
String formatMonth(DateTime m) => 'Tháng ${m.month}, ${m.year}';

/// Chu cai dau cua ten hien thi, dung cho nut Tai khoan.
String initialOf(String name) {
  final t = name.trim();
  return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
}
