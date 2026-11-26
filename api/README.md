# Pocklet Web API

ASP.NET Core Web API (.NET 10) + EF Core + SQL Server cho app Pocklet. Làm theo đặc tả Pocklet (FR-01 đến FR-23 phần server, BR-01 đến BR-09).

```
api/
├── Pocklet.slnx
├── Pocklet.Api/          Controllers, Data (EF Core), Services (luật nghiệp vụ), SeedData (ảnh mẫu)
├── Pocklet.Api.Tests/    Test xUnit cho BR-04, BR-06, giờ VN, kiểm tra loại ảnh
└── e2e/e2e.py            Kiểm thử đầu-cuối: gọi từng endpoint trên API đang chạy
```

## Chạy

Cần: .NET SDK 10, SQL Server Express (hoặc LocalDB), công cụ `dotnet-ef`.

```powershell
dotnet tool install --global dotnet-ef
cd api/Pocklet.Api

# Khoá ký JWT để trong user-secrets, không đưa lên GitHub (NFR-03)
$b = New-Object byte[] 48; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
dotnet user-secrets set "Jwt:Key" ([Convert]::ToBase64String($b))

# Chỉ khi KHÔNG dùng SQL Server Express mặc định (localhost\SQLEXPRESS), ví dụ LocalDB:
dotnet user-secrets set "ConnectionStrings:Default" "Server=(localdb)\MSSQLLocalDB;Database=Pocklet;Trusted_Connection=True;TrustServerCertificate=True"

# Tạo migration lần đầu, một người tạo rồi commit thư mục Migrations cho cả nhóm
dotnet ef migrations add InitialCreate

# --seed-demo tạo tài khoản mẫu demo@pocklet.vn / Demo@1234 có sẵn khoảng 2 tháng dữ liệu kèm ảnh
dotnet run -- --seed-demo
```

- API chạy ở `http://localhost:5080`. Thử ở `http://localhost:5080/swagger`: gọi `POST /api/auth/login`, bấm **Authorize**, dán token.
- Database tự tạo và cập nhật khi API khởi động. Ảnh lưu ở `Pocklet.Api/uploads/` (không commit).
- Test: `cd api && dotnet test`. Kiểm thử đầu-cuối khi API đang chạy: `pip install requests pillow` rồi `python api/e2e/e2e.py`.
- Điện thoại thật gọi API qua IP laptop (cùng Wi-Fi), mở cổng 5080 trên tường lửa (PowerShell quyền Admin):
  `New-NetFirewallRule -DisplayName "Pocklet API" -Direction Inbound -Protocol TCP -LocalPort 5080 -Action Allow`

## Hợp đồng API cho app

Địa chỉ: máy ảo Android `http://10.0.2.2:5080`, điện thoại thật `http://<IP laptop>:5080`.
Mọi endpoint trừ đăng ký, đăng nhập đều cần header `Authorization: Bearer <token>`. Token hạn 7 ngày; gặp 401 thì về màn Đăng nhập.
Thời gian trả về có múi giờ, ví dụ `"2026-11-22T10:05:00+07:00"`; ngày, tháng tính theo giờ Việt Nam (BR-02). Tiền là số nguyên VND.

### Tài khoản (FR-01 đến FR-04)

| Endpoint | Gửi | Nhận |
|---|---|---|
| `POST /api/auth/register` | `{email, password, displayName}` | `{token, expiresAt, user: {id, email, displayName, createdAt}}` |
| `POST /api/auth/login` | `{email, password}` | như trên; sai thì 401 |
| `GET /api/me` | | `user` |
| `PUT /api/me` | `{displayName}` | `user` |
| `PUT /api/me/password` | `{currentPassword, newPassword}` | 204 |

### Danh mục (FR-05, FR-06)

`GET /api/categories` → `[{id, name, icon, color, isDefault}]`, 8 danh mục mặc định có id 1 đến 8 (Khác là 8).
Tên biểu tượng và màu của 8 danh mục mặc định giống hệt dữ liệu mẫu trong `app/lib/data/mock_expense_repository.dart`.
`POST /api/categories`, `PUT /api/categories/{id}` gửi `{name, icon, color}`; `DELETE /api/categories/{id}` chuyển khoản chi sang Khác.
Sửa, xoá danh mục mặc định trả 403; tên trùng trả 400 kèm lỗi ở trường `name`.

### Khoản chi (FR-07 đến FR-09, FR-23)

Một khoản chi:

```json
{ "id": 12, "categoryId": 1, "amount": 45000, "spentAt": "2026-11-22T07:40:00+07:00",
  "note": "Phở bò", "photos": [{ "id": 30, "isReceipt": false }], "createdAt": "2026-11-22T07:41:02+07:00" }
```

| Endpoint | Gửi | Nhận |
|---|---|---|
| `GET /api/expenses?from=&to=&categoryId=&q=&min=&max=&page=1&pageSize=20` | ngày dạng `yyyy-MM-dd`, tính cả hai đầu | `{items: [khoản chi], page, pageSize, totalCount, totalAmount}`, mới nhất trước, `pageSize` tối đa 100 |
| `GET /api/expenses/{id}` | | khoản chi |
| `POST /api/expenses` | `{categoryId, amount, spentAt, note}` | 201: khoản chi + `budgetAlerts: [{categoryId, level, percent}]` |
| `PUT /api/expenses/{id}` | như trên | 200: khoản chi + `budgetAlerts` |
| `DELETE /api/expenses/{id}` | | 204, xoá luôn ảnh |

`budgetAlerts` chỉ có phần tử ở đúng lần lưu làm vượt ngưỡng (FR-18): `level` là `"warning"` (từ 80%) hoặc `"exceeded"` (trên 100%), `categoryId` null là ngân sách tổng.

### Ảnh (FR-10 đến FR-12)

| Endpoint | Gửi | Nhận |
|---|---|---|
| `POST /api/expenses/{id}/photos` | multipart: `file` (JPEG/PNG ≤ 2 MB), `isReceipt` (`true`/`false`) | 201 `{id, expenseId, isReceipt}`; ảnh thứ 6 → 409, quá 2 MB → 413, không phải JPEG/PNG → 415 |
| `GET /api/photos/{id}` | | file ảnh; **cần header JWT**, nên dùng `Image.network(url, headers: {'Authorization': 'Bearer $token'})` |
| `PATCH /api/photos/{id}` | `{isReceipt}` | `{id, isReceipt}` |
| `DELETE /api/photos/{id}` | | 204 |

Lưu khoản chi có ảnh theo hai bước (mục 4.1): `POST /api/expenses` lấy `id`, rồi tải từng ảnh lên.

### Lịch, ngân sách, thống kê

| Endpoint | Nhận |
|---|---|
| `GET /api/calendar?month=yyyy-MM` (FR-13 đến FR-15) | `{month, total, days: [{date, total, count, coverPhotoId}]}`, chỉ có những ngày có khoản chi; `coverPhotoId` theo BR-06 |
| `GET /api/budgets?month=yyyy-MM` (FR-16 đến FR-18) | `{month, total, categories, suggestedFromPreviousMonth}`; `total` và mỗi phần tử `categories` là `{categoryId, name, limitAmount, spent, percent, level}`; `total` null nếu chưa đặt; `suggestedFromPreviousMonth` có khi tháng này chưa đặt mà tháng trước đã đặt |
| `PUT /api/budgets` gửi `{month, items: [{categoryId, limitAmount}]}` | thay toàn bộ ngân sách của tháng, `categoryId` null là ngân sách tổng; trả lại như GET |
| `GET /api/stats/monthly?month=yyyy-MM` (FR-20, FR-21) | `{month, total, previousTotal, changePercent, budgetLimit, dailyBudget, byCategory: [{categoryId, name, icon, color, total, percent}], byDay: [{date, total, previousMonthTotal}]}` |

### Lỗi

Dạng ProblemDetails: `{title, status, detail, errors: {tenTruong: ["thông báo"]}}`. Thông báo đã viết bằng tiếng Việt, hiện thẳng lên màn hình được.
400 dữ liệu sai, 401 chưa đăng nhập hoặc token hết hạn, 403 sửa danh mục mặc định, 404 không có hoặc của người khác,
409 email đã dùng hoặc đủ 5 ảnh, 413 ảnh quá 2 MB, 415 sai loại ảnh.

### Nối vào `ExpenseRepository` của app

| Hàm | Gọi | Đọc kết quả |
|---|---|---|
| `getCategories()` | `GET /api/categories` | `ExpenseCategory.fromJson` từng phần tử |
| `getExpenses(from, to)` | `GET /api/expenses?from=…&to=…&pageSize=100` | `Expense.fromJson` từng phần tử của `items`; nếu `totalCount` > 100 thì gọi tiếp `page=2` |
| `getCalendar(month)` | `GET /api/calendar?month=yyyy-MM` | `CalendarMonth.fromJson` |
| `getBudgets(month)` | `GET /api/budgets?month=yyyy-MM` | `BudgetOverview.fromJson` |
