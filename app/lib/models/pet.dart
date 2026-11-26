import '../core/date_utils.dart';
import 'budget.dart';

/// Ban dong hanh nguoi dung chon luc mo app lan dau.
enum PetKind {
  pig('Heo đất'),
  cat('Mèo'),
  dog('Cún');

  const PetKind(this.label);

  final String label;
}

/// Trang thai cua pet theo nhip chi trong thang.
enum PetMood {
  /// Chua dat muc tieu thang.
  unknown('Chờ mục tiêu', 'Đặt mục tiêu chi tháng này để nuôi mình nhé!', 0.9, 0.88),

  /// Nhip chi <= 80%.
  chubby('Béo tròn', 'No căng luôn! Tháng này bạn tiêu khéo quá.', 1.0, 1.0),

  /// 80% < nhip <= 100%.
  healthy('Khoẻ mạnh', 'Đang đúng nhịp, giữ vậy nhé!', 0.9, 0.88),

  /// 100% < nhip <= 120%.
  thin('Hơi gầy', 'Hôm nay mình hơi đói rồi đó…', 0.8, 0.76),

  /// 120% < nhip <= 150%.
  tired('Gầy, mệt', 'Mình mệt quá… bớt chi một chút nha.', 0.7, 0.64),

  /// Nhip > 150% hoac da vuot muc tieu ca thang.
  starving('Đói lả', 'Mình đói lả rồi, cứu mình với!', 0.6, 0.54);

  const PetMood(this.label, this.speech, this.scale, this.bodyWidth);

  final String label;

  /// Cau pet noi trong bong bong.
  final String speech;

  /// Kich thuoc tong the (1 = to nhat).
  final double scale;

  /// Do beo cua than (1 = tron nhat).
  final double bodyWidth;
}

/// Ket qua tinh trang thai pet.
class PetStatus {
  const PetStatus({required this.mood, this.pace});

  final PetMood mood;

  /// Nhip chi: da chi / so nen chi den hom nay. Null neu chua co muc tieu.
  final double? pace;

  int? get pacePercent => pace == null ? null : (pace! * 100).round();
}

/// Nhip chi = da chi / (muc tieu x so ngay da qua / so ngay trong thang).
/// Do theo nhip (khong theo so tien da chi) de cuoi thang pet van khoe
/// neu nguoi dung chi dung ke hoach.
PetStatus petStatusFor(BudgetOverview overview, DateTime today) {
  final total = overview.total;
  if (total == null || total.limit <= 0) {
    return const PetStatus(mood: PetMood.unknown);
  }

  final days = daysInMonth(overview.month.year, overview.month.month);
  final isCurrentMonth = monthOf(today) == overview.month;
  // Thang da qua: tinh ca thang. Thang hien tai: tinh ca hom nay.
  final elapsed = isCurrentMonth ? today.day : days;
  final expected = total.limit * elapsed / days;
  final pace = expected <= 0 ? 0.0 : total.spent / expected;

  final PetMood mood;
  if (total.spent > total.limit || pace > 1.5) {
    mood = PetMood.starving;
  } else if (pace > 1.2) {
    mood = PetMood.tired;
  } else if (pace > 1.0) {
    mood = PetMood.thin;
  } else if (pace > 0.8) {
    mood = PetMood.healthy;
  } else {
    mood = PetMood.chubby;
  }
  return PetStatus(mood: mood, pace: pace);
}