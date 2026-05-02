<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class NewsPostLike extends Model
{
    // ✅ Khai báo bảng nếu ông đặt tên khác với mặc định (số nhiều)
    protected $table = 'news_post_likes';

    // ✅ Cho phép lưu các trường này vào database
    protected $fillable = [
        'user_id',
        'news_post_id',
    ];

    /**
     * 👤 Mối quan hệ: Lượt thích này thuộc về một Người dùng
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    /**
     * 📝 Mối quan hệ: Lượt thích này thuộc về một Bài viết
     */
    public function newsPost(): BelongsTo
    {
        return $this->belongsTo(NewsPost::class, 'news_post_id');
    }
}