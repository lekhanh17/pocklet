using System.ComponentModel.DataAnnotations;

namespace Pocklet.Api.Dtos;

// ---------- Tài khoản ----------

public class RegisterRequest
{
    [Required(ErrorMessage = "Nhập email")]
    [EmailAddress(ErrorMessage = "Email không hợp lệ")]
    [MaxLength(256)]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Nhập mật khẩu")]
    [MinLength(8, ErrorMessage = "Mật khẩu phải có ít nhất 8 ký tự")]
    [MaxLength(100)]
    public string Password { get; set; } = "";

    [Required(ErrorMessage = "Nhập tên hiển thị")]
    [MaxLength(100, ErrorMessage = "Tên hiển thị tối đa 100 ký tự")]
    public string DisplayName { get; set; } = "";
}

public class LoginRequest
{
    [Required(ErrorMessage = "Nhập email")]
    public string Email { get; set; } = "";

    [Required(ErrorMessage = "Nhập mật khẩu")]
    public string Password { get; set; } = "";
}

public class UpdateMeRequest
{
    [Required(ErrorMessage = "Nhập tên hiển thị")]
    [MaxLength(100, ErrorMessage = "Tên hiển thị tối đa 100 ký tự")]
    public string DisplayName { get; set; } = "";
}

public class ChangePasswordRequest
{
    [Required(ErrorMessage = "Nhập mật khẩu hiện tại")]
    public string CurrentPassword { get; set; } = "";

    [Required(ErrorMessage = "Nhập mật khẩu mới")]
    [MinLength(8, ErrorMessage = "Mật khẩu phải có ít nhất 8 ký tự")]
    [MaxLength(100)]
    public string NewPassword { get; set; } = "";
}

public record UserDto(int Id, string Email, string DisplayName, DateTimeOffset CreatedAt);

public record AuthResponse(string Token, DateTimeOffset ExpiresAt, UserDto User);

// ---------- Danh mục ----------

public class CategoryRequest
{
    [Required(ErrorMessage = "Nhập tên danh mục")]
    [MaxLength(50, ErrorMessage = "Tên danh mục tối đa 50 ký tự")]
    public string Name { get; set; } = "";

    [Required]
    [MaxLength(50)]
    public string Icon { get; set; } = "more_horiz";

    [Required]
    [RegularExpression("^#[0-9A-Fa-f]{6}$", ErrorMessage = "Màu phải có dạng #RRGGBB")]
    public string Color { get; set; } = "#8A827A";
}

public record CategoryDto(int Id, string Name, string Icon, string Color, bool IsDefault);

// ---------- Khoản chi và ảnh ----------

public class ExpenseRequest
{
    [Range(1, int.MaxValue, ErrorMessage = "Chọn danh mục")]
    public int CategoryId { get; set; }

    /// <summary>Số nguyên VND, từ 1 đến 1.000.000.000 (BR-01).</summary>
    [Range(typeof(long), "1", "1000000000", ErrorMessage = "Số tiền phải từ 1 đến 1.000.000.000 ₫")]
    public long Amount { get; set; }

    /// <summary>ISO 8601 có múi giờ, ví dụ 2026-11-17T07:40:00+07:00.</summary>
    [Required(ErrorMessage = "Chọn thời điểm chi")]
    public DateTimeOffset? SpentAt { get; set; }

    [MaxLength(200, ErrorMessage = "Ghi chú tối đa 200 ký tự")]
    public string? Note { get; set; }
}

public record PhotoDto(int Id, bool IsReceipt);

public record ExpenseDto(
    int Id,
    int CategoryId,
    long Amount,
    DateTimeOffset SpentAt,
    string? Note,
    IReadOnlyList<PhotoDto> Photos,
    DateTimeOffset CreatedAt);

public record BudgetAlertDto(int? CategoryId, string Level, int Percent);

/// <summary>Kết quả khi thêm hoặc sửa khoản chi: khoản chi và các cảnh báo ngân sách vừa bật (FR-18).</summary>
public record ExpenseSaveResponse(
    int Id,
    int CategoryId,
    long Amount,
    DateTimeOffset SpentAt,
    string? Note,
    IReadOnlyList<PhotoDto> Photos,
    DateTimeOffset CreatedAt,
    IReadOnlyList<BudgetAlertDto> BudgetAlerts);

public record ExpensePageDto(
    IReadOnlyList<ExpenseDto> Items,
    int Page,
    int PageSize,
    int TotalCount,
    long TotalAmount);

public class PhotoUploadForm
{
    [Required(ErrorMessage = "Chọn ảnh")]
    public IFormFile? File { get; set; }

    public bool IsReceipt { get; set; }
}

public class PhotoPatchRequest
{
    [Required]
    public bool? IsReceipt { get; set; }
}

public record PhotoCreatedDto(int Id, int ExpenseId, bool IsReceipt);

// ---------- Lịch ----------

public record CalendarDayDto(string Date, long Total, int Count, int? CoverPhotoId);

public record CalendarDto(string Month, long Total, IReadOnlyList<CalendarDayDto> Days);

// ---------- Ngân sách ----------

public record BudgetItemDto(
    int? CategoryId,
    string Name,
    long LimitAmount,
    long Spent,
    int Percent,
    // "ok", "warning" (từ 80%) hoặc "exceeded" (trên 100%)
    string Level);

public record BudgetSuggestionDto(int? CategoryId, long LimitAmount);

public record BudgetMonthDto(
    string Month,
    BudgetItemDto? Total,
    IReadOnlyList<BudgetItemDto> Categories,
    // Có giá trị khi tháng này chưa đặt mà tháng trước đã đặt (FR-16)
    IReadOnlyList<BudgetSuggestionDto>? SuggestedFromPreviousMonth);

public class BudgetPutItem
{
    public int? CategoryId { get; set; }

    [Range(typeof(long), "1", "1000000000", ErrorMessage = "Hạn mức phải từ 1 đến 1.000.000.000 ₫")]
    public long LimitAmount { get; set; }
}

public class BudgetPutRequest
{
    [Required(ErrorMessage = "Chọn tháng")]
    [RegularExpression(@"^\d{4}-\d{2}$", ErrorMessage = "Tháng phải có dạng yyyy-MM")]
    public string Month { get; set; } = "";

    [Required]
    public List<BudgetPutItem> Items { get; set; } = new();
}

// ---------- Thống kê ----------

public record CategoryStatDto(int CategoryId, string Name, string Icon, string Color, long Total, double Percent);

public record DayStatDto(string Date, long Total, long PreviousMonthTotal);

public record MonthlyStatsDto(
    string Month,
    long Total,
    long PreviousTotal,
    // Null khi tháng trước bằng 0
    double? ChangePercent,
    long? BudgetLimit,
    // Ngân sách tổng chia đều cho số ngày trong tháng; null khi chưa đặt ngân sách
    long? DailyBudget,
    IReadOnlyList<CategoryStatDto> ByCategory,
    IReadOnlyList<DayStatDto> ByDay);
