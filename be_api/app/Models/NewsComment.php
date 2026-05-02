<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class NewsComment extends Model
{
    use HasFactory;

    protected $fillable = [
        'post_id',
        'user_id',
        'content',
        'parent_id',
    ];



    public function user() { return $this->belongsTo(User::class, 'user_id'); }

    public function parent()
    {
        return $this->belongsTo(NewsComment::class, 'parent_id');
    }

    public function children()
    {
        return $this->hasMany(NewsComment::class, 'parent_id');
    }


public function post()
{
    return $this->belongsTo(NewsPost::class, 'post_id');
}
}
?>

