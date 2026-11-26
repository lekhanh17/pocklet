using System.Globalization;

namespace Pocklet.Api.Common;

/// <summary>
/// Giờ Việt Nam (UTC+7, không có giờ mùa hè). Server lưu UTC; ngày và tháng của khoản chi tính theo giờ Việt Nam (BR-02).
/// </summary>
public static class VnTime
{
    public static readonly TimeSpan Offset = TimeSpan.FromHours(7);

    /// <summary>Đổi một giá trị đọc từ cơ sở dữ liệu (luôn là UTC) sang giờ Việt Nam.</summary>
    public static DateTimeOffset FromUtc(DateTime utc) =>
        new DateTimeOffset(DateTime.SpecifyKind(utc, DateTimeKind.Utc)).ToOffset(Offset);

    public static DateTimeOffset Now(TimeProvider? clock = null) =>
        (clock ?? TimeProvider.System).GetUtcNow().ToOffset(Offset);

    public static DateOnly Today(TimeProvider? clock = null) => DateOnly.FromDateTime(Now(clock).DateTime);

    /// <summary>Ngày (giờ Việt Nam) của một thời điểm UTC.</summary>
    public static DateOnly DateOf(DateTime utc) => DateOnly.FromDateTime(FromUtc(utc).DateTime);

    /// <summary>00:00 giờ Việt Nam của ngày đó, đổi ra UTC.</summary>
    public static DateTime StartOfDayUtc(DateOnly day) =>
        new DateTimeOffset(day.ToDateTime(TimeOnly.MinValue), Offset).UtcDateTime;

    /// <summary>Ngày 1 của tháng chứa ngày đó.</summary>
    public static DateOnly MonthStart(DateOnly day) => new(day.Year, day.Month, 1);

    /// <summary>Đọc "yyyy-MM" thành ngày 1 của tháng.</summary>
    public static bool TryParseMonth(string? value, out DateOnly month)
    {
        month = default;
        if (string.IsNullOrWhiteSpace(value)) return false;
        return DateOnly.TryParseExact(value.Trim() + "-01", "yyyy-MM-dd", CultureInfo.InvariantCulture, DateTimeStyles.None, out month);
    }

    public static string MonthKey(DateOnly month) => month.ToString("yyyy-MM", CultureInfo.InvariantCulture);

    public static string DateKey(DateOnly day) => day.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}
