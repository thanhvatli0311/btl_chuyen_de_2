<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class CategoryController extends Controller
{
    /**
     * Chức năng: Lấy danh sách toàn bộ danh mục sản phẩm theo cấu trúc phân cấp (Cha - Con).
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa danh sách các danh mục gốc kèm theo các danh mục con liên kết.
     */
    public function index()
    {
        // Thực hiện truy vấn lấy các danh mục không có parent_id (danh mục gốc)
        // Sử dụng Eager Loading 'with' để nạp kèm các danh mục con, giúp tối ưu số lượng câu truy vấn SQL
        $categories = Category::with('children')
            ->whereNull('parent_id')
            ->get();

        return response()->json(['success' => true, 'data' => $categories]);
    }

    /**
     * Chức năng: Khởi tạo một danh mục sản phẩm mới vào hệ thống (thao tác của Admin).
     * Tham số đầu vào: Request $request (chứa 'name' và 'parent_id' nếu là danh mục con).
     * Giá trị trả về: JSON thông tin danh mục vừa tạo và mã trạng thái 201.
     */
    public function store(Request $request)
    {
        // Kiểm tra tính hợp lệ của dữ liệu đầu vào
        $request->validate([
            'name' => 'required|string',
            'parent_id' => 'nullable|exists:categories,id'
        ]);

        // Tiến hành tạo bản ghi danh mục mới
        $category = Category::create([
            'name' => $request->name,
            // Chuyển đổi tên thành chuỗi slug không dấu phục vụ đường dẫn URL
            // Đính kèm hàm time() để đảm bảo tính duy nhất, tránh trùng lặp slug trong hệ thống
            'slug' => Str::slug($request->name) . '-' . time(),
            'parent_id' => $request->parent_id
        ]);

        return response()->json(['success' => true, 'data' => $category], 201);
    }
}
