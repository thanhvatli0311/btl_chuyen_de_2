<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
Schema::create('transactions', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->enum('type', ['deposit', 'sale_revenue', 'withdraw', 'refund']);
    $table->decimal('amount', 15, 2);
    $table->decimal('balance_after', 15, 2);
    $table->string('reference_id')->nullable(); // Mã đơn hàng liên quan
    $table->timestamps();
});
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
?>

