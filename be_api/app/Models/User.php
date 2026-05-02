<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;


// Import các model liên quan để tránh lỗi "Class not found"
use App\Models\{Shop, Order, Cart, Address, Notification, Complaint, Transaction, Review};

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'phone', 'password', 'role', 'avatar',
        'status', 'otp_code', 'otp_expires_at'
    ];

    protected $hidden = [
        'password', 'remember_token',
    ];

    /**
     * TẦNG LOGIC: Ép kiểu dữ liệu (Casting)
     * Giúp Flutter nhận đúng kiểu int/datetime thay vì string, tránh lỗi "type mismatch"
     */
    protected $casts = [
        'id' => 'integer',
        'email_verified_at' => 'datetime',
        'otp_expires_at' => 'datetime',
        'password' => 'hashed',
    ];

    /**
     * TẦNG HIỆU NĂNG: Eager Loading mặc định
     * Tự động nạp quan hệ shop. Flutter gọi baseProvider.user.shop sẽ có dữ liệu ngay.
     */


    /*
    |--------------------------------------------------------------------------
    | CÁC QUAN HỆ (RELATIONSHIPS) - CHUẨN HÓA CHO CHAT & REVIEW
    |--------------------------------------------------------------------------
    */

    // 1. Gian hàng (Dành cho Role: Shop)
    public function shop()
    {
        return $this->hasOne(Shop::class, 'user_id');
    }

    // 2. CHAT & TIN NHẮN (Fix lỗi 500 cho ChatController)
    // Dùng Message model vì bảng tin nhắn của ông là 'messages'
    public function sentChats()
    {
        return $this->hasMany(Chat::class, 'from_user_id');
    }

    public function receivedChats()
    {
        return $this->hasMany(Chat::class, 'to_user_id');
    }

    // 3. ĐÁNH GIÁ (Mới bổ sung cho tính năng Đánh giá)
    public function reviews()
    {
        return $this->hasMany(Review::class, 'user_id');
    }

    // 4. MUA SẮM & ĐỊA CHỈ
    public function customerOrders()
    {
        return $this->hasMany(Order::class, 'customer_id');
    }

    public function carts()
    {
        return $this->hasMany(Cart::class, 'user_id');
    }

    public function addresses()
    {
        return $this->hasMany(Address::class, 'user_id');
    }

    // 5. TÀI CHÍNH & KHIẾU NẠI
    public function transactions()
    {
        return $this->hasMany(Transaction::class, 'user_id');
    }

    public function complaints()
    {
        return $this->hasMany(Complaint::class, 'user_id');
    }

    public function notifications()
    {
        return $this->hasMany(Notification::class, 'user_id');
    }

    /*
    |--------------------------------------------------------------------------
    | SCOPES & ACCESSORS (TỐI ƯU CHO FLUTTER)
    |--------------------------------------------------------------------------
    */

    // Lọc nhanh vai trò: User::customer()->get();
    public function scopeCustomer($query) { return $query->where('role', 'customer'); }
    public function scopeShop($query) { return $query->where('role', 'shop'); }
    public function scopeAdmin($query) { return $query->where('role', 'admin'); }

    /**
     * XỬ LÝ AVATAR:
     * Giữ nguyên path để Flutter ImageHelper.dart tự nối URL của server
     */
    public function getAvatarAttribute($value)
    {
        return $value;
    }
}
