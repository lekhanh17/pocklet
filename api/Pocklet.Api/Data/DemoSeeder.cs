using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Services;

namespace Pocklet.Api.Data;

/// <summary>
/// Tạo tài khoản mẫu cho buổi demo: khoảng 40 khoản chi và 15 ảnh trong tháng hiện tại, thêm tháng trước để Thống kê có số so sánh.
/// Chạy bằng: dotnet run -- --seed-demo. Chạy lại không tạo trùng.
/// </summary>
public static class DemoSeeder
{
    public const string Email = "demo@pocklet.vn";
    public const string Password = "Demo@1234";

    // (ngày trong tháng, giờ, phút, danh mục, số tiền, ghi chú, file ảnh trong SeedData/photos hoặc null)
    private static readonly (int Day, int Hour, int Minute, int Category, long Amount, string Note, string? Photo)[] ThisMonth =
    {
        (1, 8, 5, DefaultCategories.AnUong, 35_000, "Bánh mì trứng", "banh-mi.jpg"),
        (1, 19, 30, DefaultCategories.AnUong, 85_000, "Cơm tối với bạn", null),
        (2, 7, 45, DefaultCategories.DiChuyen, 30_000, "Grab đi học", null),
        (2, 12, 10, DefaultCategories.AnUong, 45_000, "Cơm gà", "com-ga.jpg"),
        (2, 20, 0, DefaultCategories.GiaiTri, 135_000, "Xem phim", "ve-phim.jpg"),
        (3, 12, 0, DefaultCategories.AnUong, 40_000, "Bún bò", null),
        (3, 16, 30, DefaultCategories.AnUong, 55_000, "Cà phê nhóm", null),
        (4, 9, 0, DefaultCategories.HoaDon, 540_000, "Tiền điện tháng 10", "hoa-don-dien.jpg"),
        (5, 12, 15, DefaultCategories.AnUong, 50_000, "Cơm tấm", null),
        (5, 18, 0, DefaultCategories.SucKhoe, 110_000, "Thuốc cảm", null),
        (6, 7, 30, DefaultCategories.AnUong, 30_000, "Xôi", null),
        (6, 17, 45, DefaultCategories.DiChuyen, 45_000, "Đổ xăng", null),
        (7, 10, 0, DefaultCategories.MuaSam, 320_000, "Áo thun", "ao-thun.jpg"),
        (7, 13, 0, DefaultCategories.AnUong, 60_000, "Lẩu trưa", null),
        (8, 12, 30, DefaultCategories.AnUong, 65_000, "Mì cay", null),
        (8, 19, 0, DefaultCategories.HocTap, 195_000, "Sách Flutter", null),
        (9, 8, 0, DefaultCategories.AnUong, 40_000, "Phở", "pho.jpg"),
        (9, 15, 0, DefaultCategories.AnUong, 100_000, "Trà sữa cả nhóm", null),
        (10, 12, 0, DefaultCategories.AnUong, 48_000, "Cơm văn phòng", null),
        (10, 18, 20, DefaultCategories.DiChuyen, 40_000, "Gửi xe tháng", null),
        (12, 11, 0, DefaultCategories.MuaSam, 480_000, "Giày thể thao", "giay.jpg"),
        (12, 19, 30, DefaultCategories.AnUong, 170_000, "Nướng cuối tuần", null),
        (13, 12, 0, DefaultCategories.AnUong, 45_000, "Bún chả", null),
        (13, 17, 0, DefaultCategories.SucKhoe, 145_000, "Khám răng", null),
        (14, 10, 30, DefaultCategories.GiaiTri, 250_000, "Đi chơi Thảo Cầm Viên", "thao-cam-vien.jpg"),
        (14, 13, 0, DefaultCategories.AnUong, 120_000, "Ăn trưa ngoài", null),
        (14, 18, 0, DefaultCategories.MuaSam, 180_000, "Quà sinh nhật", "qua.jpg"),
        (14, 21, 0, DefaultCategories.DiChuyen, 70_000, "Grab về nhà", null),
        (15, 9, 0, DefaultCategories.AnUong, 45_000, "Bánh cuốn", "banh-cuon.jpg"),
        (15, 14, 0, DefaultCategories.HocTap, 95_000, "In tài liệu", null),
        (15, 20, 0, DefaultCategories.AnUong, 170_000, "Lẩu Thái", null),
        (16, 8, 0, DefaultCategories.AnUong, 25_000, "Cà phê sữa", null),
        (16, 12, 0, DefaultCategories.AnUong, 45_000, "Cơm trưa", null),
        (16, 18, 30, DefaultCategories.HoaDon, 100_000, "Nạp tiền điện thoại", null),
        (16, 19, 0, DefaultCategories.DiChuyen, 70_000, "Đổ xăng", null),
        (16, 21, 0, DefaultCategories.HocTap, 62_000, "Photo tài liệu", null),
        (17, 7, 40, DefaultCategories.AnUong, 45_000, "Phở bò", "pho-bo.jpg"),
        (17, 8, 10, DefaultCategories.DiChuyen, 32_000, "Grab đi học", null),
        (17, 15, 20, DefaultCategories.AnUong, 39_000, "Trà sữa", "tra-sua.jpg"),
        (17, 17, 5, DefaultCategories.HocTap, 64_000, "Sổ tay + bút", "hoa-don-so-tay.jpg"),
        (18, 12, 0, DefaultCategories.AnUong, 50_000, "Cơm gà xối mỡ", "com-ga-xoi-mo.jpg"),
        (19, 19, 0, DefaultCategories.GiaiTri, 90_000, "Karaoke", null),
        (20, 12, 0, DefaultCategories.AnUong, 55_000, "Hủ tiếu", "hu-tieu.jpg"),
    };

    // Tháng trước: ít khoản hơn, không có ảnh, chỉ để so sánh.
    private static readonly (int Day, int Category, long Amount, string Note)[] LastMonth =
    {
        (2, DefaultCategories.AnUong, 420_000, "Ăn uống tuần 1"),
        (3, DefaultCategories.HoaDon, 510_000, "Tiền điện"),
        (6, DefaultCategories.MuaSam, 650_000, "Quần jean"),
        (9, DefaultCategories.AnUong, 460_000, "Ăn uống tuần 2"),
        (12, DefaultCategories.DiChuyen, 280_000, "Xăng và gửi xe"),
        (16, DefaultCategories.AnUong, 480_000, "Ăn uống tuần 3"),
        (18, DefaultCategories.GiaiTri, 300_000, "Đi chơi"),
        (20, DefaultCategories.HocTap, 220_000, "Khoá học online"),
        (23, DefaultCategories.AnUong, 510_000, "Ăn uống tuần 4"),
        (27, DefaultCategories.SucKhoe, 200_000, "Khám sức khoẻ"),
        (28, DefaultCategories.MuaSam, 270_000, "Đồ dùng nhà"),
    };

    public static async Task SeedAsync(IServiceProvider services, ILogger logger, CancellationToken ct = default)
    {
        var db = services.GetRequiredService<AppDbContext>();
        var hasher = services.GetRequiredService<IPasswordHasher<User>>();
        var storage = services.GetRequiredService<PhotoStorage>();
        var env = services.GetRequiredService<IWebHostEnvironment>();
        var clock = services.GetRequiredService<TimeProvider>();

        if (await db.Users.AnyAsync(u => u.Email == Email, ct))
        {
            logger.LogInformation("Tài khoản mẫu {Email} đã có, bỏ qua.", Email);
            return;
        }

        var nowUtc = clock.GetUtcNow().UtcDateTime;
        var user = new User { Email = Email, DisplayName = "Bạn Demo", CreatedAt = nowUtc };
        user.PasswordHash = hasher.HashPassword(user, Password);
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);

        var now = VnTime.Now(clock);
        var month = VnTime.MonthStart(VnTime.Today(clock));
        var daysInMonth = DateTime.DaysInMonth(month.Year, month.Month);
        var photoDir = Path.Combine(env.ContentRootPath, "SeedData", "photos");
        var photoCount = 0;

        foreach (var row in ThisMonth)
        {
            if (row.Day > daysInMonth) continue;
            var local = new DateTimeOffset(month.Year, month.Month, row.Day, row.Hour, row.Minute, 0, VnTime.Offset);
            if (local > now) continue; // Không tạo khoản chi trong tương lai (BR-02).

            var expense = new Expense
            {
                UserId = user.Id,
                CategoryId = row.Category,
                Amount = row.Amount,
                SpentAt = local.UtcDateTime,
                Note = row.Note,
                CreatedAt = local.UtcDateTime,
                UpdatedAt = local.UtcDateTime,
            };

            var source = row.Photo == null ? null : Path.Combine(photoDir, row.Photo);
            if (source != null && File.Exists(source))
            {
                var bytes = await File.ReadAllBytesAsync(source, ct);
                var path = await storage.SaveAsync(user.Id, bytes, "jpg", ct);
                expense.Photos.Add(new ExpensePhoto
                {
                    FilePath = path,
                    IsReceipt = row.Photo!.StartsWith("hoa-don", StringComparison.Ordinal),
                    SizeBytes = bytes.Length,
                    CreatedAt = local.UtcDateTime,
                });
                photoCount++;
            }

            db.Expenses.Add(expense);
        }

        var previous = month.AddMonths(-1);
        var daysInPrevious = DateTime.DaysInMonth(previous.Year, previous.Month);
        foreach (var row in LastMonth)
        {
            if (row.Day > daysInPrevious) continue;
            var local = new DateTimeOffset(previous.Year, previous.Month, row.Day, 12, 0, 0, VnTime.Offset);
            db.Expenses.Add(new Expense
            {
                UserId = user.Id,
                CategoryId = row.Category,
                Amount = row.Amount,
                SpentAt = local.UtcDateTime,
                Note = row.Note,
                CreatedAt = local.UtcDateTime,
                UpdatedAt = local.UtcDateTime,
            });
        }

        db.Budgets.AddRange(
            new Budget { UserId = user.Id, Month = month, CategoryId = null, LimitAmount = 6_000_000 },
            new Budget { UserId = user.Id, Month = month, CategoryId = DefaultCategories.AnUong, LimitAmount = 2_000_000 },
            new Budget { UserId = user.Id, Month = month, CategoryId = DefaultCategories.MuaSam, LimitAmount = 800_000 },
            new Budget { UserId = user.Id, Month = month, CategoryId = DefaultCategories.DiChuyen, LimitAmount = 1_000_000 },
            new Budget { UserId = user.Id, Month = previous, CategoryId = null, LimitAmount = 5_000_000 });

        await db.SaveChangesAsync(ct);
        logger.LogInformation("Đã tạo tài khoản mẫu {Email} / {Password} với {Photos} ảnh.", Email, Password, photoCount);
    }
}
