using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Dtos;
using Pocklet.Api.Services;

namespace Pocklet.Api.Controllers;

[Route("api/auth")]
public class AuthController(AppDbContext db, TokenService tokens, IPasswordHasher<User> hasher, TimeProvider clock)
    : ApiControllerBase
{
    /// <summary>Đăng ký bằng email, mật khẩu, tên hiển thị (FR-01).</summary>
    [AllowAnonymous]
    [HttpPost("register")]
    [ProducesResponseType<AuthResponse>(StatusCodes.Status201Created)]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest req, CancellationToken ct)
    {
        var email = req.Email.Trim().ToLowerInvariant();
        var displayName = req.DisplayName.Trim();
        if (displayName.Length == 0) return FieldError("displayName", "Nhập tên hiển thị");

        if (await db.Users.AnyAsync(u => u.Email == email, ct))
        {
            ModelState.AddModelError("email", "Email đã được dùng");
            return ValidationProblem(title: "Email đã được dùng", statusCode: StatusCodes.Status409Conflict, modelStateDictionary: ModelState);
        }

        var user = new User
        {
            Email = email,
            DisplayName = displayName,
            CreatedAt = clock.GetUtcNow().UtcDateTime,
        };
        user.PasswordHash = hasher.HashPassword(user, req.Password);
        db.Users.Add(user);
        await db.SaveChangesAsync(ct);

        return StatusCode(StatusCodes.Status201Created, Issue(user));
    }

    /// <summary>Đăng nhập (FR-02). Sai email hoặc mật khẩu đều báo chung một câu.</summary>
    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest req, CancellationToken ct)
    {
        var email = req.Email.Trim().ToLowerInvariant();
        var user = await db.Users.FirstOrDefaultAsync(u => u.Email == email, ct);
        if (user == null) return ProblemWith(StatusCodes.Status401Unauthorized, "Email hoặc mật khẩu không đúng");

        var result = hasher.VerifyHashedPassword(user, user.PasswordHash, req.Password);
        if (result == PasswordVerificationResult.Failed)
            return ProblemWith(StatusCodes.Status401Unauthorized, "Email hoặc mật khẩu không đúng");

        if (result == PasswordVerificationResult.SuccessRehashNeeded)
        {
            user.PasswordHash = hasher.HashPassword(user, req.Password);
            await db.SaveChangesAsync(ct);
        }

        return Ok(Issue(user));
    }

    private AuthResponse Issue(User user)
    {
        var (token, expiresAt) = tokens.Create(user);
        return new AuthResponse(token, expiresAt, new UserDto(user.Id, user.Email, user.DisplayName, VnTime.FromUtc(user.CreatedAt)));
    }
}
