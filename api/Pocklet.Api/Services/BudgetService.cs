using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;

namespace Pocklet.Api.Services;

public class BudgetService(AppDbContext db, TimeProvider clock)
{
    /// <summary>Tổng đã chi của người dùng trong tháng (giờ Việt Nam); categoryId null = mọi danh mục.</summary>
    public async Task<decimal> SpentAsync(int userId, DateOnly month, int? categoryId, CancellationToken ct)
    {
        var from = VnTime.StartOfDayUtc(month);
        var to = VnTime.StartOfDayUtc(month.AddMonths(1));
        var q = db.Expenses.Where(e => e.UserId == userId && e.SpentAt >= from && e.SpentAt < to);
        if (categoryId != null) q = q.Where(e => e.CategoryId == categoryId);
        return await q.SumAsync(e => (decimal?)e.Amount, ct) ?? 0m;
    }

    /// <summary>
    /// Gọi sau khi thêm hoặc sửa một khoản chi (đã SaveChanges). Kiểm tra ngân sách tổng và ngân sách của danh mục
    /// trong tháng của khoản chi, ghi lại ngưỡng vừa báo và trả về các cảnh báo mới (FR-18, BR-04).
    /// </summary>
    public async Task<List<BudgetAlertDto>> EvaluateAfterSaveAsync(int userId, DateTime spentAtUtc, int categoryId, CancellationToken ct)
    {
        var month = VnTime.MonthStart(VnTime.DateOf(spentAtUtc));
        var budgets = await db.Budgets
            .Where(b => b.UserId == userId && b.Month == month && (b.CategoryId == null || b.CategoryId == categoryId))
            .ToListAsync(ct);

        var alerts = new List<BudgetAlertDto>();
        var now = clock.GetUtcNow().UtcDateTime;
        foreach (var budget in budgets.OrderBy(b => b.CategoryId.HasValue))
        {
            var spent = await SpentAsync(userId, month, budget.CategoryId, ct);
            var level = BudgetRules.Evaluate(budget, spent, now);
            if (level != null)
                alerts.Add(new BudgetAlertDto(budget.CategoryId, level, BudgetRules.Percent(spent, budget.LimitAmount)));
        }

        if (alerts.Count > 0) await db.SaveChangesAsync(ct);
        return alerts;
    }
}
