using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;
using Pocklet.Api.Services;

namespace Pocklet.Api.Controllers;

[Route("api/calendar")]
public class CalendarController(AppDbContext db) : ApiControllerBase
{
    /// <summary>
    /// Tổng tiền, số khoản và ảnh đại diện của từng ngày có chi trong tháng (FR-13). Ngày không chi không có trong danh sách.
    /// </summary>
    /// <param name="month">Tháng dạng yyyy-MM, ví dụ 2026-11.</param>
    /// <param name="ct"></param>
    [HttpGet]
    public async Task<ActionResult<CalendarDto>> Get([FromQuery] string? month, CancellationToken ct)
    {
        if (!VnTime.TryParseMonth(month, out var start)) return FieldError("month", "Tháng phải có dạng yyyy-MM");

        var userId = UserId;
        var fromUtc = VnTime.StartOfDayUtc(start);
        var toUtc = VnTime.StartOfDayUtc(start.AddMonths(1));

        var rows = await db.Expenses.AsNoTracking()
            .Where(e => e.UserId == userId && e.SpentAt >= fromUtc && e.SpentAt < toUtc)
            .Select(e => new
            {
                e.Id,
                e.SpentAt,
                e.Amount,
                Photos = e.Photos.Select(p => new { p.Id, p.CreatedAt }).ToList(),
            })
            .ToListAsync(ct);

        var days = rows
            .Select(r => new CalendarExpense(r.Id, r.SpentAt, r.Amount, r.Photos.Select(p => new CalendarPhoto(p.Id, p.CreatedAt)).ToList()))
            .GroupBy(e => VnTime.DateOf(e.SpentAtUtc))
            .OrderBy(g => g.Key)
            .Select(g => new CalendarDayDto(
                VnTime.DateKey(g.Key),
                ToLong(g.Sum(x => x.Amount)),
                g.Count(),
                CalendarRules.CoverPhotoId(g)))
            .ToList();

        return new CalendarDto(VnTime.MonthKey(start), days.Sum(d => d.Total), days);
    }
}
