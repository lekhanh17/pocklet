# Pocklet – App Flutter (đợt 1: giao diện)

Đợt này gồm: khung app, theme hướng B · Nhật ký ảnh, thanh điều hướng 5 mục, **màn Hôm nay**, **màn Lịch** và màn xem ảnh toàn màn hình. Dữ liệu là **dữ liệu mẫu** (mock), chưa gọi API.

## Chạy lần đầu

Cần Flutter 3.24 trở lên (`flutter --version`).

```bash
# 1. Giải nén vào thư mục app/ của repo, rồi vào thư mục đó
cd app

# 2. Sinh thư mục android/ và ios/ (không ghi đè file đã có)
flutter create . --project-name pocklet --org com.pocklet --platforms android,ios

# 3. Đặt minSdk = 26 (NFR-06) trong android/app/build.gradle hoặc build.gradle.kts:
#    minSdk = 26

# 4. Cài thư viện, kiểm tra, chạy
flutter pub get
flutter analyze
flutter test
flutter run
```

Font Nunito được tải qua `google_fonts` khi chạy lần đầu nên máy cần có mạng. Bản release cần thêm quyền `<uses-permission android:name="android.permission.INTERNET"/>` trong `android/app/src/main/AndroidManifest.xml` (sau này gọi API cũng cần quyền này).

## Cấu trúc thư mục

```
lib/
  main.dart, app.dart           Điểm vào, MaterialApp
  core/                         Theme (màu hướng B), định dạng tiền BR-01, ngày tháng
  models/                       ExpenseCategory, Expense, CalendarMonth, BudgetOverview
  data/
    expense_repository.dart     Giao diện lớp dữ liệu, mỗi hàm ứng với một endpoint API
    mock_expense_repository.dart  Dữ liệu mẫu, sinh từ ngày 1 đến hôm nay
  providers/app_providers.dart  Toàn bộ provider Riverpod
  widgets/                      PhotoThumb (khung sọc thay ảnh), viền nét đứt, thẻ, AsyncView
  features/
    shell/                      Thanh điều hướng 5 mục
    today/                      Màn Hôm nay
    calendar/                   Màn Lịch
    photo_viewer/               Xem ảnh toàn màn hình
    placeholder/                Màn tạm cho Thống kê, Ngân sách
test/widget_test.dart           Test BR-01, BR-04, BR-06 và dữ liệu mẫu
```

## Khi API (vai A) xong

1. Tạo `lib/data/api_expense_repository.dart` với `class ApiExpenseRepository implements ExpenseRepository`; mỗi hàm gọi đúng endpoint ghi trong `expense_repository.dart` và dùng `fromJson` có sẵn trong `models/`.
2. Đổi **một dòng** trong `lib/providers/app_providers.dart`: `MockExpenseRepository()` → `ApiExpenseRepository(...)`.
3. Trong `lib/widgets/photo_thumb.dart`, thay khung sọc bằng `Image.network('/api/photos/{id}')` kèm header JWT (có ghi chú `TODO(API)`).

Các chỗ chưa làm đều có ghi chú `TODO(FR-xx)` để tìm nhanh: `grep -rn "TODO" lib`.
