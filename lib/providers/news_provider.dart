// 📂 lib/providers/news_provider.dart

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/models/news_model.dart';
import '../data/repositories/api_service.dart';

class NewsProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<NewsPostModel> _posts = [];
  List<NewsPostModel> _managementPosts = [];
  bool _isLoading = false;
  bool _isProcessingLike = false;

  List<NewsPostModel> get posts => _posts;
  List<NewsPostModel> get managementPosts => _managementPosts;
  bool get isLoading => _isLoading;

  /// ✅ HÀM MỚI: Xóa trạng thái khi đăng xuất (Tránh lỗi lưu "tim" người cũ)
  void clearState() {
    _posts = [];
    _managementPosts = [];
    _isLoading = false;
    _isProcessingLike = false;
    notifyListeners();
  }

  /// 1. Tải bảng tin công khai
  Future<void> fetchNews({String? token, bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      // ✅ Truyền token vào đây để Server biết "ai" đang xem tin
      final res = await _apiService.getNewsFeed(token: token);

      if (res.data['success'] == true) {
        final List rawList = res.data['data']['data'];
        _posts = rawList.map((e) => NewsPostModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp bảng tin: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Thả tim - Xử lý Optimistic UI (Đã sửa tên hàm và đồng bộ data)
  Future<void> toggleLike(String token, int postId) async {
    if (_isProcessingLike) return;

    final index = _posts.indexWhere((p) => p.id == postId);
    if (index == -1) return;

    _isProcessingLike = true;
    final post = _posts[index];

    // ✅ BƯỚC 1: CẬP NHẬT GIAO DIỆN LẬP TỨC (Optimistic)
    post.isLiked = !post.isLiked;
    post.isLiked ? post.likesCount++ : post.likesCount--;
    notifyListeners(); // Người dùng thấy tim đỏ và số nhảy ngay trên Redmi Note 12

    try {
      // ✅ BƯỚC 2: GỌI API (Đúng tên hàm likeNews)
      final res = await _apiService.likeNews(postId, token);

      if (res.data['success'] == true) {
        // ✅ BƯỚC 3: ĐỒNG BỘ DỮ LIỆU THỰC TẾ TỪ SERVER
        // Backend trả về likes_count và is_liked chính xác 100%
        post.likesCount = res.data['likes_count'];
        post.isLiked = res.data['is_liked'];
        notifyListeners();
      }
    } catch (e) {
      // 🛑 HOÀN TÁC: Nếu lỗi mạng thì trả lại trạng thái cũ
      post.isLiked = !post.isLiked;
      post.isLiked ? post.likesCount++ : post.likesCount--;
      notifyListeners();
      Fluttertoast.showToast(msg: "Lỗi kết nối khi thả tim!");
    } finally {
      _isProcessingLike = false;
    }
  }

  /// 3. Bình luận bài viết
  Future<bool> sendComment(String token, int postId, String content, {int? parentId}) async {
    try {
      final res = await _apiService.sendComment(postId, content, token, parentId: parentId);

      if (res.data is! Map) return false;

      if (res.data['success'] == true) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) _posts[index].commentsCount++;
        // Tải lại thầm lặng để cập nhật danh sách bình luận mới nhất
        await fetchNews(isSilent: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 4. Sửa bài viết (Đồng bộ sau khi cập nhật thành công)
  Future<bool> updateNewsPost({
    required int id,
    required String title,
    required String content,
    required List<String> imagePaths,
    required String token,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.updateNewsWithImages(
        id: id, title: title, content: content, imagePaths: imagePaths, token: token,
      );

      if (res.data['success'] == true) {
        await fetchNews(isSilent: true); // Làm mới bảng tin công khai
        await fetchManagementNews(token); // Làm mới bảng tin quản lý
        return true;
      }
    } catch (_) {
      Fluttertoast.showToast(msg: "Cập nhật bài viết thất bại");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // --- CÁC HÀM QUẢN LÝ KHÁC GIỮ NGUYÊN ---
  Future<void> fetchManagementNews(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _apiService.getNewsManagement(token);
      _managementPosts = data.map((e) => NewsPostModel.fromJson(e)).toList();
    } catch (_) {} finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteNewsPost(int postId, String token) async {
    try {
      final res = await _apiService.deleteNews(postId, token);
      if (res.data['success'] == true) {
        _managementPosts.removeWhere((p) => p.id == postId);
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        Fluttertoast.showToast(msg: "Đã xóa bài viết");
      }
    } catch (_) {}
  }
}