<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Brand extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'slug',
        'description',
        'logo',
        'status', // SQL: ENUM('active', 'inactive')
    ];

    // Không cast status sang boolean vì DB là ENUM chuỗi
    protected $casts = [
        'created_at' => 'datetime',
    ];

    public function phones()
    {
        return $this->hasMany(Phone::class);
    }
    // Thêm vào trong class Brand
    protected $appends = ['logo_url'];

    public function getLogoUrlAttribute()
    {
        if (filter_var($this->logo, FILTER_VALIDATE_URL)) {
            return $this->logo;
        }
        return $this->logo ? asset('storage/' . $this->logo) : null;
    }
}
