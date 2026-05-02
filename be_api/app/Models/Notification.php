<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Notification extends Model
{
    use HasFactory;

    // Các trường được phép nạp dữ liệu hàng loạt
    protected $fillable = [
        'user_id',
        'title',
        'content',
        'type',
        'is_read',
        'read_at'
    ];

    /**
     * Chức năng: Thiết lập mối quan hệ với bảng Users.
     * Giá trị trả về: Thuộc về một người dùng (BelongsTo).
     */
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
