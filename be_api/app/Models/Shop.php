<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Shop extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id', 'name', 'slug', 'description', 'avatar',
        'warehouse_address', 'bank_info', 'balance', 'status'
    ];

    // GẮT GAO: Ép kiểu số thực để Flutter làm biểu đồ doanh thu không bị crash
    protected $casts = [
        'id' => 'integer',
        'user_id' => 'integer',
        'bank_info' => 'array',
        'balance' => 'double', // Chuyển từ decimal sang double để đồng bộ Flutter
    ];

    // Ẩn bank_info để bảo mật, chỉ hiện khi cần thiết
    protected $hidden = ['bank_info'];

    protected $appends = ['avatar_url'];

    // Quan hệ ngược về User
    public function user()
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    // Danh sách máy thuộc Shop (Khớp bảng phones.shop_id)
    public function phones()
    {
        return $this->hasMany(Phone::class, 'shop_id');
    }

    // Đơn hàng tại Shop (Khớp bảng orders.shop_id)
    public function orders()
    {
        return $this->hasMany(Order::class, 'shop_id');
    }

    public function coupons()
    {
        return $this->hasMany(Coupon::class, 'shop_id');
    }

    public function newsPosts()
    {
        return $this->hasMany(NewsPost::class, 'shop_id');
    }

    /**
     * Xử lý Avatar URL - Đã xét nét để khớp với tunnel zrok
     */
    public function getAvatarUrlAttribute()
    {
        if (filter_var($this->avatar, FILTER_VALIDATE_URL)) {
            return $this->avatar;
        }

        if ($this->avatar) {
            // Sử dụng asset() sẽ tự động lấy domain zrok của em
            return asset('storage/' . $this->avatar);
        }

        return 'https://ui-avatars.com/api/?name=' . urlencode($this->name) . '&background=0047AB&color=fff';
    }
    public function transactions()
{
    // Dựa vào SQL, transactions.user_id khớp với shops.user_id
    return $this->hasMany(Transaction::class, 'user_id', 'user_id');
}
}
