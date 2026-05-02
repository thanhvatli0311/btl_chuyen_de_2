<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Phone extends Model
{
    use HasFactory;

    protected $fillable = [
        'shop_id', 'brand_id', 'category_id', 'title',
        'description',
        'slug', 'price', 'discount_price', 'stock',
        'condition', 'thumbnail', 'images', 'status'
    ];

    protected $casts = [
        'id' => 'integer',
        'shop_id' => 'integer',
        'price' => 'double',
        'discount_price' => 'double',
        'images' => 'array',
        'stock' => 'integer',
    ];

    // Quan hệ với Shop (Chủ sở hữu máy)
    public function shop()
    {
        return $this->belongsTo(Shop::class);
    }

    // Quan hệ với Thông số kỹ thuật (Dùng để Filter trên Flutter)
    public function specs()
    {
        return $this->hasMany(PhoneSpec::class);
    }

    public function brand()
    {
        return $this->belongsTo(Brand::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function orderItems()
    {
        return $this->hasMany(OrderItem::class);
    }
    protected $appends = ['thumbnail_url']; // Tự động thêm trường này vào JSON

    public function getThumbnailUrlAttribute()
    {
        // Nếu thumbnail đã là link tuyệt đối (như trong Seeder thầy viết) thì giữ nguyên
        if (filter_var($this->thumbnail, FILTER_VALIDATE_URL)) {
            return $this->thumbnail;
        }

        // Nếu là path, tự động nối thêm BASE URL của server hiện tại
        return asset('storage/' . $this->thumbnail);
    }
    public function reviews()
    {
        // Một điện thoại có nhiều đánh giá
        return $this->hasMany(Review::class, 'phone_id');
    }
}
