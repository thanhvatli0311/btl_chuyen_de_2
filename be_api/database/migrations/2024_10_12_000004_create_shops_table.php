<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
Schema::create('shops', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->unique()->constrained()->onDelete('cascade');
    $table->string('name')->unique();
    $table->string('slug')->unique();
    $table->text('description')->nullable();
    $table->string('avatar')->nullable();
    $table->string('warehouse_address');
    $table->json('bank_info')->nullable(); // Lưu STK, Tên ngân hàng
    $table->decimal('balance', 15, 2)->default(0); // Ví tiền shop
    $table->enum('status', ['pending', 'approved', 'blocked'])->default('pending');
    $table->timestamps();
});
    }

    public function down(): void
    {
        Schema::dropIfExists('shops');
    }
};
?>

