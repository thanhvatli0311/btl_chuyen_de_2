<?php

namespace App\Http\Middleware;

use Illuminate\Auth\Middleware\Authenticate as Middleware;
use Illuminate\Http\Request;

class Authenticate extends Middleware
{
    /**
     * Get the path the user should be redirected to when they are not authenticated.
     */
    protected function redirectTo($request)
    {
        // ✅ Kiểm tra: Nếu yêu cầu KHÔNG PHẢI là JSON thì mới trả về route login
        // Với API Flutter của ông, nó sẽ bỏ qua dòng này và không gây lỗi nữa.
        if (! $request->expectsJson()) {
            return route('login');
        }

        // Trả về null để Laravel trả về mã lỗi 401 JSON chuẩn thay vì Redirect
        return null;
    }
}
