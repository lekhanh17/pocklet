using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;
using Pocklet.Api.Services;

namespace Pocklet.Api.Controllers;

[Route("api/photos")]
public class PhotosController(AppDbContext db, PhotoStorage storage) : ApiControllerBase
{
    /// <summary>Trả file ảnh; chỉ chủ khoản chi tải được (NFR-04). Thư mục uploads/ không mở ra ngoài.</summary>
    [HttpGet("{id:int}")]
    [Produces("image/jpeg", "image/png")]
    [ProducesResponseType(typeof(FileResult), StatusCodes.Status200OK)]
    public async Task<ActionResult> Get(int id, CancellationToken ct)
    {
        var photo = await FindOwnedAsync(id, ct);
        if (photo == null) return NotFoundProblem("Không tìm thấy ảnh");

        var full = storage.FullPath(photo.FilePath);
        if (!System.IO.File.Exists(full)) return NotFoundProblem("Không tìm thấy ảnh");

        Response.Headers.CacheControl = "private, max-age=86400";
        return PhysicalFile(full, PhotoStorage.ContentTypeFor(photo.FilePath));
    }

    /// <summary>Đánh dấu hoặc bỏ đánh dấu ảnh là hoá đơn (FR-12).</summary>
    [HttpPatch("{id:int}")]
    public async Task<ActionResult<PhotoDto>> Patch(int id, PhotoPatchRequest req, CancellationToken ct)
    {
        var photo = await FindOwnedAsync(id, ct);
        if (photo == null) return NotFoundProblem("Không tìm thấy ảnh");

        photo.IsReceipt = req.IsReceipt!.Value;
        await db.SaveChangesAsync(ct);
        return new PhotoDto(photo.Id, photo.IsReceipt);
    }

    /// <summary>Xoá một ảnh; xoá rồi thì không tải được nữa (FR-12).</summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken ct)
    {
        var photo = await FindOwnedAsync(id, ct);
        if (photo == null) return NotFoundProblem("Không tìm thấy ảnh");

        var file = photo.FilePath;
        db.ExpensePhotos.Remove(photo);
        await db.SaveChangesAsync(ct);
        storage.Delete(file);
        return NoContent();
    }

    private Task<ExpensePhoto?> FindOwnedAsync(int id, CancellationToken ct)
    {
        var userId = UserId;
        return db.ExpensePhotos.FirstOrDefaultAsync(p => p.Id == id && p.Expense!.UserId == userId, ct);
    }
}
