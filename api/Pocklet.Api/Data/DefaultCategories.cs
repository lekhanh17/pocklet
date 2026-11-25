namespace Pocklet.Api.Data;

/// <summary>8 danh mục mặc định (FR-05), thêm bằng migration đầu tiên.</summary>
public static class DefaultCategories
{
    public const int AnUong = 1;
    public const int DiChuyen = 2;
    public const int MuaSam = 3;
    public const int HoaDon = 4;
    public const int GiaiTri = 5;
    public const int SucKhoe = 6;
    public const int HocTap = 7;

    /// <summary>Khoản chi của danh mục riêng bị xoá sẽ chuyển về đây (BR-03).</summary>
    public const int Khac = 8;

    public static readonly Category[] All =
    {
        new() { Id = AnUong, Name = "Ăn uống", Icon = "restaurant", Color = "#E07A5F" },
        new() { Id = DiChuyen, Name = "Di chuyển", Icon = "directions_car", Color = "#3D85C6" },
        new() { Id = MuaSam, Name = "Mua sắm", Icon = "shopping_bag", Color = "#C2185B" },
        new() { Id = HoaDon, Name = "Hoá đơn", Icon = "receipt_long", Color = "#6D4C41" },
        new() { Id = GiaiTri, Name = "Giải trí", Icon = "sports_esports", Color = "#7E57C2" },
        new() { Id = SucKhoe, Name = "Sức khoẻ", Icon = "medical_services", Color = "#D32F2F" },
        new() { Id = HocTap, Name = "Học tập", Icon = "school", Color = "#F9A825" },
        new() { Id = Khac, Name = "Khác", Icon = "more_horiz", Color = "#78716C" },
    };
}
