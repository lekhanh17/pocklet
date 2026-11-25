using Pocklet.Api.Data;

namespace Pocklet.Api.Services;

/// <summary>Quy tắc ngân sách BR-04, tách riêng để kiểm thử.</summary>
public static class BudgetRules
{
    public const string Ok = "ok";
    public const string Warning = "warning";
    public const string Exceeded = "exceeded";

    /// <summary>Phần trăm đã dùng, làm tròn xuống: 1.850.000 / 2.000.000 = 92.</summary>
    public static int Percent(decimal spent, decimal limit) =>
        limit <= 0 ? 0 : (int)Math.Floor(spent * 100m / limit);

    /// <summary>Nhãn luôn hiện trên màn hình: từ 80% là "sắp hết", trên 100% là "vượt".</summary>
    public static string Level(decimal spent, decimal limit)
    {
        if (limit <= 0) return Ok;
        if (spent > limit) return Exceeded;
        if (spent * 100m >= limit * 80m) return Warning;
        return Ok;
    }

    /// <summary>
    /// Quyết định có bật thông báo không. Mỗi ngưỡng chỉ báo một lần mỗi tháng: lần đầu chạm ngưỡng thì ghi Warned80At / Warned100At,
    /// lần sau thấy cột đã có giá trị thì không báo nữa. Vượt thẳng qua 100% thì chỉ báo "vượt" nhưng ghi cả hai cột.
    /// Trả về mức vừa báo, hoặc null nếu không báo gì.
    /// </summary>
    public static string? Evaluate(Budget budget, decimal spent, DateTime nowUtc)
    {
        var level = Level(spent, budget.LimitAmount);
        if (level == Exceeded && budget.Warned100At == null)
        {
            budget.Warned100At = nowUtc;
            budget.Warned80At ??= nowUtc;
            return Exceeded;
        }
        if (level is Warning or Exceeded && budget.Warned80At == null)
        {
            budget.Warned80At = nowUtc;
            return Warning;
        }
        return null;
    }

    /// <summary>Đổi hạn mức thì đặt lại hai cột đã báo về null (BR-04).</summary>
    public static void ChangeLimit(Budget budget, decimal newLimit)
    {
        if (budget.LimitAmount == newLimit) return;
        budget.LimitAmount = newLimit;
        budget.Warned80At = null;
        budget.Warned100At = null;
    }
}
