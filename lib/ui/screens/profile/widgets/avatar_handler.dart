import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../../../providers/base_provider.dart';
import '../../../../data/repositories/api_service.dart';
import '../../../../core/utils/image_helper.dart';

class AvatarHandler extends StatefulWidget {
  final dynamic user;
  final double px;

  const AvatarHandler({super.key, required this.user, required this.px});

  @override
  State<AvatarHandler> createState() => _AvatarHandlerState();
}

class _AvatarHandlerState extends State<AvatarHandler> {
  /// Khởi tạo công cụ chọn ảnh duy nhất cho State để tối ưu bộ nhớ.
  final ImagePicker _picker = ImagePicker();

  /// Biến trạng thái để theo dõi quá trình đang tải ảnh lên server.
  bool _isUpdating = false;

  /// Chức năng: Cho phép người dùng chọn ảnh từ thư viện và thực hiện tải lên máy chủ để cập nhật ảnh đại diện.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _pickAndUploadAvatar() async {
    /// Kiểm tra nếu đang trong quá trình cập nhật thì không cho phép thực hiện tiếp.
    if (_isUpdating) return;

    /// Mở thư viện ảnh trên điện thoại với chất lượng nén 70% để tiết kiệm băng thông.
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    /// Nếu người dùng hủy chọn ảnh hoặc Widget đã bị gỡ khỏi cây thư mục thì dừng lại.
    if (img == null || !mounted) return;

    setState(() => _isUpdating = true);

    final baseProvider = context.read<BaseProvider>();

    try {
      /// Gọi API cập nhật hồ sơ với tệp ảnh vừa chọn.
      final res = await baseProvider.apiService.updateProfileWithImages(
        data: {},
        thumbnailPath: img.path,
        token: baseProvider.token!,
      );

      if (res.data != null && res.data['success'] == true) {
        /// Xử lý xóa ảnh cũ khỏi bộ nhớ đệm (Cache) để hiển thị ảnh mới ngay lập tức.
        if (widget.user?.avatar != null) {
          final oldUrl = ImageHelper.buildImageUrl(widget.user!.avatar);
          await CachedNetworkImage.evictFromCache(oldUrl);
        }

        Fluttertoast.showToast(msg: "Cập nhật ảnh thành công!");

        /// Nạp lại thông tin cá nhân mới nhất sau khi đổi ảnh thành công.
        if (mounted) {
          await baseProvider.getProfile();
        }
      } else {
        Fluttertoast.showToast(msg: "Cập nhật thất bại từ máy chủ");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối: Không thể tải ảnh lên");
    } finally {
      /// Đảm bảo tắt trạng thái cập nhật sau khi hoàn tất tác vụ.
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Chức năng: Hiển thị một hộp thoại phóng to ảnh đại diện hiện tại kèm tùy chọn thay đổi ảnh.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có (Hiển thị UI Dialog).
  void _showAvatarViewer() {
    final String? avatar = widget.user?.avatar;
    final bool hasAvatar = avatar != null && avatar.isNotEmpty;

    showDialog(
      context: context,
      /// Làm mờ nền phía sau với độ trong suốt cao để làm nổi bật ảnh.
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// Hiển thị ảnh hiện tại hoặc Icon mặc định nếu chưa có ảnh.
            hasAvatar
                ? ImageHelper.load(
              avatar!,
              fit: BoxFit.contain,
              borderRadius: 20,
            )
                : Icon(Icons.person, size: 150 + widget.px, color: Colors.white),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Đóng", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 20),
                /// Nút bấm kích hoạt lại luồng chọn và tải ảnh mới.
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar();
                  },
                  icon: const Icon(Icons.photo_camera),
                  label: const Text("Đổi ảnh mới"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0047AB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? avatarPath = widget.user?.avatar;
    final bool hasAvatar = avatarPath != null && avatarPath.isNotEmpty;

    /// Tính toán kích thước các thành phần dựa trên độ lệch cỡ chữ của người dùng.
    final double avatarRadius = 45 + widget.px;
    final double iconSize = 45 + widget.px;
    final double imgSize = 90 + (widget.px * 2);

    return Stack(
      alignment: Alignment.center,
      children: [
        GestureDetector(
          /// Chặn tương tác nếu đang trong quá trình tải ảnh lên.
          onTap: _isUpdating ? null : _showAvatarViewer,
          child: CircleAvatar(
            radius: avatarRadius,
            backgroundColor: const Color(0xFF0047AB).withValues(alpha: 0.1),
            child: hasAvatar
                ? ImageHelper.load(
              avatarPath!,
              borderRadius: 100,
              width: imgSize,
              height: imgSize,
            )
                : Icon(
              Icons.person,
              size: iconSize,
              color: const Color(0xFF0047AB),
            ),
          ),
        ),

        /// Hiển thị lớp phủ mờ và vòng xoay tiến trình khi đang upload.
        if (_isUpdating)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}