<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('news_posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('shop_id')->constrained('users')->onDelete('cascade');
            $table->string('title');
            $table->text('content');
            $table->json('images')->nullable();
            $table->unsignedInteger('likes_count')->default(0);
            $table->unsignedInteger('comments_count')->default(0);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('news_posts');
    }
};
?>
</xai:function_call

<xai:function_call name="create_file">
<parameter name="absolute_path">database/migrations/2024_10_12_000013_create_news_comments_table.php
