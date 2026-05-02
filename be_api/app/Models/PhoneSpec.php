<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PhoneSpec extends Model
{
    use HasFactory;

    protected $fillable = ['phone_id', 'spec_key', 'spec_value'];

    // Thuộc về sản phẩm nào
    public function phone() {
        return $this->belongsTo(Phone::class);
    }
}
