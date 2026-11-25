using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;

namespace Pocklet.Api.Controllers;

[Route("api/me")]
public class MeController(AppDbContext db, IPasswordHasher<User> hasher) : ApiControllerBase
{
    [HttpGet]
    public async Task<ActionResult<UserDto>> Get(CancellationToken ct)
    {
        var user = await db.Users.FindAsync([UserId], ct);
        if (user == null) return Unauthorized();
        return ToUserDto(user);
    }

    /// <summary>Đổi tên hiển thị (FR-04).</summary>
    [HttpPut]
    public async Task<ActionResult<UserDto>> Update(UpdateMeRequest req, CancellationToken ct)
    {
        var name = req.DisplayName.Trim();
        if (name.Length == 0) return FieldError("displayName", "Nhập tên hiển thị");

        var user = await db.Users.FindAsync([UserId], ct);
        if (user == null) return Unauthorized();
        user.DisplayName = name;
        await db.SaveChangesAsync(ct);
        return ToUserDto(user);
    }

    /// <summary>Đổi mật khẩu; phải nhập đúng mật khẩu cũ (FR-04).</summary>
    [HttpPut("password")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult> ChangePassword(ChangePasswordRequest req, CancellationToken ct)
    {
        var user = await db.Users.FindAsync([UserId], ct);
        if (user == null) return Unauthorized();

        if (hasher.VerifyHashedPassword(user, user.PasswordHash, req.CurrentPassword) == PasswordVerificationResult.Failed)
            return FieldError("currentPassword", "Mật khẩu hiện tại không đúng");

        user.PasswordHash = hasher.HashPassword(user, req.NewPassword);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static UserDto ToUserDto(User u) => new(u.Id, u.Email, u.DisplayName, VnTime.FromUtc(u.CreatedAt));
}
