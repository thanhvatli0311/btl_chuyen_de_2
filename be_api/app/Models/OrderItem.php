<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OrderItem extends Model
{
    use HasFactory;

    protected $fillable = ['order_id', 'phone_id', 'price', 'quantity', 'subtotal'];

    protected $casts = [
        'price' => 'decimal:2',
        'subtotal' => 'decimal:2', // ✅ Đảm bảo tính toán tiền tệ chính xác cho Flutter
    ];

    public function order() { return $this->belongsTo(Order::class); }
    public function phone() { return $this->belongsTo(Phone::class); }
}
