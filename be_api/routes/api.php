<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\{
    AuthController, PhoneController, OrderController, ShopController,
    CategoryController, BrandController, AddressController, CartController,
    TransactionController, ComplaintController, NewsController, NotificationController, ChatController, ReviewController, AdminController
};

/*
|--------------------------------------------------------------------------
| PUBLIC
|--------------------------------------------------------------------------
*/
Route::post('/login', [AuthController::class, 'login'])->name('login');
Route::post('/register', [AuthController::class, 'register']);
Route::post('/send-otp', [AuthController::class, 'sendOtp']);
Route::post('/verify-otp', [AuthController::class, 'verifyOtp']);
Route::post('/password/reset', [AuthController::class, 'resetPassword']);


Route::get('/banners', [AuthController::class, 'getBanners']);
Route::get('/categories', [CategoryController::class, 'index']);
Route::get('/brands', [BrandController::class, 'index']);
Route::get('/phones', [PhoneController::class, 'index']);
Route::get('/phones/{slug}', [PhoneController::class, 'show']);

Route::get('/shops/{slug}', [ShopController::class, 'publicProfile']);
Route::get('/phones/{phoneId}/reviews', [ReviewController::class, 'index']);
Route::get('/phones/{id}/related', [PhoneController::class, 'getRelated']);
 Route::get('/news', [NewsController::class, 'index']);
 Route::get('/news/{id}', [NewsController::class, 'show']);

/*
|--------------------------------------------------------------------------
| 2. PROTECTED API (Đã đăng nhập)
|--------------------------------------------------------------------------
*/



Route::middleware('auth:sanctum')->group(function () {


    // ✅ PROFILE DÙNG CHUNG (Dành cho cả 3 luồng: Admin, Shop, Customer)
    // Đáp ứng hàm getProfile() trong BaseProvider
    Route::get('/user/profile', [AuthController::class, 'profile']);
    // Đáp ứng hàm đổi avatar/tên trong ProfileScreen
    Route::match(['post', 'put'], '/user/profile', [AuthController::class, 'updateProfile']);
    Route::post('/shop/register-request', [ShopController::class, 'registerShop']);

    Route::post('/news/{id}/like', [NewsController::class, 'likePost']);
    Route::post('/news/{id}', [NewsController::class, 'update']);
    Route::delete('/news/{id}', [NewsController::class, 'destroy']);
    Route::post('/news/{id}/comments', [NewsController::class, 'storeComment']);

    // --- CUSTOMER MODULE ---
    Route::prefix('customer')->middleware('role:customer,admin,shop')->group(function () {
        Route::post('/reviews', [ReviewController::class, 'store']);
        Route::post('/complaints', [ComplaintController::class, 'store']);
        Route::apiResource('addresses', AddressController::class);
        Route::apiResource('cart', CartController::class);
        // ✅ THÊM DÒNG NÀY: API xóa các món đã chọn sau khi thanh toán thành công
        Route::post('/cart/remove-selected', [CartController::class, 'removeSelected']);
        Route::post('/orders/checkout', [OrderController::class, 'checkout']);
        Route::get('/orders', [OrderController::class, 'customerOrders']);
        Route::get('/orders/{code}', [OrderController::class, 'show']);
        Route::post('/orders/{id}/cancel', [OrderController::class, 'cancel']);
        Route::post('/report', [ComplaintController::class, 'reportViolation']);
        Route::get('/notifications', [NotificationController::class, 'index']); // Lấy danh sách
        Route::post('/notifications/{id}/read', [NotificationController::class, 'markAsRead']); // Đọc 1 cái
        Route::post('/notifications/read-all', [NotificationController::class, 'markAllAsRead']); // Đọc hết
        Route::delete('/notifications/{id}', [NotificationController::class, 'destroy']); // Xóa
        Route::put('/chats/{receiverId}/read', [ChatController::class, 'markAsRead']);

    });

    // --- SHOP MODULE ---
    Route::prefix('shop')->middleware('role:shop,admin')->group(function () {
        Route::get('/dashboard', [ShopController::class, 'getDashboardStats']);
        Route::get('/revenue-stats', [ShopController::class, 'getRevenueStats']);
        Route::get('/wallet', [TransactionController::class, 'shopWallet']);
        Route::patch('/phones/{id}/discount', [PhoneController::class, 'updateDiscount']);


        // Quản lý sản phẩm của Shop
        Route::apiResource('phones', PhoneController::class)->except(['show']);
        Route::post('/phones/{id}/update-stock', [PhoneController::class, 'updateStock']);
        Route::apiResource('brands', BrandController::class);

        // Quản lý đơn hàng cho Shop
        Route::get('/orders', [OrderController::class, 'shopOrders']);
        Route::put('/orders/{id}/status', [OrderController::class, 'updateStatus']);
        Route::get('/news-management', [NewsController::class, 'manageIndex']);

        // Marketing & Ví
        Route::post('/coupons', [ShopController::class, 'storeCoupon']);
        Route::get('/transactions', [TransactionController::class, 'index']);
        Route::get('/complaints', [ComplaintController::class, 'shopIndex']);
        Route::post('/news', [NewsController::class, 'store']);
        Route::post('/news/{id}', [NewsController::class, 'update']);



    });

    // --- ADMIN MODULE ---
    Route::prefix('admin')->middleware('role:admin')->group(function () {
        Route::get('/dashboard-stats', [AdminController::class, 'getDashboardStats']);
        Route::get('/users', [AdminController::class, 'allUsers']);
        Route::put('/users/{id}', [AdminController::class, 'updateUser']);

        // ✅ QUY VỀ MỘT MỐI: Quản lý Shop hoàn toàn ở AdminController
        Route::get('/shops', [AdminController::class, 'getShops']); // Lấy tất cả hoặc lọc theo status
        Route::put('/shops/{id}/status', [AdminController::class, 'updateShopStatus']); // Duyệt hoặc Khóa

        Route::get('/pending-phones', [AdminController::class, 'getPendingPhones']);
        Route::put('/phones/{id}/approve', [AdminController::class, 'approvePhone']);

        Route::get('/settings', [AdminController::class, 'getSystemSettings']);
        Route::post('/settings/update', [AdminController::class, 'updateSetting']);
        Route::post('/broadcast', [AdminController::class, 'sendBroadcast']);
        // Phải trỏ đúng vào 'adminIndex'
        Route::get('/complaints', [ComplaintController::class, 'adminIndex']);
        // API lấy dữ liệu biểu đồ doanh thu theo ngày
        Route::get('/daily-revenue', [AdminController::class, 'getDailyRevenue']);
        // API lấy bảng xếp hạng doanh thu các Shop
        Route::get('/shop-rankings', [AdminController::class, 'getShopRankings']);
        Route::get('/shops/{shopId}/analytics', [AdminController::class, 'getShopDetailAnalytics']);
        Route::get('/orders', [OrderController::class, 'allOrders']);
        Route::post('/banners', [AdminController::class, 'storeBanner']);
        Route::post('/complaints/{id}/resolve', [ComplaintController::class, 'resolve']);

    });





    // Chat & Social (Dùng chung)
    Route::prefix('chats')->group(function () {
        Route::get('/', [ChatController::class, 'getChatList']);

    Route::get('/{receiverId}', [ChatController::class, 'getMessages']);
    Route::post('/send', [ChatController::class, 'sendMessage']);
    });


    Route::post('/logout', [AuthController::class, 'logout']);
});
