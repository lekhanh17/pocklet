# Pocklet – App Flutter (đợt 1: giao diện)

Đợt này gồm: khung app, theme tông ấm kiểu game nuôi thú theo mục 5 đặc tả v3 (nền kem `#FBF1E1`, chữ nâu `#412402`, một màu tương tác xanh lá `#3B6D11`, font Nunito, nhấn thu nhỏ 0.95), thanh điều hướng 5 mục, **phòng bạn đồng hành** (FR-19, FR-29, FR-30), **màn Hôm nay**, **màn Lịch**, màn xem ảnh toàn màn hình, **màn Camera** và **form Thêm khoản chi** (luồng 4.1: chụp → nhập → lưu, nén ảnh theo BR-05). Dữ liệu là **dữ liệu mẫu** (mock), chưa gọi API; ảnh chụp thật được giữ trong bộ nhớ của phiên chạy.

## Chạy lần đầu

Cần **Flutter 3.44 trở lên** (`flutter --version`): `pubspec.lock` hiện yêu cầu Flutter ≥ 3.44.0 và Dart ≥ 3.12 (camera, image_picker bản mới). Máy cũ hơn thì chạy `flutter upgrade` trước. Cần JDK 17 trở lên (Android Studio có sẵn).

```bash
# 1. Giải nén vào thư mục app/ của repo, rồi vào thư mục đó
cd app

# 2. Cài thư viện, kiểm tra, chạy (android/ và ios/ đã có sẵn trong repo, minSdk = 26 theo NFR-06)
flutter pub get
flutter analyze
flutter test
flutter run
```

Font Nunito (giấy phép OFL) đóng gói sẵn trong `assets/fonts/`, không tải qua mạng, nên chạy được cả khi demo không có Internet.

## Quyền đã khai báo

- Android `src/main/AndroidManifest.xml`: `INTERNET` (gọi API) và `CAMERA` (FR-10).
- Android `src/debug/AndroidManifest.xml`: `usesCleartextTraffic` để bản debug gọi API bằng HTTP trong LAN; bản release không bật (NFR-09).
- iOS `Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.

Máy ảo Android: vào **Device Manager → Edit → Show Advanced Settings → Camera**, chọn *VirtualScene* hoặc *Webcam0* cho camera sau.

## Cấu trúc thư mục

```
lib/
  main.dart, app.dart           Điểm vào, MaterialApp
  core/                         Theme (AppColors, AppText, AppRadius, AppSpacing), định dạng tiền BR-01, ngày tháng
  models/                       ExpenseCategory, Expense, CalendarMonth, BudgetOverview
  data/
    expense_repository.dart     Giao diện lớp dữ liệu, mỗi hàm ứng với một endpoint API
    mock_expense_repository.dart  Dữ liệu mẫu, sinh từ ngày 1 đến hôm nay
  providers/app_providers.dart  Toàn bộ provider Riverpod
  widgets/                      PhotoThumb (khung sọc thay ảnh), Pressable (nhấn thu nhỏ), viền nét đứt, thẻ, AsyncView
  features/
    shell/                      Thanh điều hướng 5 mục
    today/                      Màn Hôm nay
    calendar/                   Màn Lịch
    photo_viewer/               Xem ảnh toàn màn hình
    capture/                    Màn Camera + startCaptureFlow (mở từ nút Chụp)
    expense_form/               Form Thêm khoản chi, bàn phím số có phím 000
    placeholder/                Màn tạm cho Thống kê, Ngân sách
test/widget_test.dart           Test BR-01, BR-04, BR-05, BR-06, BR-10 (pet), bàn phím số và dữ liệu mẫu
test/logic_test.dart            Test qua ngày mới, mức cảnh báo từ API, nén ảnh, Lịch không mở tháng tương lai
```

## Khi API (vai A) xong

API nằm ở thư mục `api/` của repo, hợp đồng endpoint và cách chạy xem `api/README.md`.

1. Tạo `lib/data/api_expense_repository.dart` với `class ApiExpenseRepository implements ExpenseRepository`; mỗi hàm gọi đúng endpoint ghi trong `expense_repository.dart` và dùng `fromJson` có sẵn trong `models/`.
2. Đổi **một dòng** trong `lib/providers/app_providers.dart`: `MockExpenseRepository()` → `ApiExpenseRepository(...)`.
3. Hàm `photoImage(photoId)` của `ApiExpenseRepository` trả về `NetworkImage('/api/photos/{id}')` kèm header JWT; `PhotoThumb` tự dùng nguồn này (và tự thu nhỏ ảnh theo ô hiển thị).
4. `setMonthlyBudget`: `PUT /api/budgets` thay **toàn bộ** ngân sách của tháng, nên phải gửi kèm các dòng ngân sách danh mục đang có (xem ghi chú trong `expense_repository.dart`).

Các chỗ chưa làm đều có ghi chú `TODO(FR-xx)` để tìm nhanh: `grep -rn "TODO" lib`.
