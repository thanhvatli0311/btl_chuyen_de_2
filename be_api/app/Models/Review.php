<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Review extends Model {
    protected $fillable = ['user_id', 'phone_id', 'rating', 'comment'];

    // Quan hệ với User để lấy tên/avatar người đánh giá
    public function user()
{
    // Một đánh giá thuộc về một người dùng
    return $this->belongsTo(User::class, 'user_id');
}

    public function phone() {
        return $this->belongsTo(Phone::class);
    }
}
