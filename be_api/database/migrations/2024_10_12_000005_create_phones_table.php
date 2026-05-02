<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
Schema::create('phones', function (Blueprint $table) {
    $table->id();
    $table->foreignId('shop_id')->constrained('shops')->onDelete('cascade');
    $table->foreignId('brand_id')->constrained()->onDelete('cascade');
    $table->foreignId('category_id')->constrained()->onDelete('cascade');
    $table->string('title');
    $table->string('slug')->unique();
    $table->decimal('price', 15, 2);
    $table->decimal('discount_price', 15, 2)->nullable();
    $table->integer('stock')->default(0);
    $table->enum('condition', ['new', 'used_like_new', 'used'])->default('new');
    $table->string('thumbnail');
    $table->json('images')->nullable();
    $table->enum('status', ['active', 'inactive', 'sold_out'])->default('active');
    $table->timestamps();
});
Schema::create('phone_specs', function (Blueprint $table) {
    $table->id();
    $table->foreignId('phone_id')->constrained()->onDelete('cascade');
    $table->string('spec_key');   // RAM, CPU...
    $table->string('spec_value'); // 8GB, Snapdragon...
    $table->timestamps();
    $table->index(['spec_key', 'spec_value']);
});
    }

    public function down(): void
    {
        Schema::dropIfExists('phones');
        Schema::dropIfExists('phone_specs');
    }
};
?>

