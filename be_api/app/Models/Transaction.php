<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Transaction extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'type',           // deposit, sale_revenue, withdraw, refund
        'amount',
        'balance_after',  // SỬA: Khớp với SQL (Số dư sau giao dịch)
        'description',
        'reference_id',   // SỬA: Khớp với SQL (Mã tham chiếu đơn hàng)
    ];

    protected $casts = [
        'amount' => 'decimal:2',
        'balance_after' => 'decimal:2',
    ];

    // Người thực hiện giao dịch
    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
