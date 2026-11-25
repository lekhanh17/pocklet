using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;
using Pocklet.Api.Services;

namespace Pocklet.Api.Controllers;

[Route("api/expenses")]
public class ExpensesController(
    AppDbContext db,
    BudgetService budgets,
    PhotoStorage storage,
    IOptions<StorageOptions> storageOptions,
    TimeProvider clock) : ApiControllerBase
{
    /// <summary>
    /// Danh sách, lọc, tìm (FR-14, FR-23). from, to là ngày yyyy-MM-dd theo giờ Việt Nam, tính cả hai đầu.
    /// Kết quả mới nhất trước, kèm tổng số khoản và tổng tiền của toàn bộ kết quả.
    /// </summary>
    [HttpGet]
    public async Task<ActionResult<ExpensePageDto>> List(
        [FromQuery] DateOnly? from,
        [FromQuery] DateOnly? to,
        [FromQuery] int? categoryId,
        [FromQuery] string? q,
        [FromQuery] long? min,
        [FromQuery] long? max,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        CancellationToken ct = default)
    {
        if (page < 1) page = 1;
        pageSize = Math.Clamp(pageSize, 1, 100);
        if (from != null && to != null && from > to) return FieldError("to", "Ngày kết thúc phải sau ngày bắt đầu");

        var userId = UserId;
        var query = db.Expenses.AsNoTracking().Where(e => e.UserId == userId);

        if (from != null)
        {
            var fromUtc = VnTime.StartOfDayUtc(from.Value);
            query = query.Where(e => e.SpentAt >= fromUtc);
        }
        if (to != null)
        {
            var toUtc = VnTime.StartOfDayUtc(to.Value.AddDays(1));
            query = query.Where(e => e.SpentAt < toUtc);
        }
        if (categoryId != null) query = query.Where(e => e.CategoryId == categoryId);
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim();
            query = query.Where(e => e.Note != null && e.Note.Contains(term));
        }
        if (min != null)
        {
            var minAmount = (decimal)min.Value;
            query = query.Where(e => e.Amount >= minAmount);
        }
        if (max != null)
        {
            var maxAmount = (decimal)max.Value;
            query = query.Where(e => e.Amount <= maxAmount);
        }

        var totalCount = await query.CountAsync(ct);
        var totalAmount = await query.SumAsync(e => (decimal?)e.Amount, ct) ?? 0m;
        var items = await query
            .OrderByDescending(e => e.SpentAt).ThenByDescending(e => e.Id)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Include(e => e.Photos)
            .AsSplitQuery()
            .ToListAsync(ct);

        return new ExpensePageDto(items.Select(ToDto).ToList(), page, pageSize, totalCount, ToLong(totalAmount));
    }

    /// <summary>Chi tiết kèm danh sách ảnh.</summary>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<ExpenseDto>> Get(int id, CancellationToken ct)
    {
        var expense = await FindOwnedAsync(id, tracking: false, ct);
        if (expense == null) return NotFoundProblem("Không tìm thấy khoản chi");
        return ToDto(expense);
    }

    /// <summary>Thêm khoản chi (FR-07). Trả về khoản chi và các cảnh báo ngân sách vừa bật (FR-18).</summary>
    [HttpPost]
    [ProducesResponseType<ExpenseSaveResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<ExpenseSaveResponse>> Create(ExpenseRequest req, CancellationToken ct)
    {
        var invalid = await ValidateAsync(req, ct);
        if (invalid != null) return invalid;

        var now = clock.GetUtcNow().UtcDateTime;
        var expense = new Expense
        {
            UserId = UserId,
            CategoryId = req.CategoryId,
            Amount = req.Amount,
            SpentAt = req.SpentAt!.Value.UtcDateTime,
            Note = NormalizeNote(req.Note),
            CreatedAt = now,
            UpdatedAt = now,
        };
        db.Expenses.Add(expense);
        await db.SaveChangesAsync(ct);

        var alerts = await budgets.EvaluateAfterSaveAsync(expense.UserId, expense.SpentAt, expense.CategoryId, ct);
        return StatusCode(StatusCodes.Status201Created, ToSaveResponse(expense, alerts));
    }

    /// <summary>Sửa khoản chi (FR-08). Mọi trường sửa được.</summary>
    [HttpPut("{id:int}")]
    public async Task<ActionResult<ExpenseSaveResponse>> Update(int id, ExpenseRequest req, CancellationToken ct)
    {
        var expense = await FindOwnedAsync(id, tracking: true, ct);
        if (expense == null) return NotFoundProblem("Không tìm thấy khoản chi");

        var invalid = await ValidateAsync(req, ct);
        if (invalid != null) return invalid;

        expense.CategoryId = req.CategoryId;
        expense.Amount = req.Amount;
        expense.SpentAt = req.SpentAt!.Value.UtcDateTime;
        expense.Note = NormalizeNote(req.Note);
        expense.UpdatedAt = clock.GetUtcNow().UtcDateTime;
        await db.SaveChangesAsync(ct);

        var alerts = await budgets.EvaluateAfterSaveAsync(expense.UserId, expense.SpentAt, expense.CategoryId, ct);
        return ToSaveResponse(expense, alerts);
    }

    /// <summary>Xoá khoản chi và toàn bộ ảnh đi kèm, cả file trên đĩa (FR-09, BR-07).</summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken ct)
    {
        var expense = await FindOwnedAsync(id, tracking: true, ct);
        if (expense == null) return NotFoundProblem("Không tìm thấy khoản chi");

        var files = expense.Photos.Select(p => p.FilePath).ToList();
        db.Expenses.Remove(expense);
        await db.SaveChangesAsync(ct);
        foreach (var file in files) storage.Delete(file);
        return NoContent();
    }

    /// <summary>Tải một ảnh lên cho khoản chi (FR-10). Tối đa 5 ảnh, mỗi ảnh tối đa 2 MB, chỉ JPEG hoặc PNG (BR-05).</summary>
    [HttpPost("{id:int}/photos")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10 * 1024 * 1024)]
    [ProducesResponseType<PhotoCreatedDto>(StatusCodes.Status201Created)]
    public async Task<ActionResult<PhotoCreatedDto>> UploadPhoto(int id, [FromForm] PhotoUploadForm form, CancellationToken ct)
    {
        var options = storageOptions.Value;
        var expense = await FindOwnedAsync(id, tracking: true, ct);
        if (expense == null) return NotFoundProblem("Không tìm thấy khoản chi");

        var file = form.File;
        if (file == null || file.Length == 0) return FieldError("file", "Chọn ảnh");
        if (expense.Photos.Count >= options.MaxPhotosPerExpense)
            return ProblemWith(StatusCodes.Status409Conflict, $"Mỗi khoản chi tối đa {options.MaxPhotosPerExpense} ảnh");
        if (file.Length > options.MaxPhotoBytes)
            return ProblemWith(StatusCodes.Status413PayloadTooLarge, "Ảnh lớn hơn 2 MB");

        byte[] bytes;
        await using (var stream = file.OpenReadStream())
        using (var memory = new MemoryStream())
        {
            await stream.CopyToAsync(memory, ct);
            bytes = memory.ToArray();
        }

        var extension = PhotoStorage.DetectExtension(bytes);
        if (extension == null) return ProblemWith(StatusCodes.Status415UnsupportedMediaType, "Chỉ nhận ảnh JPEG hoặc PNG");

        var path = await storage.SaveAsync(expense.UserId, bytes, extension, ct);
        var photo = new ExpensePhoto
        {
            FilePath = path,
            IsReceipt = form.IsReceipt,
            SizeBytes = bytes.Length,
            CreatedAt = clock.GetUtcNow().UtcDateTime,
        };
        expense.Photos.Add(photo);

        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch
        {
            storage.Delete(path);
            throw;
        }

        return StatusCode(StatusCodes.Status201Created, new PhotoCreatedDto(photo.Id, expense.Id, photo.IsReceipt));
    }

    private async Task<Expense?> FindOwnedAsync(int id, bool tracking, CancellationToken ct)
    {
        var userId = UserId;
        var query = db.Expenses.Include(e => e.Photos).Where(e => e.Id == id && e.UserId == userId);
        if (!tracking) query = query.AsNoTracking();
        return await query.FirstOrDefaultAsync(ct);
    }

    /// <summary>Danh mục phải là mặc định hoặc của chính người dùng; không cho chọn thời điểm sau hiện tại (BR-02).</summary>
    private async Task<ActionResult?> ValidateAsync(ExpenseRequest req, CancellationToken ct)
    {
        var userId = UserId;
        var categoryOk = await db.Categories.AnyAsync(c => c.Id == req.CategoryId && (c.UserId == null || c.UserId == userId), ct);
        if (!categoryOk) return FieldError("categoryId", "Danh mục không tồn tại");

        // Cho lệch 2 phút để đồng hồ điện thoại và server không khớp hẳn vẫn lưu được.
        if (req.SpentAt!.Value > clock.GetUtcNow().AddMinutes(2))
            return FieldError("spentAt", "Không chọn được thời điểm sau hiện tại");

        return null;
    }

    private static string? NormalizeNote(string? note)
    {
        var trimmed = note?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    private static ExpenseSaveResponse ToSaveResponse(Expense e, IReadOnlyList<BudgetAlertDto> alerts)
    {
        var dto = ToDto(e);
        return new ExpenseSaveResponse(dto.Id, dto.CategoryId, dto.Amount, dto.SpentAt, dto.Note, dto.Photos, dto.CreatedAt, alerts);
    }
}
