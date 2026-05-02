import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/network/api_config.dart';
import '../models/address_model.dart';
import '../models/category_brand_model.dart';
import '../models/order_model.dart';
import '../models/phone_model.dart';

/// Lớp ApiService chịu trách nhiệm quản lý toàn bộ các yêu cầu gửi lên máy chủ (API) của ứng dụng.
class ApiService {
  late Dio _dio;

  /// Hàm khởi tạo lớp ApiService, thiết lập cấu hình mặc định cho các kết nối mạng.
  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      responseType: ResponseType.json,
      contentType: 'application/json',
      validateStatus: (status) => status! < 500,
    ));

    /// Thiết lập bộ lọc Interceptor để quản lý các giai đoạn của yêu cầu: gửi đi, nhận về và xử lý lỗi.
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) => handler.next(options),
      onResponse: (response, handler) => handler.next(response),
      onError: (DioException e, handler) => handler.next(e),
    ));
  }

  /// Hàm hỗ trợ tạo cấu hình xác thực (Token) và định dạng dữ liệu cho yêu cầu.
  /// Tham số: token - Mã định danh người dùng; isMultipart - Xác định có gửi kèm tệp tin hay không.
  /// Trả về: Đối tượng Options chứa Header và ContentType.
  Options _auth(String? token, {bool isMultipart = false}) => Options(
    headers: {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token'
    },
    contentType: isMultipart ? 'multipart/form-data' : 'application/json',
  );

  /// Hàm xử lý đăng nhập người dùng.
  /// Tham số: email, password của tài khoản.
  /// Trả về: Response chứa thông tin đăng nhập và mã Token.
  Future<Response> login(String email, String password) =>
      _dio.post('/login', data: {'email': email, 'password': password});

  /// Hàm đăng ký tài khoản mới.
  /// Tham số: data - Bản đồ chứa thông tin cá nhân của người dùng.
  /// Trả về: Response xác nhận việc đăng ký.
  Future<Response> register(Map<String, dynamic> data) =>
      _dio.post('/register', data: data);

  /// Hàm đăng xuất khỏi hệ thống.
  /// Tham số: token - Mã định danh để máy chủ hủy phiên làm việc.
  /// Trả về: Response xác nhận đăng xuất.
  Future<Response> logout(String token) =>
      _dio.post('/logout', options: _auth(token));

  /// Hàm yêu cầu gửi mã OTP về email để xác thực hoặc lấy lại mật khẩu.
  /// Tham số: email nhận mã.
  /// Trả về: Toàn bộ dữ liệu phản hồi từ máy chủ.
  Future<Response> sendOtp(String email) async {
    final res = await _dio.post('/send-otp', data: {'email': email});
    return res.data;
  }

  /// Hàm xác minh mã OTP người dùng đã nhập.
  /// Tham số: email và mã otp_code.
  /// Trả về: Response kết quả xác minh.
  Future<Response> verifyOtp(String email, String otp) => _dio.post('/verify-otp', data: {
    'email': email,
    'otp_code': otp,
  });

  /// Hàm thiết lập lại mật khẩu mới.
  /// Tham số: data - Chứa mật khẩu mới và mã xác thực.
  /// Trả về: Bản đồ chứa kết quả thực hiện.
  Future<Map<String, dynamic>> resetPassword(Map<String, dynamic> data) async {
    final res = await _dio.post('/password/reset', data: data);
    return res.data;
  }

  /// Hàm lấy thông tin chi tiết cá nhân của người dùng hiện tại.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa dữ liệu Profile.
  Future<Response> getProfile(String token) async =>
      await _dio.get('/user/profile', options: _auth(token));

  /// Hàm cập nhật thông tin cá nhân kèm theo việc thay đổi ảnh đại diện.
  /// Tham số: data - Thông tin văn bản; thumbnailPath - Đường dẫn tệp ảnh; token xác thực.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updateProfileWithImages({
    required Map<String, dynamic> data,
    String? thumbnailPath,
    required String token,
  }) async {
    /// Chuyển đổi dữ liệu sang FormData để có thể gửi kèm tệp tin hình ảnh.
    FormData formData = FormData.fromMap(data);

    /// Kiểm tra nếu có ảnh mới thì mới thực hiện đính kèm tệp vào yêu cầu.
    if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
      formData.files.add(MapEntry(
        'avatar',
        await MultipartFile.fromFile(thumbnailPath, filename: 'avatar.jpg'),
      ));
    }

    /// Laravel yêu cầu sử dụng method spoofing '_method: PUT' khi gửi dữ liệu Multipart qua POST.
    formData.fields.add(const MapEntry('_method', 'PUT'));

    return await _dio.post(
      '/user/profile',
      data: formData,
      options: _auth(token, isMultipart: true),
    );
  }

  /// Hàm truy vấn danh sách điện thoại đang bán với các tiêu chí lọc.
  /// Tham số: query - Từ khóa tìm kiếm; brandId - Hãng; minRam - Cấu hình; sortBy - Cách sắp xếp.
  /// Trả về: Danh sách các đối tượng PhoneModel.
  Future<List<PhoneModel>> getPhones({String? query, int? brandId, int? minRam, String? sortBy}) async {
    try {
      /// Truyền các tham số lọc vào queryParameters để máy chủ xử lý tìm kiếm.
      final response = await _dio.get('/phones', queryParameters: {
        if (query != null && query.isNotEmpty) 'search': query,
        if (brandId != null) 'brand_id': brandId,
        if (minRam != null) 'min_ram': minRam,
        if (sortBy != null) 'sort_by': sortBy,
      });

      if (response.statusCode == 200) {
        final List rawData = response.data['data'];
        /// Ánh xạ dữ liệu JSON nhận được thành danh sách mô hình dữ liệu Dart.
        return rawData.map((json) => PhoneModel.fromJson(json)).toList();
      }
    } catch (e) { debugPrint("Lỗi lấy danh sách máy: $e"); }
    return [];
  }

  /// Hàm lấy thông tin chi tiết của một chiếc điện thoại dựa trên đường dẫn tĩnh (slug).
  /// Tham số: slug định danh.
  /// Trả về: Đối tượng PhoneModel hoặc null nếu không tìm thấy.
  Future<PhoneModel?> getPhoneDetail(String slug) async {
    try {
      final res = await _dio.get('/phones/$slug');
      if (res.statusCode == 200 && res.data['success'] == true) {
        return PhoneModel.fromJson(res.data['data']);
      }
    } catch (e) { debugPrint("Lỗi nạp chi tiết: $e"); }
    return null;
  }

  /// Hàm đăng bán sản phẩm mới bao gồm mô tả văn bản và nhiều hình ảnh minh họa.
  /// Tham số: data - Thông tin máy; thumbnailPath - Ảnh chính; subImagePaths - Danh sách ảnh phụ; token xác thực.
  /// Trả về: Response xác nhận đăng bán.
  Future<Response> storePhoneWithImages({
    required Map<String, dynamic> data,
    required String thumbnailPath,
    required List<String> subImagePaths,
    required String token,
  }) async {
    /// Khởi tạo FormData và thêm ảnh đại diện chính của sản phẩm.
    FormData formData = FormData.fromMap({
      ...data,
      'thumbnail': await MultipartFile.fromFile(thumbnailPath, filename: 'main.jpg'),
    });

    /// Vòng lặp đính kèm tất cả các ảnh phụ vào mảng 'images[]'.
    for (var path in subImagePaths) {
      formData.files.add(MapEntry('images[]', await MultipartFile.fromFile(path, filename: 'sub.jpg')));
    }
    return await _dio.post('/shop/phones', data: formData, options: _auth(token, isMultipart: true));
  }

  /// Hàm cập nhật thông tin máy đã đăng, xử lý thông minh để chỉ gửi ảnh mới nếu có thay đổi.
  /// Tham số: id máy; data - Thông tin; thumbnailPath - Ảnh đại diện; subImagePaths - Ảnh phụ; token xác thực.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updatePhoneWithImages({
    required int id,
    required Map<String, dynamic> data,
    String? thumbnailPath,
    List<String>? subImagePaths,
    required String token,
  }) async {
    Map<String, dynamic> payload = Map<String, dynamic>.from(data);
    /// Giả lập phương thức PUT để Laravel có thể nhận diện yêu cầu cập nhật.
    payload['_method'] = 'PUT';

    /// Chỉ đính kèm tệp nếu người dùng chọn ảnh mới từ thiết bị (không bắt đầu bằng http).
    if (thumbnailPath != null && !thumbnailPath.startsWith('http')) {
      payload['thumbnail'] = await MultipartFile.fromFile(thumbnailPath, filename: 'thumb.jpg');
    }

    FormData formData = FormData.fromMap(payload);

    /// Xử lý danh sách ảnh phụ, chỉ tải lên những tệp tin nằm ở bộ nhớ máy.
    if (subImagePaths != null && subImagePaths.isNotEmpty) {
      if (subImagePaths.any((p) => !p.startsWith('http'))) {
        for (var path in subImagePaths) {
          if (!path.startsWith('http')) {
            formData.files.add(MapEntry('images[]', await MultipartFile.fromFile(path, filename: 'sub.jpg')));
          }
        }
      }
    }
    return await _dio.post('/shop/phones/$id', data: formData, options: _auth(token, isMultipart: true));
  }

  /// Hàm điều chỉnh giá khuyến mãi cho một sản phẩm.
  /// Tham số: id máy; discountPrice - Giá giảm; token xác thực.
  /// Trả về: Response kết quả chỉnh sửa.
  Future<Response> updatePhoneDiscount(int id, double? discountPrice, String token) =>
      _dio.patch('/shop/phones/$id/discount', data: {'discount_price': discountPrice}, options: _auth(token));

  /// Hàm gỡ bỏ một sản phẩm khỏi hệ thống.
  /// Tham số: id máy; token xác thực.
  /// Trả về: Response xác nhận đã xóa.
  Future<Response> deletePhone(int id, String token) =>
      _dio.delete('/shop/phones/$id', options: _auth(token));

  /// Hàm lấy danh sách toàn bộ sản phẩm đang quản lý của một cửa hàng (Shop).
  /// Tham số: token xác thực.
  /// Trả về: Danh sách PhoneModel thuộc quyền sở hữu của Shop.
  Future<List<PhoneModel>> getMyShopPhones(String token) async {
    try {
      final res = await _dio.get('/shop/phones', options: _auth(token));
      if (res.data['success'] == true) {
        final List rawData = res.data['data'];
        return rawData.map((e) => PhoneModel.fromJson(e)).toList();
      }
    } catch (e) { debugPrint("ApiService Error: $e"); }
    return [];
  }

  /// Hàm lấy số liệu thống kê kinh doanh của Shop theo khoảng thời gian.
  /// Tham số: token xác thực; start và end - Ngày bắt đầu/kết thúc.
  /// Trả về: Response chứa số liệu thống kê.
  Future<Response> getRevenueStats(String token, {String? start, String? end}) =>
      _dio.get('/shop/revenue-stats', queryParameters: {
        if (start != null) 'start_date': start,
        if (end != null) 'end_date': end,
      }, options: _auth(token));

  /// Hàm lấy danh sách các đơn hàng của cửa hàng.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa danh sách đơn hàng.
  Future<Response> getShopOrders(String token) =>
      _dio.get('/shop/orders', options: _auth(token));

  /// Hàm thay đổi trạng thái đơn hàng (Duyệt đơn, Đang giao...).
  /// Tham số: orderId; status mới; token xác thực.
  /// Trả về: Response kết quả cập nhật trạng thái.
  Future<Response> updateOrderStatus({required int orderId, required String status, required String token}) =>
      _dio.put('/shop/orders/$orderId/status', data: {'status': status}, options: _auth(token));

  /// Hàm lấy lịch sử các giao dịch tài chính liên quan đến doanh thu của Shop.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa danh sách giao dịch.
  Future<Response> getRevenueTransactions(String token) =>
      _dio.get('/shop/transactions', options: _auth(token));

  /// Hàm gửi yêu cầu rút tiền từ ví của Shop về tài khoản ngân hàng.
  /// Tham số: data - Thông tin rút tiền; token xác thực.
  /// Trả về: Response xác nhận yêu cầu.
  Future<Response> requestWithdraw(Map<String, dynamic> data, String token) =>
      _dio.post('/shop/withdraw-requests', data: data, options: _auth(token));

  /// Hàm xem lại lịch sử các lệnh rút tiền đã thực hiện của Shop.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa danh sách lệnh rút.
  Future<Response> getShopWithdrawHistory(String token) =>
      _dio.get('/shop/withdraw-requests', options: _auth(token));

  /// Hàm gửi yêu cầu đăng ký mở cửa hàng mới lên sàn.
  /// Tham số: token xác thực; shopName - Tên shop; address - Địa chỉ kho hàng.
  /// Trả về: Response kết quả gửi đơn đăng ký.
  Future<Response> registerShopRequest({required String token, required String shopName, required String address}) =>
      _dio.post('/shop/register-request', data: {'name': shopName, 'warehouse_address': address}, options: _auth(token));

  /// Hàm lấy danh sách toàn bộ các hãng điện thoại có trên hệ thống.
  /// Trả về: Danh sách BrandModel.
  Future<List<BrandModel>> getBrands() async {
    try {
      final res = await _dio.get('/brands');
      if (res.statusCode == 200) {
        final List rawData = res.data['data'];
        return rawData.map((e) => BrandModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Hàm lấy danh sách các loại danh mục máy (Điện thoại cũ, mới...).
  /// Trả về: Danh sách CategoryModel.
  Future<List<CategoryModel>> getCategories() async {
    try {
      final res = await _dio.get('/categories');
      if (res.statusCode == 200) {
        final List rawData = res.data['data'];
        return rawData.map((e) => CategoryModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Hàm thêm mới một thương hiệu điện thoại.
  /// Tham số: name của hãng; token xác thực quyền admin/shop.
  /// Trả về: Response kết quả lưu.
  Future<Response> storeBrand(String name, String token) =>
      _dio.post('/shop/brands', data: {'name': name}, options: _auth(token));

  /// Hàm sửa tên thương hiệu điện thoại.
  /// Tham số: id hãng; name mới; token xác thực.
  /// Trả về: Response kết quả sửa.
  Future<Response> updateBrand(int id, String name, String token) =>
      _dio.put('/shop/brands/$id', data: {'name': name}, options: _auth(token));

  /// Hàm xóa một thương hiệu khỏi danh sách.
  /// Tham số: id hãng; token xác thực.
  /// Trả về: Response xác nhận đã xóa.
  Future<Response> deleteBrand(int id, String token) =>
      _dio.delete('/shop/brands/$id', options: _auth(token));

  /// Hàm truy cập giỏ hàng của người mua.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa danh sách sản phẩm trong giỏ.
  Future<Response> getCart(String token) => _dio.get('/customer/cart', options: _auth(token));

  /// Hàm thêm một sản phẩm vào giỏ hàng cá nhân.
  /// Tham số: phoneId - ID máy; quantity - Số lượng; token xác thực.
  /// Trả về: Response kết quả thêm.
  Future<Response> addToCart({required int phoneId, required int quantity, required String token}) =>
      _dio.post('/customer/cart', data: {'phone_id': phoneId, 'quantity': quantity}, options: _auth(token));

  /// Hàm cập nhật số lượng của một sản phẩm đang nằm trong giỏ hàng.
  /// Tham số: cartId - ID dòng giỏ hàng; quantity mới; token xác thực.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updateCartQuantity(int cartId, int quantity, String token) =>
      _dio.post('/customer/cart/$cartId', data: {'quantity': quantity, '_method': 'PUT'}, options: _auth(token));

  /// Hàm loại bỏ một sản phẩm khỏi giỏ hàng.
  /// Tham số: cartId; token xác thực.
  /// Trả về: Response kết quả xóa.
  Future<Response> removeFromCart(int cartId, String token) =>
      _dio.delete('/customer/cart/$cartId', options: _auth(token));

  /// Hàm tiến hành đặt hàng từ các sản phẩm đã chọn trong giỏ hàng.
  /// Tham số: token xác thực; data - Thông tin giao hàng và thanh toán.
  /// Trả về: Response xác nhận đơn hàng thành công.
  Future<Response> checkout({required String token, required Map<String, dynamic> data}) =>
      _dio.post('/customer/orders/checkout', data: data, options: _auth(token));

  /// Hàm lấy lịch sử các đơn hàng đã đặt của người mua.
  /// Tham số: token xác thực; status - Trạng thái đơn muốn xem (mặc định là 'all').
  /// Trả về: Danh sách OrderModel.
  Future<List<OrderModel>> getCustomerOrders(String token, {String status = 'all'}) async {
    try {
      final response = await _dio.get('/customer/orders', queryParameters: {'status': status}, options: _auth(token));
      if (response.data['success'] == true) {
        List rawList = response.data['data'] as List;
        return rawList.map((json) => OrderModel.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Hàm gửi yêu cầu hủy đơn hàng.
  /// Tham số: token xác thực; orderId; reason - Lý do hủy.
  /// Trả về: Bản đồ chứa trạng thái thành công và thông báo.
  Future<Map<String, dynamic>> cancelOrder(String token, int orderId, {String? reason}) async {
    try {
      final res = await _dio.post('/customer/orders/$orderId/cancel', data: {'reason': reason}, options: _auth(token));
      return res.data;
    } catch (e) { return {'success': false, 'message': e.toString()}; }
  }

  /// Hàm lấy danh sách các địa chỉ nhận hàng đã lưu của người dùng.
  /// Tham số: token xác thực.
  /// Trả về: Danh sách AddressModel.
  Future<List<AddressModel>> getAddresses(String token) async {
    try {
      final res = await _dio.get('/customer/addresses', options: _auth(token));
      return (res.data['data'] as List).map((e) => AddressModel.fromJson(e)).toList();
    } catch (_) { return []; }
  }

  /// Hàm thêm mới địa chỉ nhận hàng.
  /// Tham số: token xác thực; data - Chi tiết địa chỉ.
  /// Trả về: Response kết quả lưu.
  Future<Response> storeAddress(String token, Map<String, dynamic> data) =>
      _dio.post('/customer/addresses', data: data, options: _auth(token));

  /// Hàm cập nhật thông tin một địa chỉ đã có.
  /// Tham số: token xác thực; id địa chỉ; data - Thông tin mới.
  /// Trả về: Response kết quả sửa.
  Future<Response> updateAddress(String token, int id, Map<String, dynamic> data) =>
      _dio.put('/customer/addresses/$id', data: data, options: _auth(token));

  /// Hàm xóa bỏ vĩnh viễn một địa chỉ khỏi danh sách.
  /// Tham số: token xác thực; id địa chỉ.
  /// Trả về: Response kết quả xóa.
  Future<Response> deleteAddress(String token, int id) =>
      _dio.delete('/customer/addresses/$id', options: _auth(token));

  /// Hàm lấy danh sách các thông báo hệ thống gửi cho người dùng.
  /// Tham số: token xác thực.
  /// Trả về: Response chứa danh sách thông báo.
  Future<Response> getNotifications(String token) =>
      _dio.get('/customer/notifications', options: _auth(token));

  /// Hàm đánh dấu một thông báo cụ thể là đã xem.
  /// Tham số: token xác thực; id thông báo.
  /// Trả về: Response kết quả thực hiện.
  Future<Response> markNotificationRead(String token, int id) =>
      _dio.put('/customer/notifications/$id/mark-read', options: _auth(token));

  /// Hàm xóa một thông báo.
  /// Tham số: token xác thực; id thông báo.
  /// Trả về: Response kết quả xóa.
  Future<Response> deleteNotification(String token, int id) =>
      _dio.delete('/customer/notifications/$id', options: _auth(token));

  /// Hàm lấy danh sách tin tức/bài đăng cộng đồng.
  /// Tham số: token - Không bắt buộc, dùng để kiểm tra trạng thái Like của người xem.
  /// Trả về: Response chứa danh sách bài đăng.
  Future<Response> getNewsFeed({String? token}) async {
    return await _dio.get(
        '/news',
        options: _auth(token)
    );
  }

  /// Hàm lấy nội dung chi tiết của một bài đăng tin tức.
  /// Tham số: id bài viết.
  /// Trả về: Bản đồ chứa dữ liệu chi tiết bài đăng.
  Future<Map<String, dynamic>> getNewsDetail(int id) async {
    final res = await _dio.get('/news/$id');
    return res.data;
  }

  /// Hàm đăng một bản tin mới đính kèm nhiều hình ảnh minh họa.
  /// Tham số: title, content của bài viết; imagePaths - Danh sách đường dẫn ảnh; token xác thực.
  /// Trả về: Response kết quả đăng bài.
  Future<Response> storeNewsWithImages({required String title, required String content, required List<String> imagePaths, required String token}) async {
    FormData formData = FormData.fromMap({'title': title, 'content': content});
    /// Đưa từng tệp tin ảnh vào mảng 'news_images[]' để gửi lên máy chủ.
    for (String path in imagePaths) {
      formData.files.add(MapEntry('news_images[]', await MultipartFile.fromFile(path)));
    }
    return _dio.post('/shop/news', data: formData, options: _auth(token, isMultipart: true));
  }

  /// Hàm cập nhật nội dung bài đăng tin tức, lọc bỏ ảnh cũ và thêm ảnh mới.
  /// Tham số: id bài viết; title, content; imagePaths - Danh sách ảnh; token xác thực.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updateNewsWithImages({required int id, required String title, required String content, required List<String> imagePaths, required String token}) async {
    Map<String, dynamic> data = {'title': title, 'content': content, '_method': 'PUT'};
    FormData formData = FormData.fromMap(data);
    /// Chỉ tải lên những hình ảnh mới chọn từ máy (không phải ảnh lấy từ link internet).
    for (String path in imagePaths) {
      if (!path.startsWith('http')) {
        formData.files.add(MapEntry('news_images[]', await MultipartFile.fromFile(path)));
      }
    }
    return await _dio.post('/shop/news/$id', data: formData, options: _auth(token, isMultipart: true));
  }

  /// Hàm lấy danh sách các bản tin thuộc quản lý của Shop (để chỉnh sửa/xóa).
  /// Tham số: token xác thực.
  /// Trả về: Danh sách các đối tượng dữ liệu dạng động.
  Future<List<dynamic>> getNewsManagement(String token) async {
    try {
      final res = await _dio.get('/shop/news-management', options: _auth(token));
      if (res.data is Map) return res.data['data'] ?? [];
    } catch (_) {}
    return [];
  }

  /// Hàm xóa bài đăng tin tức.
  /// Tham số: id bài viết; token xác thực quyền sở hữu.
  /// Trả về: Response kết quả xóa.
  Future<Response> deleteNews(int id, String token) =>
      _dio.delete('/news/$id', options: _auth(token));

  /// Hàm thực hiện hành động Thích (Like) hoặc Bỏ thích một bài viết.
  /// Tham số: id bài viết; token xác thực người dùng.
  /// Trả về: Response chứa trạng thái like mới và tổng số lượt like.
  Future<Response> likeNews(int id, String token) async {
    return await _dio.post(
        '/news/$id/like',
        options: _auth(token)
    );
  }

  /// Hàm gửi một bình luận mới vào bài viết hoặc trả lời bình luận khác.
  /// Tham số: postId - Bài viết; content - Nội dung; token; parentId - ID bình luận cha (nếu là phản hồi).
  /// Trả về: Response chứa thông tin bình luận vừa tạo.
  Future<Response> sendComment(int postId, String content, String token, {int? parentId}) =>
      _dio.post('/news/$postId/comments', data: {'content': content, 'parent_id': parentId}, options: _auth(token));

  /// Hàm gửi đánh giá và số sao cho một chiếc điện thoại.
  /// Tham số: token xác thực; phoneId; rating - Số sao; comment - Đánh giá văn bản.
  /// Trả về: Response kết quả đánh giá.
  Future<Response> submitReview({required String token, required int phoneId, required int rating, required String comment}) =>
      _dio.post('/customer/reviews', data: {'phone_id': phoneId, 'rating': rating, 'comment': comment}, options: _auth(token));

  /// Hàm lấy toàn bộ danh sách đánh giá của một sản phẩm.
  /// Tham số: phoneId - ID máy.
  /// Trả về: Response chứa danh sách các Review.
  Future<Response> getReviews(int phoneId) => _dio.get('/phones/$phoneId/reviews');

  /// Hàm lấy danh sách các cuộc hội thoại chat của người dùng.
  /// Tham số: token xác thực.
  /// Trả về: Response danh sách phòng chat.
  Future<Response> getChatList(String token) => _dio.get('/chats', options: _auth(token));

  /// Hàm lấy lịch sử tin nhắn chi tiết trong một cuộc hội thoại.
  /// Tham số: token xác thực; receiverId - ID người nhận tin nhắn.
  /// Trả về: Response danh sách tin nhắn.
  Future<Response> getMessages(String token, int receiverId) => _dio.get('/chats/$receiverId', options: _auth(token));

  /// Hàm gửi tin nhắn văn bản đến một người dùng khác.
  /// Tham số: token xác thực; toUserId - Người nhận; message - Nội dung.
  /// Trả về: Response xác nhận tin nhắn đã gửi.
  Future<Response> sendChatMessage(String token, int toUserId, String message) =>
      _dio.post('/chats/send', data: {'to_user_id': toUserId, 'message': message}, options: _auth(token));

  /// Hàm đánh dấu toàn bộ tin nhắn trong một cuộc hội thoại là đã đọc.
  /// Tham số: token xác thực; receiverId - Người gửi tin nhắn.
  /// Trả về: Response kết quả thực hiện.
  Future<Response> markChatAsRead(String token, int receiverId) => _dio.put('/chats/$receiverId/read', options: _auth(token));

  /// Hàm lấy các số liệu thống kê tổng quan của toàn bộ sàn (dành cho Admin).
  /// Tham số: token xác thực quyền quản trị.
  /// Trả về: Response chứa dữ liệu thống kê tổng quát.
  Future<Response> getAdminDashboardStats(String token) => _dio.get('/admin/dashboard-stats', options: _auth(token));

  /// Hàm lấy biểu đồ doanh thu theo ngày của toàn sàn.
  /// Tham số: token; start/end - Khoảng thời gian muốn xem.
  /// Trả về: Response dữ liệu biểu đồ.
  Future<Response> getAdminDailyRevenue(String token, {String? start, String? end}) =>
      _dio.get('/admin/daily-revenue', queryParameters: {if (start != null) 'start_date': start, if (end != null) 'end_date': end}, options: _auth(token));

  /// Hàm lấy danh sách xếp hạng các Shop có doanh thu cao nhất.
  /// Tham số: token quản trị.
  /// Trả về: Response danh sách xếp hạng.
  Future<Response> getAdminShopRankings(String token) => _dio.get('/admin/shop-rankings', options: _auth(token));

  /// Hàm xem chi tiết số liệu kinh doanh của một Shop cụ thể.
  /// Tham số: token; shopId; start/end - Thời gian lọc.
  /// Trả về: Response dữ liệu phân tích Shop.
  Future<Response> getAdminShopDetailAnalytics(String token, int shopId, String start, String end) =>
      _dio.get('/admin/shops/$shopId/analytics', queryParameters: {'start_date': start, 'end_date': end}, options: _auth(token));

  /// Hàm truy vấn danh sách toàn bộ tài khoản có trên hệ thống.
  /// Tham số: token xác thực quyền admin.
  /// Trả về: Response chứa danh sách người dùng.
  Future<Response> getAdminUsers(String token) =>
      _dio.get('/admin/users', options: _auth(token));

  /// Hàm thay đổi chức vụ hoặc khóa/mở khóa tài khoản người dùng.
  /// Tham số: token; userId; role mới; status mới.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updateUserStatus(String token, int userId, {String? role, String? status}) =>
      _dio.put('/admin/users/$userId', data: {if (role != null) 'role': role, if (status != null) 'status': status}, options: _auth(token));

  /// Hàm lấy danh sách các Shop trên sàn lọc theo trạng thái (Đã duyệt, Chưa duyệt...).
  /// Tham số: token; status lọc.
  /// Trả về: Response danh sách Shop.
  Future<Response> getAdminShops(String token, {String? status}) =>
      _dio.get('/admin/shops', queryParameters: status != null ? {'status': status} : null, options: _auth(token));

  /// Hàm thực hiện phê duyệt đơn mở cửa hàng hoặc khóa cửa hàng.
  /// Tham số: token; shopId; status muốn chuyển (approved, blocked...).
  /// Trả về: Response kết quả thay đổi.
  Future<Response> updateShopStatus(String token, int shopId, String status) =>
      _dio.put('/admin/shops/$shopId/status', data: {'status': status}, options: _auth(token));

  /// Hàm lấy danh sách các yêu cầu rút tiền đang chờ xử lý từ các Shop.
  /// Tham số: token quản trị.
  /// Trả về: Response danh sách lệnh rút.
  Future<Response> getWithdrawRequests(String token) => _dio.get('/admin/withdraw-requests', options: _auth(token));

  /// Hàm lấy danh sách rút tiền tương tự như trên (Dùng cho giao diện quản lý).
  /// Tham số: token quản trị.
  /// Trả về: Response danh sách lệnh rút.
  Future<Response> adminGetWithdrawRequests(String token) => _dio.get('/admin/withdraw-requests', options: _auth(token));

  /// Hàm thực hiện chuyển trạng thái lệnh rút tiền (Hoàn thành, Từ chối).
  /// Tham số: id lệnh; status mới; note - Ghi chú lý do; token quản trị.
  /// Trả về: Response kết quả xử lý.
  Future<Response> adminHandleWithdraw(int id, String status, String? note, String token) =>
      _dio.post('/admin/withdraw-requests/$id/handle', data: {'status': status, 'admin_note': note}, options: _auth(token));

  /// Hàm lấy các cài đặt cấu hình toàn hệ thống (Phí dịch vụ, tiền cọc...).
  /// Tham số: token quản trị.
  /// Trả về: Response danh sách các key-value cài đặt.
  Future<Response> getSystemSettings(String token) => _dio.get('/admin/settings', options: _auth(token));

  /// Hàm cập nhật giá trị cho một cài đặt hệ thống.
  /// Tham số: token; key tên cài đặt; value giá trị mới.
  /// Trả về: Response kết quả cập nhật.
  Future<Response> updateSystemSetting(String token, String key, String value) =>
      _dio.post('/admin/settings/update', data: {'key_name': key, 'value': value}, options: _auth(token));

  /// Hàm gửi thông báo đẩy (Broadcast) đến toàn bộ người dùng trên sàn.
  /// Tham số: token; title - Tiêu đề; message - Nội dung thông báo.
  /// Trả về: Response xác nhận đã gửi thành công.
  Future<Response> sendAdminBroadcast({required String token, required String title, required String message}) =>
      _dio.post('/admin/broadcast', data: {'title': title, 'content': message}, options: _auth(token));

  /// Hàm lấy danh sách các khiếu nại khách hàng gửi về sàn.
  /// Tham số: token quản trị.
  /// Trả về: Response danh sách khiếu nại.
  Future<Response> getAdminComplaints(String token) => _dio.get('/admin/complaints', options: _auth(token));

  /// Hàm đưa ra quyết định xử lý khiếu nại của Admin.
  /// Tham số: token; id khiếu nại; data - Nội dung hướng giải quyết.
  /// Trả về: Response kết quả giải quyết.
  Future<Response> resolveComplaint(String token, int id, Map<String, dynamic> data) =>
      _dio.post('/admin/complaints/$id/resolve', data: data, options: _auth(token));

  /// Hàm người mua gửi đơn khiếu nại về một đơn hàng hoặc shop.
  /// Tham số: token xác thực; data - Nội dung khiếu nại.
  /// Trả về: Response kết quả gửi.
  Future<Response> submitComplaint(String token, Map<String, dynamic> data) =>
      _dio.post('/customer/complaints', data: data, options: _auth(token));

  /// Hàm Shop xem danh sách khiếu nại mà mình đang bị vướng phải.
  /// Tham số: token xác thực shop.
  /// Trả về: Response danh sách khiếu nại của shop.
  Future<Response> getShopComplaints(String token) =>
      _dio.get('/shop/complaints', options: _auth(token));
}