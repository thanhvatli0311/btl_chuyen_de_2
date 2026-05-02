<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OrderStatusLog extends Model
{
    protected $fillable = ['order_id', 'status_from', 'status_to', 'reason', 'changed_by'];

    // Quan hệ ngược lại với đơn hàng
    public function order() {
        return $this->belongsTo(Order::class);
    }

    // Người thực hiện thay đổi (Admin hoặc Shop hoặc Khách)
    public function user() {
        return $this->belongsTo(User::class, 'changed_by');
    }
}
