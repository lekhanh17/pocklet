import 'expense.dart';

/// Tong hop mot ngay tren lich (GET /api/calendar).
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.total,
    required this.count,
    this.coverPhotoId,
  });

  final DateTime date;
  final int total;
  final int count;

  /// Anh dai dien cua ngay (BR-06), null neu ngay khong co anh.
  final int? coverPhotoId;

  factory CalendarDay.fromJson(Map<String, dynamic> json) {
    return CalendarDay(
      date: DateTime.parse(json['date'] as String),
      total: (json['total'] as num).toInt(),
      count: json['count'] as int,
      coverPhotoId: json['coverPhotoId'] as int?,
    );
  }
}

/// Du lieu lich cua mot thang. Chi chua nhung ngay co khoan chi.
class CalendarMonth {
  CalendarMonth({
    required this.month,
    required this.total,
    required this.days,
  });

  final DateTime month;
  final int total;
  final List<CalendarDay> days;

  /// Tra cuu theo so ngay trong thang (1..31). Tinh mot lan, khong dung lai moi lan goi.
  late final Map<int, CalendarDay> byDay = {for (final d in days) d.date.day: d};

  late final int daysWithPhoto = days.where((d) => d.coverPhotoId != null).length;

  factory CalendarMonth.fromJson(Map<String, dynamic> json) {
    return CalendarMonth(
      month: DateTime.parse('${json['month']}-01'),
      total: (json['total'] as num).toInt(),
      days: (json['days'] as List<dynamic>)
          .map((d) => CalendarDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Tong hop cac khoan chi cua mot ngay.
/// Anh dai dien (BR-06): anh tai len som nhat cua khoan chi co anh
/// va co SpentAt muon nhat trong ngay.
CalendarDay summarizeDay(DateTime day, Iterable<Expense> items) {
  var total = 0;
  var count = 0;
  Expense? latestWithPhoto;
  for (final e in items) {
    total += e.amount;
    count++;
    if (e.hasPhotos &&
        (latestWithPhoto == null || e.spentAt.isAfter(latestWithPhoto.spentAt))) {
      latestWithPhoto = e;
    }
  }
  return CalendarDay(
    date: day,
    total: total,
    count: count,
    coverPhotoId: latestWithPhoto?.photos.first.id,
  );
}
