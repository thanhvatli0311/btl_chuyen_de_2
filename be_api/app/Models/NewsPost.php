<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class NewsPost extends Model
{
    use HasFactory;

    protected $fillable = ['shop_id', 'title', 'content', 'images', 'likes_count', 'comments_count'];

    protected $casts = [
        'images' => 'array',
        'likes_count' => 'integer',
        'comments_count' => 'integer',
    ];

    public function shop() { return $this->belongsTo(Shop::class, 'shop_id'); }

    public function likes() { return $this->hasMany(NewsPostLike::class, 'news_post_id'); }
    public function user() {
        return $this->belongsTo(User::class);
    }

    // Hình ảnh của bài tin
    public function images() {
        return $this->hasMany(NewsPost::class, 'post_id');
    }

    // Bình luận (Lấy kèm user để hiện avatar/tên)
    public function comments() {
        return $this->hasMany(NewsComment::class, 'post_id')->with('user')->whereNull('parent_id')->latest();
    }


}
?>
