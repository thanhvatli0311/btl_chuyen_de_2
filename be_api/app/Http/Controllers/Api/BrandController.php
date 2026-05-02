<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Brand;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class BrandController extends Controller
{
    /**
     * Chức năng: Truy vấn và trả về danh sách các hãng sản xuất đang hoạt động.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa trạng thái thành công và mảng dữ liệu các hãng.
     */
    public function index()
    {
        // Chỉ lấy những hãng có trạng thái là 'active' để hiển thị lên ứng dụng
        $brands = Brand::where('status', 'active')->get();
        return response()->json(['success' => true, 'data' => $brands]);
    }

    /**
     * Chức năng: Tiếp nhận dữ liệu và khởi tạo một hãng sản xuất mới.
     * Tham số đầu vào: Request $request (Chứa thông tin tên, logo, mô tả).
     * Giá trị trả về: JSON thông tin hãng vừa tạo kèm mã trạng thái 201 hoặc thông báo lỗi.
     */
    public function store(Request $request)
    {
        try {
        // Kiểm tra tính hợp lệ: Tên hãng là bắt buộc và không được trùng lặp trong bảng brands
        $request->validate([
            'name' => 'required|string|unique:brands,name',
        ], [
            'name.unique' => 'Hãng này đã có rồi, ông chọn trong danh sách nhé!'
        ]);

        // Tiến hành lưu dữ liệu vào cơ sở dữ liệu
        $brand = Brand::create([
            'name' => $request->name,
            // Chuyển tên hãng thành dạng slug (ví dụ: "Apple iPhone" thành "apple-iphone") để làm URL đẹp
            'slug' => Str::slug($request->name),
            'logo' => $request->logo ?? null,
            'description' => $request->description,
            'status' => 'active'
        ]);

        return response()->json(['success' => true, 'message' => 'Đã thêm hãng mới!', 'data' => $brand], 201);
        } catch (\Exception $e)
        {
            // Trả về lỗi 500 nếu có sự cố bất ngờ từ server
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Cập nhật thông tin của hãng sản xuất đã có dựa trên mã ID.
     * Tham số đầu vào: Request $request (Dữ liệu mới), $id (Mã định danh của hãng).
     * Giá trị trả về: JSON xác nhận kết quả cập nhật.
     */
    public function update(Request $request, $id) {
        try {
            // Tìm hãng theo ID, nếu không thấy sẽ tự động quăng lỗi ModelNotFound
            $brand = Brand::findOrFail($id);

            // Validate tên hãng mới, cho phép trùng với tên hiện tại của chính nó nhưng không được trùng với hãng khác
            $request->validate([
                'name' => 'required|string|unique:brands,name,' . $id,
            ]);

            // Cập nhật đồng thời cả tên và chuỗi slug tương ứng
            $brand->update([
                'name' => $request->name,
                'slug' => \Illuminate\Support\Str::slug($request->name),
            ]);

            return response()->json(['success' => true, 'message' => 'Cập nhật hãng thành công!']);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Xóa bỏ hoàn toàn một hãng sản xuất khỏi hệ thống.
     * Tham số đầu vào: $id (Mã định danh của hãng cần xóa).
     * Giá trị trả về: JSON xác nhận việc xóa thành công hoặc báo lỗi.
     */
    public function destroy($id) {
        try {
            // Xác định hãng cần xóa, trả về 404 nếu ID không tồn tại
            $brand = Brand::findOrFail($id);
            $brand->delete();
            return response()->json(['success' => true, 'message' => 'Đã xóa hãng!']);
        } catch (\Exception $e) {
            // Báo lỗi 500 trong trường hợp không thể xóa (ví dụ: bị ràng buộc khóa ngoại bởi các sản phẩm)
            return response()->json(['success' => false, 'message' => 'Không thể xóa hãng này'], 500);
        }
    }

}
