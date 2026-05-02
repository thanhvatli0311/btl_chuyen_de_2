<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
Schema::create('orders', function (Blueprint $table) {
    $table->id();
    $table->string('code')->unique();
    $table->foreignId('customer_id')->constrained('users')->onDelete('cascade');
    $table->foreignId('shop_id')->constrained('shops')->onDelete('cascade');
    $table->foreignId('address_id')->constrained('addresses');
    $table->decimal('total_amount', 15, 2);
    $table->enum('status', ['pending', 'confirmed', 'shipping', 'delivered', 'cancelled', 'returned'])->default('pending');
    $table->enum('payment_method', ['cod', 'e-wallet', 'bank_transfer'])->default('cod');
    $table->boolean('is_paid')->default(false);
    $table->string('shipping_code')->nullable();
    $table->timestamps();
});

    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
    }
};
?>

