using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Services;

namespace Pocklet.Api.Tests;

public class BudgetRulesTests
{
    private static readonly DateTime Now = new(2026, 11, 17, 8, 0, 0, DateTimeKind.Utc);

    [Theory]
    [InlineData(1_599_999L, BudgetRules.Ok)]
    [InlineData(1_600_000L, BudgetRules.Warning)]
    [InlineData(2_000_000L, BudgetRules.Warning)]
    [InlineData(2_000_001L, BudgetRules.Exceeded)]
    public void Level_follows_80_and_100_percent(long spent, string expected)
    {
        Assert.Equal(expected, BudgetRules.Level(spent, 2_000_000));
    }

    [Fact]
    public void Each_threshold_is_reported_once_per_month()
    {
        var budget = new Budget { LimitAmount = 2_000_000 };

        Assert.Equal(BudgetRules.Warning, BudgetRules.Evaluate(budget, 1_600_000, Now));
        Assert.Null(BudgetRules.Evaluate(budget, 1_700_000, Now));
        Assert.Equal(BudgetRules.Exceeded, BudgetRules.Evaluate(budget, 2_000_001, Now));
        Assert.Null(BudgetRules.Evaluate(budget, 2_500_000, Now));
    }

    [Fact]
    public void Jumping_past_100_reports_exceeded_and_marks_both()
    {
        var budget = new Budget { LimitAmount = 800_000 };

        Assert.Equal(BudgetRules.Exceeded, BudgetRules.Evaluate(budget, 980_000, Now));
        Assert.NotNull(budget.Warned80At);
        Assert.NotNull(budget.Warned100At);
    }

    [Fact]
    public void Changing_the_limit_resets_both_flags()
    {
        var budget = new Budget { LimitAmount = 800_000, Warned80At = Now, Warned100At = Now };

        BudgetRules.ChangeLimit(budget, 1_200_000);

        Assert.Null(budget.Warned80At);
        Assert.Null(budget.Warned100At);
        Assert.Equal(BudgetRules.Warning, BudgetRules.Evaluate(budget, 980_000, Now));
    }

    [Fact]
    public void Percent_rounds_down()
    {
        Assert.Equal(92, BudgetRules.Percent(1_850_000, 2_000_000));
        Assert.Equal(0, BudgetRules.Percent(100, 0));
    }
}

public class CalendarRulesTests
{
    private static DateTime At(int hour) => new(2026, 11, 17, hour, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Cover_is_first_photo_of_latest_expense_with_photos()
    {
        var day = new[]
        {
            new CalendarExpense(1, At(1), 45_000, new[] { new CalendarPhoto(10, At(1)) }),
            new CalendarExpense(2, At(8), 39_000, new[] { new CalendarPhoto(21, At(9)), new CalendarPhoto(20, At(8)) }),
            new CalendarExpense(3, At(10), 64_000, Array.Empty<CalendarPhoto>()),
        };

        Assert.Equal(20, CalendarRules.CoverPhotoId(day));
    }

    [Fact]
    public void No_photo_means_no_cover()
    {
        var day = new[] { new CalendarExpense(1, At(1), 45_000, Array.Empty<CalendarPhoto>()) };
        Assert.Null(CalendarRules.CoverPhotoId(day));
    }
}

public class VnTimeTests
{
    [Fact]
    public void Late_evening_belongs_to_the_vietnamese_day()
    {
        // 23:30 ngày 17/11 giờ Việt Nam = 16:30 UTC cùng ngày (TC-13).
        var utc = new DateTime(2026, 11, 17, 16, 30, 0, DateTimeKind.Utc);
        Assert.Equal(new DateOnly(2026, 11, 17), VnTime.DateOf(utc));

        // 00:30 ngày 18/11 giờ Việt Nam = 17:30 UTC ngày 17/11.
        Assert.Equal(new DateOnly(2026, 11, 18), VnTime.DateOf(utc.AddHours(1)));
    }

    [Fact]
    public void Day_start_is_midnight_vietnam_time()
    {
        Assert.Equal(new DateTime(2026, 10, 31, 17, 0, 0, DateTimeKind.Utc), VnTime.StartOfDayUtc(new DateOnly(2026, 11, 1)));
    }

    [Theory]
    [InlineData("2026-11", true)]
    [InlineData("2026-13", false)]
    [InlineData("11-2026", false)]
    [InlineData("", false)]
    public void Month_parsing(string input, bool ok)
    {
        Assert.Equal(ok, VnTime.TryParseMonth(input, out _));
    }

    [Fact]
    public void Only_jpeg_and_png_are_accepted()
    {
        Assert.Equal("jpg", PhotoStorage.DetectExtension(new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 }));
        Assert.Equal("png", PhotoStorage.DetectExtension(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }));
        Assert.Null(PhotoStorage.DetectExtension("GIF89a"u8));
    }
}
