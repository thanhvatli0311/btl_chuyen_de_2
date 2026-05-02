<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('system_settings', function (Blueprint $table) {
            $table->id();
            $table->string('key_name', 50)->unique(); // VD: platform_fee
            $table->string('value');
            $table->text('description')->nullable();
            $table->timestamp('updated_at')->useCurrent()->useCurrentOnUpdate();
        });

        // Chèn dữ liệu mặc định ngay khi chạy migration
        DB::table('system_settings')->insert([
            [
                'key_name' => 'platform_fee',
                'value' => '5',
                'description' => 'Phí sàn khấu trừ từ mỗi đơn hàng (%)'
            ],
            [
                'key_name' => 'min_deposit',
                'value' => '1000000',
                'description' => 'Tiền cọc vận hành tối thiểu của Shop (VNĐ)'
            ],
            [
                'key_name' => 'seller_policy',
                'value' => 'Nội dung chính sách người bán...',
                'description' => 'Chính sách hiển thị trên App'
            ],
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('system_settings');
    }
};
