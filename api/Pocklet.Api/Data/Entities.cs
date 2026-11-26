namespace Pocklet.Api.Data;

public class User
{
    public int Id { get; set; }
    public string Email { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public string DisplayName { get; set; } = "";
    public DateTime CreatedAt { get; set; }
}

public class Category
{
    public int Id { get; set; }

    /// <summary>Null = danh mục mặc định dùng chung cho mọi người dùng.</summary>
    public int? UserId { get; set; }
    public User? User { get; set; }

    public string Name { get; set; } = "";
    public string Icon { get; set; } = "more_horiz";
    public string Color { get; set; } = "#8A827A";

    public bool IsDefault => UserId == null;
}

public class Expense
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }
    public int CategoryId { get; set; }
    public Category? Category { get; set; }

    /// <summary>Số nguyên VND (BR-01).</summary>
    public decimal Amount { get; set; }

    /// <summary>Thời điểm chi theo UTC (BR-02).</summary>
    public DateTime SpentAt { get; set; }

    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public List<ExpensePhoto> Photos { get; set; } = new();
}

public class ExpensePhoto
{
    public int Id { get; set; }
    public int ExpenseId { get; set; }
    public Expense? Expense { get; set; }

    /// <summary>Đường dẫn tương đối: uploads/{userId}/{yyyy-MM}/{guid}.jpg</summary>
    public string FilePath { get; set; } = "";
    public bool IsReceipt { get; set; }
    public int SizeBytes { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class Budget
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public User? User { get; set; }

    /// <summary>Null = ngân sách tổng của tháng.</summary>
    public int? CategoryId { get; set; }
    public Category? Category { get; set; }

    /// <summary>Luôn là ngày 1 của tháng.</summary>
    public DateOnly Month { get; set; }
    public decimal LimitAmount { get; set; }

    /// <summary>Thời điểm đã báo "sắp hết"; null = chưa báo (BR-04).</summary>
    public DateTime? Warned80At { get; set; }

    /// <summary>Thời điểm đã báo "vượt"; null = chưa báo (BR-04).</summary>
    public DateTime? Warned100At { get; set; }
}
