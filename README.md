HƯỚNG DẪN TRIỂN KHAI HỆ THỐNG QUẢN LÝ MUA BÁN ĐIỆN THOẠI ONLINE

Tài liệu này cung cấp quy trình thiết lập và vận hành hệ thống bao gồm máy chủ API (Laravel) và ứng dụng di động (Flutter).

1. YÊU CẦU MÔI TRƯỜNG



Backend: PHP >= 8.1 , MySQL/MariaDB >= 10.4.  



Frontend: Flutter SDK, Android Studio hoặc VS Code.  



Công cụ bổ trợ: XAMPP , zrok (Tunneling) , Composer.  

2. TRIỂN KHAI MÁY CHỦ (BACKEND)



Cài đặt thư viện: Di chuyển vào thư mục backend và thực hiện lệnh composer install.  

Cấu hình môi trường:

Sao chép tệp .env.example thành .env.  

Khai báo thông số kết nối Database: DB_DATABASE=db_phone_market, DB_USERNAME, DB_PASSWORD.  

Khởi tạo Database:

Truy cập phpMyAdmin, tạo cơ sở dữ liệu tên db_phone_market.  

Thực thi lệnh php artisan migrate để tạo cấu trúc 29 bảng hệ thống.  

(Tùy chọn) Import tệp SQL mẫu để có dữ liệu thử nghiệm.  

Khởi chạy Server:

Thực thi php artisan key:generate.  

Thực thi php artisan serve để chạy server tại cổng 8000.  

3. THIẾT LẬP KẾT NỐI (NETWORK TUNNELING)

Để ứng dụng di động trên thiết bị thật có thể kết nối với server localhost, sử dụng giải pháp zrok:

Lệnh thực thi: zrok2.exe share public http://localhost:8000.  

Lưu lại URL công khai được cấp (ví dụ: https://...zrok.io) để cấu hình cho Frontend.

4. TRIỂN KHAI ỨNG DỤNG DI ĐỘNG (FRONTEND)



Cài đặt thư viện: Di chuyển vào thư mục frontend và thực hiện lệnh flutter pub get.  

Cấu hình API:

Mở tệp lib/core/network/api_config.dart.

Cập nhật biến _zrokUrl bằng URL công khai nhận được từ bước 3.

Vận hành:

Kết nối thiết bị Android/iOS hoặc khởi động trình giả lập.

Thực thi lệnh flutter run để khởi chạy ứng dụng.  

5. CẤU TRÚC LOGIC TRỌNG TÂM



Xác thực: Sử dụng Laravel Sanctum cấp phát Personal Access Token. Token được đính kèm trong Header yêu cầu để định danh người dùng.  

Xử lý hình ảnh: Hệ thống lưu trữ ảnh tương đối trên server. Mobile App tự động nối chuỗi domainUrl và tiền tố /storage/ để hiển thị ảnh tuyệt đối.

Quản lý tài chính:

Đơn hàng hoàn tất (delivered) sẽ tự động kích hoạt logic cộng tiền vào ví Shop sau khi khấu trừ 5% phí sàn.  

Lịch sử biến động số dư được lưu vết tại bảng transactions.  

An toàn dữ liệu: Model Frontend sử dụng giải thuật tryParse và kiểm tra kiểu dữ liệu (is String/List) để ngăn chặn lỗi xung đột định dạng JSON từ API.

6. THÔNG TIN TÀI KHOẢN KIỂM THỬ (DEMO)

Admin: thanhvatli0311@gmail.com / Mật khẩu: 12345678

Shop: shop@gmail.com / Mật khẩu: 12345678

Customer: khach1@gmail.com / Mật khẩu: 12345678
