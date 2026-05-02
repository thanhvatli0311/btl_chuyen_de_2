<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SystemSetting extends Model
{
    // Bảng này không dùng created_at mặc định nên tắt timestamps hoặc chỉ dùng updated_at
    public $timestamps = false;

    protected $fillable = [
        'key_name',
        'value',
        'description',
    ];
}
