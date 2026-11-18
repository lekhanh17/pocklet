/// Cac ham xu ly ngay thang. Ngay cua khoan chi tinh theo gio Viet Nam (BR-02);
/// app chay tren dien thoai o Viet Nam nen dung gio local.

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
