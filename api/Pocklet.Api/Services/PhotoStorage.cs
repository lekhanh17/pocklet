using System.Globalization;
using Microsoft.Extensions.Options;
using Pocklet.Api.Common;

namespace Pocklet.Api.Services;

/// <summary>Lưu file ảnh trong thư mục uploads/ cạnh API; cơ sở dữ liệu chỉ giữ đường dẫn tương đối.</summary>
public class PhotoStorage
{
    private readonly string _root;
    private readonly string _rootFull;

    public PhotoStorage(IOptions<StorageOptions> options, IWebHostEnvironment env)
    {
        var configured = options.Value.UploadsPath;
        _root = Path.IsPathRooted(configured) ? configured : Path.Combine(env.ContentRootPath, configured);
        _rootFull = Path.GetFullPath(_root);
        Directory.CreateDirectory(_rootFull);
    }

    /// <summary>Đuôi file theo nội dung thật: chỉ nhận JPEG hoặc PNG (BR-05). Trả null nếu không phải.</summary>
    public static string? DetectExtension(ReadOnlySpan<byte> head)
    {
        if (head.Length >= 3 && head[0] == 0xFF && head[1] == 0xD8 && head[2] == 0xFF) return "jpg";
        if (head.Length >= 8 && head[0] == 0x89 && head[1] == 0x50 && head[2] == 0x4E && head[3] == 0x47
            && head[4] == 0x0D && head[5] == 0x0A && head[6] == 0x1A && head[7] == 0x0A) return "png";
        return null;
    }

    public static string ContentTypeFor(string relativePath) =>
        relativePath.EndsWith(".png", StringComparison.OrdinalIgnoreCase) ? "image/png" : "image/jpeg";

    /// <summary>Ghi file và trả về đường dẫn tương đối dạng uploads/{userId}/{yyyy-MM}/{guid}.{ext}. Tên file là GUID, không dùng tên gốc.</summary>
    public async Task<string> SaveAsync(int userId, byte[] bytes, string extension, CancellationToken ct)
    {
        var month = VnTime.Now().ToString("yyyy-MM", CultureInfo.InvariantCulture);
        var relative = $"uploads/{userId}/{month}/{Guid.NewGuid():N}.{extension}";
        var full = FullPath(relative);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await File.WriteAllBytesAsync(full, bytes, ct);
        return relative;
    }

    /// <summary>Đường dẫn tuyệt đối của một file ảnh; chặn mọi đường dẫn thoát ra ngoài thư mục gốc.</summary>
    public string FullPath(string relative)
    {
        const string prefix = "uploads/";
        var inner = relative.StartsWith(prefix, StringComparison.Ordinal) ? relative[prefix.Length..] : relative;
        var full = Path.GetFullPath(Path.Combine(_rootFull, inner.Replace('/', Path.DirectorySeparatorChar)));
        var rootWithSep = _rootFull.EndsWith(Path.DirectorySeparatorChar) ? _rootFull : _rootFull + Path.DirectorySeparatorChar;
        if (!full.StartsWith(rootWithSep, StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Đường dẫn ảnh không hợp lệ.");
        return full;
    }

    public void Delete(string relative)
    {
        try
        {
            var full = FullPath(relative);
            if (File.Exists(full)) File.Delete(full);
        }
        catch (IOException)
        {
            // Xoá file lỗi thì bỏ qua: bản ghi đã xoá nên ảnh không còn tải được qua API.
        }
    }
}
