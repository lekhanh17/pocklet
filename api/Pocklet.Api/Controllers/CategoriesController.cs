using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;

namespace Pocklet.Api.Controllers;

[Route("api/categories")]
public class CategoriesController(AppDbContext db) : ApiControllerBase
{
    /// <summary>8 danh mục mặc định trước, rồi danh mục riêng theo tên (FR-05, FR-06).</summary>
    [HttpGet]
    public async Task<ActionResult<List<CategoryDto>>> List(CancellationToken ct)
    {
        var userId = UserId;
        var list = await db.Categories.AsNoTracking()
            .Where(c => c.UserId == null || c.UserId == userId)
            .ToListAsync(ct);

        return list
            .OrderBy(c => c.UserId == null ? 0 : 1)
            .ThenBy(c => c.UserId == null ? c.Id.ToString("D4") : c.Name)
            .Select(ToDto)
            .ToList();
    }

    [HttpPost]
    [ProducesResponseType<CategoryDto>(StatusCodes.Status201Created)]
    public async Task<ActionResult<CategoryDto>> Create(CategoryRequest req, CancellationToken ct)
    {
        var name = req.Name.Trim();
        if (name.Length == 0) return FieldError("name", "Nhập tên danh mục");
        if (await NameTakenAsync(name, null, ct)) return FieldError("name", "Tên danh mục đã có");

        var category = new Category { UserId = UserId, Name = name, Icon = req.Icon.Trim(), Color = req.Color.ToUpperInvariant() };
        db.Categories.Add(category);
        await db.SaveChangesAsync(ct);
        return StatusCode(StatusCodes.Status201Created, ToDto(category));
    }

    [HttpPut("{id:int}")]
    public async Task<ActionResult<CategoryDto>> Update(int id, CategoryRequest req, CancellationToken ct)
    {
        var category = await db.Categories.FirstOrDefaultAsync(c => c.Id == id, ct);
        if (category == null || (category.UserId != null && category.UserId != UserId)) return NotFoundProblem("Không tìm thấy danh mục");
        if (category.UserId == null) return ProblemWith(StatusCodes.Status403Forbidden, "Không sửa được danh mục mặc định");

        var name = req.Name.Trim();
        if (name.Length == 0) return FieldError("name", "Nhập tên danh mục");
        if (await NameTakenAsync(name, id, ct)) return FieldError("name", "Tên danh mục đã có");

        category.Name = name;
        category.Icon = req.Icon.Trim();
        category.Color = req.Color.ToUpperInvariant();
        await db.SaveChangesAsync(ct);
        return ToDto(category);
    }

    /// <summary>Xoá danh mục riêng: khoản chi chuyển sang "Khác", ngân sách của danh mục bị xoá (BR-03).</summary>
    [HttpDelete("{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> Delete(int id, CancellationToken ct)
    {
        var userId = UserId;
        var category = await db.Categories.FirstOrDefaultAsync(c => c.Id == id, ct);
        if (category == null || (category.UserId != null && category.UserId != userId)) return NotFoundProblem("Không tìm thấy danh mục");
        if (category.UserId == null) return ProblemWith(StatusCodes.Status403Forbidden, "Không xoá được danh mục mặc định");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        await db.Expenses.Where(e => e.UserId == userId && e.CategoryId == id)
            .ExecuteUpdateAsync(s => s.SetProperty(e => e.CategoryId, DefaultCategories.Khac), ct);
        await db.Budgets.Where(b => b.UserId == userId && b.CategoryId == id).ExecuteDeleteAsync(ct);
        db.Categories.Remove(category);
        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);
        return NoContent();
    }

    /// <summary>
    /// Tên trùng với danh mục mặc định hoặc danh mục riêng khác của người dùng (BR-03), không phân biệt hoa thường.
    /// Mỗi người chỉ có vài danh mục nên so trong bộ nhớ, không phụ thuộc collation của database
    /// (LOWER của một số database không đổi được chữ có dấu như "Ă").
    /// </summary>
    private async Task<bool> NameTakenAsync(string name, int? exceptId, CancellationToken ct)
    {
        var userId = UserId;
        var names = await db.Categories.AsNoTracking()
            .Where(c => (c.UserId == userId || c.UserId == null) && c.Id != exceptId)
            .Select(c => c.Name)
            .ToListAsync(ct);
        return names.Any(n => string.Equals(n.Trim(), name, StringComparison.OrdinalIgnoreCase));
    }
}
