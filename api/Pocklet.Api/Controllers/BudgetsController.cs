using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;
using Pocklet.Api.Services;

namespace Pocklet.Api.Controllers;

[Route("api/budgets")]
public class BudgetsController(AppDbContext db) : ApiControllerBase
{
    private const string TotalName = "Ngân sách tổng";

    /// <summary>
    /// Ngân sách tháng kèm số đã chi, phần trăm và nhãn (FR-16, FR-17, FR-18).
    /// Tháng chưa đặt mà tháng trước đã đặt thì có thêm gợi ý chép từ tháng trước.
    /// </summary>
    /// <param name="month">Tháng dạng yyyy-MM.</param>
    /// <param name="ct"></param>
    [HttpGet]
    public async Task<ActionResult<BudgetMonthDto>> Get([FromQuery] string? month, CancellationToken ct)
    {
        if (!VnTime.TryParseMonth(month, out var start)) return FieldError("month", "Tháng phải có dạng yyyy-MM");
        return await BuildAsync(start, ct);
    }

    /// <summary>
    /// Đặt ngân sách tổng (categoryId = null) và theo danh mục cho một tháng. Danh sách gửi lên thay cho toàn bộ ngân sách của tháng:
    /// mục không có trong danh sách sẽ bị xoá. Đổi hạn mức thì đặt lại trạng thái đã báo (BR-04).
    /// </summary>
    [HttpPut]
    public async Task<ActionResult<BudgetMonthDto>> Put(BudgetPutRequest req, CancellationToken ct)
    {
        if (!VnTime.TryParseMonth(req.Month, out var start)) return FieldError("month", "Tháng phải có dạng yyyy-MM");

        var duplicated = req.Items.GroupBy(i => i.CategoryId).Any(g => g.Count() > 1);
        if (duplicated) return FieldError("items", "Mỗi danh mục chỉ có một hạn mức mỗi tháng");

        var userId = UserId;
        var categoryIds = req.Items.Where(i => i.CategoryId != null).Select(i => i.CategoryId!.Value).Distinct().ToList();
        var validCount = await db.Categories.CountAsync(c => categoryIds.Contains(c.Id) && (c.UserId == null || c.UserId == userId), ct);
        if (validCount != categoryIds.Count) return FieldError("items", "Có danh mục không tồn tại");

        var existing = await db.Budgets.Where(b => b.UserId == userId && b.Month == start).ToListAsync(ct);
        foreach (var item in req.Items)
        {
            var budget = existing.FirstOrDefault(b => b.CategoryId == item.CategoryId);
            if (budget == null)
            {
                db.Budgets.Add(new Budget { UserId = userId, CategoryId = item.CategoryId, Month = start, LimitAmount = item.LimitAmount });
            }
            else
            {
                BudgetRules.ChangeLimit(budget, item.LimitAmount);
            }
        }

        var keep = req.Items.Select(i => i.CategoryId).ToHashSet();
        db.Budgets.RemoveRange(existing.Where(b => !keep.Contains(b.CategoryId)));
        await db.SaveChangesAsync(ct);

        return await BuildAsync(start, ct);
    }

    private async Task<BudgetMonthDto> BuildAsync(DateOnly start, CancellationToken ct)
    {
        var userId = UserId;
        var budgets = await db.Budgets.AsNoTracking()
            .Include(b => b.Category)
            .Where(b => b.UserId == userId && b.Month == start)
            .ToListAsync(ct);

        var fromUtc = VnTime.StartOfDayUtc(start);
        var toUtc = VnTime.StartOfDayUtc(start.AddMonths(1));
        var spentByCategory = await db.Expenses.AsNoTracking()
            .Where(e => e.UserId == userId && e.SpentAt >= fromUtc && e.SpentAt < toUtc)
            .GroupBy(e => e.CategoryId)
            .Select(g => new { CategoryId = g.Key, Total = g.Sum(e => e.Amount) })
            .ToDictionaryAsync(x => x.CategoryId, x => x.Total, ct);
        var spentAll = spentByCategory.Values.Sum();

        BudgetItemDto? total = null;
        var categories = new List<BudgetItemDto>();
        foreach (var b in budgets)
        {
            var spent = b.CategoryId == null ? spentAll : spentByCategory.GetValueOrDefault(b.CategoryId.Value);
            var item = new BudgetItemDto(
                b.CategoryId,
                b.CategoryId == null ? TotalName : b.Category?.Name ?? "",
                ToLong(b.LimitAmount),
                ToLong(spent),
                BudgetRules.Percent(spent, b.LimitAmount),
                BudgetRules.Level(spent, b.LimitAmount));
            if (b.CategoryId == null) total = item;
            else categories.Add(item);
        }

        List<BudgetSuggestionDto>? suggestion = null;
        if (budgets.Count == 0)
        {
            var previous = start.AddMonths(-1);
            var prev = await db.Budgets.AsNoTracking()
                .Where(b => b.UserId == userId && b.Month == previous)
                .Select(b => new { b.CategoryId, b.LimitAmount })
                .ToListAsync(ct);
            if (prev.Count > 0)
                suggestion = prev.Select(p => new BudgetSuggestionDto(p.CategoryId, ToLong(p.LimitAmount))).ToList();
        }

        return new BudgetMonthDto(
            VnTime.MonthKey(start),
            total,
            categories.OrderByDescending(c => c.Percent).ThenBy(c => c.Name).ToList(),
            suggestion);
    }
}
