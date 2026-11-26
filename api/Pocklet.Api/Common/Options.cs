namespace Pocklet.Api.Common;

public class JwtOptions
{
    public string Issuer { get; set; } = "pocklet-api";
    public string Audience { get; set; } = "pocklet-app";

    /// <summary>Khoá ký HS256, tối thiểu 32 byte. Đặt bằng user-secrets hoặc biến môi trường Jwt__Key (NFR-03).</summary>
    public string Key { get; set; } = "";

    /// <summary>BR-09: token hết hạn sau 7 ngày.</summary>
    public int ExpiryDays { get; set; } = 7;
}

public class StorageOptions
{
    /// <summary>Thư mục gốc chứa ảnh, tính từ thư mục chạy API nếu là đường dẫn tương đối.</summary>
    public string UploadsPath { get; set; } = "uploads";

    /// <summary>BR-05: tối đa 2 MB mỗi ảnh.</summary>
    public int MaxPhotoBytes { get; set; } = 2 * 1024 * 1024;

    /// <summary>BR-05: tối đa 5 ảnh mỗi khoản chi.</summary>
    public int MaxPhotosPerExpense { get; set; } = 5;
}
