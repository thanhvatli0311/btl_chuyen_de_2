<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Xóa bảng cũ nếu tồn tại để làm mới theo cấu trúc Admin
        Schema::dropIfExists('banners');

        Schema::create('banners', function (Blueprint $table) {
            $table->id();
            $table->text('image_url');
            $table->text('link_url')->nullable();
            $table->boolean('is_active')->default(true);
            $table->integer('position')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('banners');
    }
};
