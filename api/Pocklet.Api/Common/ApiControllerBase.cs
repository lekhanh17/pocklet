using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.JsonWebTokens;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;

namespace Pocklet.Api.Common;

[ApiController]
[Authorize]
[Produces("application/json")]
public abstract class ApiControllerBase : ControllerBase
{
    /// <summary>Id người dùng lấy từ JWT, không bao giờ lấy từ request (NFR-04).</summary>
    protected int UserId =>
        int.Parse(User.FindFirstValue(JwtRegisteredClaimNames.Sub)
                  ?? throw new UnauthorizedAccessException("Token thiếu thông tin người dùng."));

    /// <summary>Lỗi dữ liệu gắn với một trường để app hiện ngay dưới ô nhập đó.</summary>
    protected ActionResult FieldError(string field, string message)
    {
        ModelState.AddModelError(field, message);
        return ValidationProblem(ModelState);
    }

    protected ObjectResult ProblemWith(int status, string title) => Problem(title: title, statusCode: status);

    /// <summary>Không tồn tại hoặc thuộc người khác đều trả 404 để không lộ là có tồn tại (NFR-04).</summary>
    protected ObjectResult NotFoundProblem(string title = "Không tìm thấy") => Problem(title: title, statusCode: StatusCodes.Status404NotFound);

    protected static long ToLong(decimal value) => (long)decimal.Round(value, 0);

    protected static CategoryDto ToDto(Category c) => new(c.Id, c.Name, c.Icon, c.Color, c.UserId == null);

    protected static ExpenseDto ToDto(Expense e) => new(
        e.Id,
        e.CategoryId,
        ToLong(e.Amount),
        VnTime.FromUtc(e.SpentAt),
        e.Note,
        e.Photos.OrderBy(p => p.CreatedAt).ThenBy(p => p.Id).Select(p => new PhotoDto(p.Id, p.IsReceipt)).ToList(),
        VnTime.FromUtc(e.CreatedAt));
}
