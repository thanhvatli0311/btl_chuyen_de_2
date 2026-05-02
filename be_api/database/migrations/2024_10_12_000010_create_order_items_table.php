<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
Schema::create('order_items', function (Blueprint $table) {
    $table->id();
    $table->foreignId('order_id')->constrained()->onDelete('cascade');
    $table->foreignId('phone_id')->constrained('phones');
    $table->integer('quantity');
    $table->decimal('price', 15, 2);
    $table->timestamps();
});
Schema::create('order_status_logs', function (Blueprint $table) {
    $table->id();
    $table->foreignId('order_id')->constrained()->onDelete('cascade');
    $table->string('status_from');
    $table->string('status_to');
    $table->text('reason')->nullable();
    $table->foreignId('changed_by')->constrained('users');
    $table->timestamps();
});
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
        Schema::dropIfExists('order_status_logs');
    }
};
?>

