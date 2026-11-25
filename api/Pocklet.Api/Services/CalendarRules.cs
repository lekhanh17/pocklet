namespace Pocklet.Api.Services;

/// <summary>Dữ liệu tối thiểu của một khoản chi để tính lịch, tách khỏi EF để kiểm thử.</summary>
public record CalendarExpense(int Id, DateTime SpentAtUtc, decimal Amount, IReadOnlyList<CalendarPhoto> Photos);

public record CalendarPhoto(int Id, DateTime CreatedAtUtc);

public static class CalendarRules
{
    /// <summary>
    /// BR-06: ảnh đại diện của ngày là ảnh tải lên sớm nhất của khoản chi có ảnh và có SpentAt muộn nhất trong ngày.
    /// Trả null nếu trong ngày không có ảnh nào.
    /// </summary>
    public static int? CoverPhotoId(IEnumerable<CalendarExpense> expensesOfDay)
    {
        var latestWithPhoto = expensesOfDay
            .Where(e => e.Photos.Count > 0)
            .OrderByDescending(e => e.SpentAtUtc)
            .ThenByDescending(e => e.Id)
            .FirstOrDefault();

        return latestWithPhoto?.Photos
            .OrderBy(p => p.CreatedAtUtc)
            .ThenBy(p => p.Id)
            .First().Id;
    }
}
