<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Banner extends Model
{
    use HasFactory;

    // Các trường có thể điền từ API Admin gửi lên
    protected $fillable = [
        'title',
        'image',
        'link',
        'position',
        'expires_at',
        'is_active',
    ];

    // Ép kiểu dữ liệu để Flutter nhận đúng dạng
    protected $casts = [
        'is_active' => 'boolean',
        'expires_at' => 'datetime',
    ];

    // Thêm vào trong class Banner
    protected $appends = ['image_url'];

    public function getImageUrlAttribute()
    {
        if (filter_var($this->image, FILTER_VALIDATE_URL)) {
            return $this->image;
        }
        return asset('storage/' . $this->image);
    }
}


