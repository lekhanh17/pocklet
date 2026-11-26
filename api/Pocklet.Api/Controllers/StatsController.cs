using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;

namespace Pocklet.Api.Controllers;

[Route("api/stats")]
public class StatsController(AppDbContext db) : ApiControllerBase
{
    /// <summary>
    /// Số liệu cho màn Thống kê (FR-20, FR-21): tổng tháng, tháng trước, theo danh mục, theo từng ngày kèm cùng ngày tháng trước,
    /// và mức chi mỗi ngày theo ngân sách tổng.
    /// </summary>
    /// <param name="month">Tháng dạng yyyy-MM.</param>
    /// <param name="ct"></param>
    [HttpGet("monthly")]
    public async Task<ActionResult<MonthlyStatsDto>> Monthly([FromQuery] string? month, CancellationToken ct)
    {
        if (!VnTime.TryParseMonth(month, out var start)) return FieldError("month", "Tháng phải có dạng yyyy-MM");

        var userId = UserId;
        var previous = start.AddMonths(-1);
        var fromUtc = VnTime.StartOfDayUtc(previous);
        var toUtc = VnTime.StartOfDayUtc(start.AddMonths(1));

        var rows = await db.Expenses.AsNoTracking()
            .Where(e => e.UserId == userId && e.SpentAt >= fromUtc && e.SpentAt < toUtc)
            .Select(e => new { e.SpentAt, e.Amount, e.CategoryId })
            .ToListAsync(ct);

        var withDay = rows.Select(r => new { Day = VnTime.DateOf(r.SpentAt), r.Amount, r.CategoryId }).ToList();
        var current = withDay.Where(r => r.Day.Year == start.Year && r.Day.Month == start.Month).ToList();
        var prior = withDay.Where(r => r.Day.Year == previous.Year && r.Day.Month == previous.Month).ToList();

        var total = current.Sum(r => r.Amount);
        var previousTotal = prior.Sum(r => r.Amount);

        var categories = await db.Categories.AsNoTracking()
            .Where(c => c.UserId == null || c.UserId == userId)
            .ToDictionaryAsync(c => c.Id, ct);

        var byCategory = current
            .GroupBy(r => r.CategoryId)
            .Select(g =>
            {
                var sum = g.Sum(r => r.Amount);
                categories.TryGetValue(g.Key, out var c);
                return new CategoryStatDto(
                    g.Key,
                    c?.Name ?? "Khác",
                    c?.Icon ?? "more_horiz",
                    c?.Color ?? "#8A827A",
                    ToLong(sum),
                    total == 0 ? 0 : Math.Round((double)(sum * 100m / total), 1));
            })
            .OrderByDescending(x => x.Total)
            .ToList();

        var daysInMonth = DateTime.DaysInMonth(start.Year, start.Month);
        var daysInPrevious = DateTime.DaysInMonth(previous.Year, previous.Month);
        var currentByDay = current.GroupBy(r => r.Day.Day).ToDictionary(g => g.Key, g => g.Sum(r => r.Amount));
        var previousByDay = prior.GroupBy(r => r.Day.Day).ToDictionary(g => g.Key, g => g.Sum(r => r.Amount));
        var byDay = Enumerable.Range(1, daysInMonth)
            .Select(d => new DayStatDto(
                VnTime.DateKey(new DateOnly(start.Year, start.Month, d)),
                ToLong(currentByDay.GetValueOrDefault(d)),
                d <= daysInPrevious ? ToLong(previousByDay.GetValueOrDefault(d)) : 0))
            .ToList();

        var budget = await db.Budgets.AsNoTracking()
            .Where(b => b.UserId == userId && b.Month == start && b.CategoryId == null)
            .Select(b => (decimal?)b.LimitAmount)
            .FirstOrDefaultAsync(ct);

        double? change = previousTotal == 0 ? null : Math.Round((double)((total - previousTotal) * 100m / previousTotal), 1);

        return new MonthlyStatsDto(
            VnTime.MonthKey(start),
            ToLong(total),
            ToLong(previousTotal),
            change,
            budget == null ? null : ToLong(budget.Value),
            budget == null ? null : ToLong(budget.Value / daysInMonth),
            byCategory,
            byDay);
    }
}
