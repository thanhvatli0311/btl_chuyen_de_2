<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;

class FCMService
{
    /**
     * Chức năng: Gửi yêu cầu đẩy thông báo đến máy chủ Firebase.
     * Tham số: $token (Mã thiết bị), $title (Tiêu đề), $body (Nội dung), $data (Dữ liệu đính kèm - Tùy chọn).
     */
    public static function sendPushNotification($token, $title, $body, $data = [])
    {
        // Địa chỉ API của Firebase Cloud Messaging (V1)
        $url = 'https://fcm.googleapis.com/fcm/send';

        // LƯU Ý: Đây là Server Key cũ (Legacy).
        // Nhóm nên cấu hình Service Account JSON để dùng V1 API cho bảo mật nhất.
        $serverKey = '8f8RVtRkIiOaWw_JOtRRIVcOc2Q0CYoqL1LKRl7qy3I';

        $response = Http::withHeaders([
            'Authorization' => 'key=' . $serverKey,
            'Content-Type'  => 'application/json',
        ])->post($url, [
            'to' => $token,
            'notification' => [
                'title' => $title,
                'body'  => $body,
                'sound' => 'default'
            ],
            'data' => $data, // Dùng để Flutter điều hướng khi nhấn vào thông báo
        ]);

        return $response->json();
    }
}
