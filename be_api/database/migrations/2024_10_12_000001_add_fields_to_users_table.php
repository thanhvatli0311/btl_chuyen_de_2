<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('phone')->unique()->nullable()->after('email');
            $table->enum('role', ['customer', 'shop', 'admin'])->default('customer')->after('phone');
            $table->string('otp_code', 6)->nullable()->after('role');
            $table->timestamp('otp_expires_at')->nullable()->after('otp_code');
            $table->string('avatar')->nullable()->after('otp_expires_at');
            $table->enum('status', ['active', 'blocked'])->default('active')->after('avatar');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['phone', 'role', 'otp_code', 'otp_expires_at', 'avatar', 'status']);
        });
    }
};
?>

