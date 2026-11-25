import '../core/date_utils.dart';

enum BudgetLevel {
  normal,
  warning,
  over;

  /// API tra "ok", "warning" (tu 80%) hoac "exceeded" (tren 100%) - xem api/README.md.
  /// Chuoi la thi coi la binh thuong de khong bao dong nham.
  static BudgetLevel fromApi(Object? value) => switch (value) {
        'exceeded' => BudgetLevel.over,
        'warning' => BudgetLevel.warning,
        _ => BudgetLevel.normal,
      };
}

/// Mot dong ngan sach: categoryId null la ngan sach tong cua thang.
class BudgetLine {
  const BudgetLine({this.categoryId, required this.limit, required this.spent});

  final int? categoryId;
  final int limit;
  final int spent;

  double get ratio => limit <= 0 ? 0 : spent / limit;

  /// Lam tron xuong giong API (BudgetRules.Percent): 79,6% hien 79% vi chua toi
  /// nguong "sap het". Lam tron len se hien "80%" ma nhan van binh thuong.
  int get percent => (ratio * 100).floor();

  int get remaining => limit - spent;

  /// BR-04: tu 80% la "sap het", tren 100% la "vuot".
  BudgetLevel get level {
    if (ratio > 1) return BudgetLevel.over;
    if (ratio >= 0.8) return BudgetLevel.warning;
    return BudgetLevel.normal;
  }

  /// Phan tu `total` / `categories` cua GET /api/budgets.
  /// percent, level, name server tra them thi bo qua: app tu tinh lai tu limit va spent.
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
    final level = BudgetLevel.fromApi(json['level']);
    return BudgetAlert(
      categoryId: json['categoryId'] as int?,
      // Server chi gui canh bao khi cham nguong, nen khong co muc "binh thuong" o day
      level: level == BudgetLevel.normal ? BudgetLevel.warning : level,
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

  /// Doc ket qua GET /api/budgets?month=yyyy-MM (BudgetMonthDto).
  factory BudgetOverview.fromJson(Map<String, dynamic> json) {
    final total = json['total'] as Map<String, dynamic>?;
    return BudgetOverview(
      month: DateTime.parse('${json['month']}-01'),
      total: total == null ? null : BudgetLine.fromJson(total),
      categories: ((json['categories'] as List<dynamic>?) ?? const [])
          .map((c) => BudgetLine.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

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
