<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Complaint extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'order_id',
        'shop_id',
        'type',        // cancel, exchange, return, quality
        'description',
        'status',      // pending, processing, resolved, rejected
        'admin_reply',
    ];

    // Người gửi khiếu nại (Khách hàng)
    public function user()
    {
        return $this->belongsTo(User::class);
    }

    // Đơn hàng bị khiếu nại
    public function order()
    {
        return $this->belongsTo(Order::class);
    }


    // Tranh chấp phát sinh từ khiếu nại này (Dành cho Admin)
    public function dispute()
    {
        return $this->hasOne(Dispute::class);
    }

    public function shop() { return $this->belongsTo(Shop::class); }
}
