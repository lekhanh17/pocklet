using Microsoft.EntityFrameworkCore;

namespace Pocklet.Api.Data;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<User> Users => Set<User>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Expense> Expenses => Set<Expense>();
    public DbSet<ExpensePhoto> ExpensePhotos => Set<ExpensePhoto>();
    public DbSet<Budget> Budgets => Set<Budget>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<User>(e =>
        {
            e.Property(x => x.Email).HasMaxLength(256).IsRequired();
            e.HasIndex(x => x.Email).IsUnique();
            e.Property(x => x.PasswordHash).IsRequired();
            e.Property(x => x.DisplayName).HasMaxLength(100).IsRequired();
            e.Property(x => x.CreatedAt).HasDefaultValueSql("sysutcdatetime()");
        });

        b.Entity<Category>(e =>
        {
            e.Property(x => x.Name).HasMaxLength(50).IsRequired();
            e.Property(x => x.Icon).HasMaxLength(50).IsUnicode(false).IsRequired();
            e.Property(x => x.Color).HasMaxLength(7).IsFixedLength().IsUnicode(false).IsRequired();
            e.Ignore(x => x.IsDefault);
            // HasFilter(null): SQL Server coi các NULL là bằng nhau, nên tên danh mục mặc định cũng không trùng nhau.
            e.HasIndex(x => new { x.UserId, x.Name }).IsUnique().HasFilter(null);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasData(DefaultCategories.All.Select(c => new { c.Id, UserId = (int?)null, c.Name, c.Icon, c.Color }));
        });

        b.Entity<Expense>(e =>
        {
            e.Property(x => x.Amount).HasPrecision(18, 0);
            e.Property(x => x.Note).HasMaxLength(200);
            e.HasIndex(x => new { x.UserId, x.SpentAt });
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.NoAction);
        });

        b.Entity<ExpensePhoto>(e =>
        {
            e.Property(x => x.FilePath).HasMaxLength(260).IsRequired();
            e.HasOne(x => x.Expense).WithMany(x => x.Photos).HasForeignKey(x => x.ExpenseId).OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<Budget>(e =>
        {
            e.Property(x => x.LimitAmount).HasPrecision(18, 0);
            // HasFilter(null) giữ đúng ý BR-04: mỗi tháng chỉ có một ngân sách tổng (CategoryId = NULL).
            e.HasIndex(x => new { x.UserId, x.CategoryId, x.Month }).IsUnique().HasFilter(null);
            e.HasOne(x => x.User).WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId).OnDelete(DeleteBehavior.NoAction);
        });
    }
}
