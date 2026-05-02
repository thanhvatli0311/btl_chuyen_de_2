<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class RoleMiddleware
{
    /**
     * Handle an incoming request.
     * Hỗ trợ kiểm tra một hoặc NHIỀU role cùng lúc.
     * Cách dùng trong route: middleware('role:admin,shop')
     */
    public function handle(Request $request, Closure $next, ...$roles): Response
    {
        $user = $request->user();

        // 1. Kiểm tra đăng nhập
        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'Vui lòng đăng nhập để thực hiện thao tác này.'
            ], 401);
        }

        // 2. Kiểm tra quyền hạn (Hỗ trợ mảng roles)
        if (!in_array($user->role, $roles)) {
            return response()->json([
                'success' => false,
                'message' => 'Bạn không có quyền truy cập chức năng này. Quyền yêu cầu: ' . implode(' hoặc ', $roles),
                'your_role' => $user->role
            ], 403);
        }

        return $next($request);
    }
}
