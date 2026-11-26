using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Pocklet.Api.Common;
using Pocklet.Api.Data;
using Pocklet.Api.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------- Cấu hình ----------
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("Jwt"));
builder.Services.Configure<StorageOptions>(builder.Configuration.GetSection("Storage"));
var jwt = builder.Configuration.GetSection("Jwt").Get<JwtOptions>() ?? new JwtOptions();
if (Encoding.UTF8.GetByteCount(jwt.Key) < 32 && !EF.IsDesignTime)
{
    if (!builder.Environment.IsDevelopment())
    {
        throw new InvalidOperationException(
            "Jwt:Key phải dài ít nhất 32 byte (NFR-03). Đặt bằng biến môi trường Jwt__Key.");
    }

    // Máy dev chưa đặt khoá: tạo khoá tạm để chạy được ngay. Token sẽ hết hiệu lực mỗi lần khởi động lại API.
    jwt.Key = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(48));
    builder.Configuration["Jwt:Key"] = jwt.Key;
    Console.WriteLine(
        "CẢNH BÁO: chưa đặt Jwt:Key, đang dùng khoá tạm. Chạy: dotnet user-secrets set \"Jwt:Key\" \"<chuỗi ngẫu nhiên từ 32 ký tự>\"");
}

// ---------- Dịch vụ ----------
builder.Services.AddDbContext<AppDbContext>(o =>
    o.UseSqlServer(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<IPasswordHasher<User>, PasswordHasher<User>>();
builder.Services.AddSingleton<TokenService>();
builder.Services.AddSingleton<PhotoStorage>();
builder.Services.AddScoped<BudgetService>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = jwt.Issuer,
            ValidateAudience = true,
            ValidAudience = jwt.Audience,
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Key)),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.FromMinutes(1),
        };
    });
builder.Services.AddAuthorization();

builder.Services.AddControllers();
builder.Services.AddProblemDetails();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new OpenApiInfo { Title = "Pocklet API", Version = "v1" });
    o.AddSecurityDefinition("bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Description = "Dán token nhận được từ /api/auth/login (không cần chữ Bearer).",
    });
    o.AddSecurityRequirement(document => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("bearer", document)] = [],
    });
    var xml = Path.Combine(AppContext.BaseDirectory, "Pocklet.Api.xml");
    if (File.Exists(xml)) o.IncludeXmlComments(xml);
});

var app = builder.Build();

// ---------- Cơ sở dữ liệu ----------
using (var scope = app.Services.CreateScope())
{
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    try
    {
        await db.Database.MigrateAsync();
    }
    catch (InvalidOperationException ex)
    {
        logger.LogCritical(ex,
            "Không áp dụng được migration. Nếu chưa có thư mục Migrations, chạy: dotnet ef migrations add InitialCreate");
        throw;
    }

    if (args.Contains("--seed-demo"))
    {
        await DemoSeeder.SeedAsync(scope.ServiceProvider, logger);
    }
}

// ---------- Pipeline ----------
app.UseExceptionHandler();
app.UseStatusCodePages();

app.UseSwagger();
app.UseSwaggerUI(o =>
{
    o.SwaggerEndpoint("/swagger/v1/swagger.json", "Pocklet API v1");
    o.DocumentTitle = "Pocklet API";
});

app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();

app.Run();
