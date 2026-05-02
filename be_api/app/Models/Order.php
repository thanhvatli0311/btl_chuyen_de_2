<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Order extends Model
{
    use HasFactory;

    protected $fillable = [
        'code', 
        'customer_id', 
        'shop_id', 
        'address_id',
        'total_amount', 
        'status', 
        'payment_method',
        'is_paid', 
        'shipping_code'
    ];

    protected $casts = [
        'total_amount' => 'decimal:2',
        'is_paid' => 'boolean',
    ];

    // Người mua
    public function customer()
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    // Cửa hàng bán
    public function shop()
    {
        return $this->belongsTo(Shop::class);
    }

    // Địa chỉ nhận hàng
    public function address()
    {
        return $this->belongsTo(Address::class);
    }

    // Danh sách sản phẩm trong đơn
    public function items()
    {
        return $this->hasMany(OrderItem::class);
    }

    // Lịch sử thay đổi trạng thái (Shipping logs)
    public function statusLogs()
    {
        return $this->hasMany(OrderStatusLog::class)->orderBy('created_at', 'desc');
    }

    public function refunds()
    {
        return $this->hasMany(Refund::class);
    }

    public function complaint()
    {
        return $this->hasOne(Complaint::class);
    }
}
