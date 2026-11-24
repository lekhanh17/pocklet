import '../core/date_utils.dart';

enum BudgetLevel { normal, warning, over }

/// Mot dong ngan sach: categoryId null la ngan sach tong cua thang.
class BudgetLine {
  const BudgetLine({this.categoryId, required this.limit, required this.spent});

  final int? categoryId;
  final int limit;
  final int spent;

  double get ratio => limit <= 0 ? 0 : spent / limit;

  int get percent => (ratio * 100).round();

  int get remaining => limit - spent;

  /// BR-04: tu 80% la "sap het", tren 100% la "vuot".
  BudgetLevel get level {
    if (ratio > 1) return BudgetLevel.over;
    if (ratio >= 0.8) return BudgetLevel.warning;
    return BudgetLevel.normal;
  }

  factory BudgetLine.fromJson(Map<String, dynamic> json) {
    return BudgetLine(
      categoryId: json['categoryId'] as int?,
      limit: (json['limitAmount'] as num).toInt(),
      spent: (json['spent'] as num).toInt(),
    );
  }
}

/// Canh bao ngan sach tra ve ngay sau khi luu khoan chi (FR-18, BR-04).
class BudgetAlert {
  const BudgetAlert({
    this.categoryId,
    required this.level,
    required this.percent,
  });

  /// Null la ngan sach tong cua thang.
  final int? categoryId;
  final BudgetLevel level;
  final int percent;

  factory BudgetAlert.fromJson(Map<String, dynamic> json) {
    return BudgetAlert(
      categoryId: json['categoryId'] as int?,
      level: json['level'] == 'over' ? BudgetLevel.over : BudgetLevel.warning,
      percent: (json['percent'] as num).toInt(),
    );
  }
}

/// Ngan sach cua mot thang kem so da chi (GET /api/budgets).
class BudgetOverview {
  const BudgetOverview({
    required this.month,
    this.total,
    this.categories = const [],
  });

  final DateTime month;

  /// Null neu thang nay chua dat ngan sach tong.
  final BudgetLine? total;
  final List<BudgetLine> categories;

  /// Cac danh muc dang o muc "sap het" hoac "vuot".
  List<BudgetLine> get alerts =>
      categories.where((c) => c.level != BudgetLevel.normal).toList();

  /// So ngay con lai sau hom nay trong thang.
  int daysLeftAfter(DateTime today) =>
      daysInMonth(month.year, month.month) - today.day;

  /// BR-04: so nen chi moi ngay = (ngan sach tong - da chi) / so ngay con lai.
  int? dailyAllowance(DateTime today) {
    final t = total;
    final left = daysLeftAfter(today);
    if (t == null || left <= 0) return null;
    if (t.remaining <= 0) return 0;
    return t.remaining ~/ left;
  }
}