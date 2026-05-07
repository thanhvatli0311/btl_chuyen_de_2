import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
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
      final res = await _apiService.getNewsFeed(token: token);

      if (res.data is Map && res.data['success'] == true) {
        final List rawList = res.data['data']['data'] ?? [];
        _posts = rawList.map((e) => NewsPostModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp bảng tin: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 2. Thả tim - Xử lý Optimistic UI Toàn diện
  Future<void> toggleLike(String token, int postId) async {
    if (_isProcessingLike) return;

    final postIndex = _posts.indexWhere((p) => p.id == postId);
    final manageIndex = _managementPosts.indexWhere((p) => p.id == postId);

    if (postIndex == -1 && manageIndex == -1) return;

    _isProcessingLike = true;

    void updateLocal(int pIdx, int mIdx, {bool? forceLiked, int? forceCount}) {
      if (pIdx != -1) {
        if (forceLiked != null) {
          _posts[pIdx].isLiked = forceLiked;
          _posts[pIdx].likesCount = forceCount!;
        } else {
          _posts[pIdx].isLiked = !_posts[pIdx].isLiked;
          _posts[pIdx].isLiked ? _posts[pIdx].likesCount++ : _posts[pIdx].likesCount--;
        }
      }
      if (mIdx != -1) {
        if (forceLiked != null) {
          _managementPosts[mIdx].isLiked = forceLiked;
          _managementPosts[mIdx].likesCount = forceCount!;
        } else {
          _managementPosts[mIdx].isLiked = !_managementPosts[mIdx].isLiked;
          _managementPosts[mIdx].isLiked ? _managementPosts[mIdx].likesCount++ : _managementPosts[mIdx].likesCount--;
        }
      }
      notifyListeners();
    }

    updateLocal(postIndex, manageIndex);

    try {
      final res = await _apiService.likeNews(postId, token);

      if (res.data is Map && res.data['success'] == true) {
        updateLocal(
            postIndex,
            manageIndex,
            forceLiked: res.data['is_liked'],
            forceCount: res.data['likes_count']
        );
      }
    } catch (e) {
      // 🛑 HOÀN TÁC: Trả lại trạng thái cũ nếu lỗi mạng
      updateLocal(postIndex, manageIndex);
      Fluttertoast.showToast(msg: "Không thể gửi tương tác!");
    } finally {
      _isProcessingLike = false;
    }
  }

  /// 3. Bình luận bài viết
  Future<bool> sendComment(String token, int postId, String content, {int? parentId}) async {
    try {
      final res = await _apiService.sendComment(postId, content, token, parentId: parentId);

      if (res.data is Map && res.data['success'] == true) {
        final index = _posts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _posts[index].commentsCount++;
          notifyListeners();
        }
        // Tải lại thầm lặng để lấy danh sách comment mới nhất
        await fetchNews(token: token, isSilent: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 4. Sửa bài viết
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

      if (res.data is Map && res.data['success'] == true) {
        await fetchNews(token: token, isSilent: true);
        await fetchManagementNews(token);
        return true;
      }
    } catch (e) {
      String errorMsg = "Cập nhật thất bại";
      if (e is DioException) errorMsg = e.response?.data['message'] ?? errorMsg;
      Fluttertoast.showToast(msg: errorMsg);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// 5. Lấy danh sách bài viết quản lý
  Future<void> fetchManagementNews(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> data = await _apiService.getNewsManagement(token);
      _managementPosts = data.map((e) => NewsPostModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint("❌ Lỗi Quản lý tin: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 6. Xóa bài viết
  Future<void> deleteNewsPost(int postId, String token) async {
    try {
      final res = await _apiService.deleteNews(postId, token);
      if (res.data is Map && res.data['success'] == true) {
        _managementPosts.removeWhere((p) => p.id == postId);
        _posts.removeWhere((p) => p.id == postId);
        notifyListeners();
        Fluttertoast.showToast(msg: "Đã xóa bài viết thành công");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Không thể xóa bài viết này");
    }
  }
}