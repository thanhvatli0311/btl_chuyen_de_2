import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../network/api_config.dart';

/// Lớp hỗ trợ xử lý và hiển thị hình ảnh từ môi trường mạng
class ImageHelper {

  /// Chức năng: Xây dựng đường dẫn (URL) hoàn chỉnh cho hình ảnh từ dữ liệu thô
  /// Tham số đầu vào: path - Chuỗi đường dẫn tương đối hoặc tuyệt đối của ảnh
  /// Giá trị trả về: Chuỗi URL đầy đủ dẫn tới tệp tin hình ảnh
  static String buildImageUrl(String? path) {
    /// Kiểm tra nếu dữ liệu đường dẫn trống hoặc không tồn tại
    if (path == null || path.isEmpty) {
      /// Trả về ảnh mặc định nếu không có dữ liệu đầu vào
      return "https://via.placeholder.com/150";
    }

    /// Kiểm tra nếu đường dẫn đã là một liên kết web đầy đủ
    if (path.startsWith('http')) return path;

    /// Loại bỏ ký tự gạch chéo ở đầu đường dẫn tương đối để chuẩn hóa
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;

    /// Lấy cấu hình tên miền từ hệ thống và loại bỏ ký tự gạch chéo thừa ở cuối
    String domain = ApiConfig.domainUrl;
    if (domain.endsWith('/')) {
      domain = domain.substring(0, domain.length - 1);
    }

    /// Ghép nối các thành phần thành URL hoàn chỉnh theo cấu trúc Laravel Storage
    /// Đính kèm dấu thời gian (timestamp) vào cuối URL để yêu cầu ứng dụng luôn tải lại ảnh mới
    final finalUrl = "$domain/storage/$cleanPath?v=${DateTime.now().millisecondsSinceEpoch}";

    return finalUrl;
  }

  /// Chức năng: Hiển thị hình ảnh từ Internet với tính năng lưu vào bộ nhớ đệm (Cache)
  /// Tham số đầu vào: path (đường dẫn ảnh), width (chiều rộng), height (chiều cao), fit (kiểu hiển thị), borderRadius (độ bo góc)
  /// Giá trị trả về: Một Widget hiển thị hình ảnh đã được xử lý bo góc và tải mạng
  static Widget load(
      String? path, {
        double? width,
        double? height,
        BoxFit fit = BoxFit.cover,
        double borderRadius = 0,
      }) {
    return ClipRRect(
      /// Áp dụng độ bo góc cho hình ảnh dựa trên tham số truyền vào
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        /// Chuyển đổi đường dẫn thô thành URL chuẩn trước khi tải
        imageUrl: buildImageUrl(path),
        width: width,
        height: height,
        fit: fit,
        /// Tối ưu kích thước bộ nhớ đệm để đảm bảo độ sắc nét của hình ảnh
        memCacheWidth: 800,

        /// Yêu cầu không sử dụng lại ảnh cũ khi địa chỉ URL có sự thay đổi
        useOldImageOnUrlChange: false,

        /// Hiển thị hiệu ứng chờ khi hình ảnh đang trong quá trình tải về
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: (Colors.grey[200] ?? Colors.grey).withValues(alpha: 0.5),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0047AB),
              ),
            ),
          ),
        ),

        /// Hiển thị biểu tượng lỗi khi không thể truy cập hình ảnh hoặc lỗi mạng
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: (Colors.grey[100] ?? Colors.grey),
          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}