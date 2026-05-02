<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Phone, PhoneSpec};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Exception;

class PhoneController extends Controller
{
    /**
     * Chức năng: Lấy danh sách điện thoại dựa trên bộ lọc và phân quyền (Shop hoặc Khách hàng).
     * Tham số đầu vào: Request $request (chứa các tham số lọc: search, brand_id, category_id, sort_by).
     * Giá trị trả về: JSON chứa danh sách sản phẩm kèm các quan hệ (brand, category, specs, shop).
     */
    public function index(Request $request)
    {
        try {
            $query = Phone::with(['brand', 'category', 'specs', 'shop']);

            // 1. Phân quyền truy cập: Nếu là route của Shop thì chỉ lấy hàng của Shop đó, ngược lại chỉ lấy hàng đang 'active'
            if ($request->is('api/shop/*')) {
                $user = $request->user();
                if (!$user || !$user->shop) return response()->json(['success' => true, 'data' => []]);
                $query->where('shop_id', $user->shop->id);
            } else {
                $query->where('status', 'active');
            }

            // 2. Áp dụng các bộ lọc tìm kiếm theo tên, hãng sản xuất và danh mục máy
            if ($request->filled('search')) $query->where('title', 'LIKE', '%' . $request->search . '%');
            if ($request->filled('brand_id')) $query->where('brand_id', $request->brand_id);
            if ($request->filled('category_id')) $query->where('category_id', $request->category_id);

            // 3. Xử lý logic sắp xếp dữ liệu theo yêu cầu từ người dùng
            if ($request->filled('sort_by')) {
                switch ($request->sort_by) {
                    case 'price_asc':
                        $query->orderBy('price', 'asc');
                        break;
                    case 'price_desc':
                        $query->orderBy('price', 'desc');
                        break;
                    case 'discount':
                        // Logic sắp xếp giảm sâu: Tính hiệu số giữa giá gốc và giá KM để tìm mức giảm lớn nhất
                        $query->whereNotNull('discount_price')
                            ->orderByRaw('(price - discount_price) DESC');
                        break;
                    case 'latest':
                        $query->latest();
                        break;
                    default:
                        $query->latest();
                        break;
                }
            } else {
                $query->latest();
            }

            $phones = $query->get();
            return response()->json(['success' => true, 'data' => $phones]);

        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Tiếp nhận dữ liệu, xử lý hình ảnh và đăng bán sản phẩm điện thoại mới.
     * Tham số đầu vào: Request $request (Thông tin máy, tệp hình ảnh, mảng thông số kỹ thuật).
     * Giá trị trả về: JSON thông tin máy vừa tạo kèm mã trạng thái 201.
     */
    public function store(Request $request)
    {
        try {
            // Xác thực dữ liệu đầu vào bắt buộc từ phía khách hàng/shop
            $request->validate([
                'brand_id' => 'required|exists:brands,id',
                'category_id' => 'required|exists:categories,id',
                'title' => 'required|string|max:255',
                'price' => 'required|numeric|min:0',
                'stock' => 'required|integer|min:0',
                'condition' => 'required',
                'thumbnail' => 'required',
                'specs' => 'required|array',
            ]);


            // Sử dụng Database Transaction để đảm bảo tính nhất quán (nếu lưu máy lỗi thì không lưu thông số)
            return DB::transaction(function () use ($request) {
                // Xử lý lưu trữ ảnh đại diện chính của sản phẩm vào ổ đĩa public
                $thumbnailPath = $request->thumbnail;
                if ($request->hasFile('thumbnail')) {
                    $thumbnailPath = $request->file('thumbnail')->store('products', 'public');
                }

                // Duyệt mảng để lưu trữ các hình ảnh chi tiết bổ sung
                $imagePaths = [];
                if ($request->hasFile('images')) {
                    foreach ($request->file('images') as $file) {
                        $imagePaths[] = $file->store('products/details', 'public');
                    }
                }

                $phone = Phone::create([
                    'shop_id' => auth()->user()->shop->id,
                    'brand_id' => $request->brand_id,
                    'category_id' => $request->category_id,
                    'title' => $request->title,
                    'description' => $request->description,
                    'slug' => Str::slug($request->title) . '-' . time(), // Tạo đường dẫn không dấu kèm mốc thời gian để tránh trùng
                    'price' => $request->price,
                    'discount_price' => $request->discount_price,
                    'stock' => $request->stock,
                    'condition' => $request->condition,
                    'thumbnail' => $thumbnailPath,
                    'images' => $imagePaths, // Mảng đường dẫn ảnh sẽ được Eloquent tự cast sang JSON
                    'status' => 'active',
                ]);

                // Lưu danh sách các thông số kỹ thuật chi tiết (RAM, Pin, Chip...) vào bảng liên kết
                foreach ($request->specs as $spec) {
                    if(!empty($spec['spec_key']) && !empty($spec['spec_value'])) {
                        $phone->specs()->create([
                            'spec_key' => $spec['spec_key'],
                            'spec_value' => $spec['spec_value']
                        ]);
                    }
                }

                return response()->json([
                    'success' => true,
                    'message' => 'Đăng máy thành công!',
                    'data' => $phone->load('specs')
                ], 201);
            });
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Lấy dữ liệu chi tiết của một sản phẩm thông qua đường dẫn slug (Public).
     * Tham số đầu vào: $slug (Chuỗi định danh duy nhất của sản phẩm).
     * Giá trị trả về: JSON chứa thông tin máy kèm hãng, danh mục, thông số, shop và đánh giá.
     */
    public function show($slug)
    {
        try {
            // Tìm kiếm sản phẩm theo slug, nạp toàn bộ các quan hệ cần thiết cho giao diện Flutter
            $phone = Phone::with(['brand', 'category', 'specs', 'shop.user', 'reviews.user'])
                ->where('slug', $slug)
                ->firstOrFail();

            return response()->json(['success' => true, 'data' => $phone]);
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => 'Không tìm thấy sản phẩm'], 404);
        }
    }

    /**
     * Chức năng: Cập nhật nhanh số lượng tồn kho của máy (dành cho người bán).
     * Tham số đầu vào: Request $request (chứa số lượng stock), $id (ID máy).
     * Giá trị trả về: JSON báo kết quả cập nhật kho hàng.
     */
    public function updateStock(Request $request, $id)
    {
        try {
            $request->validate(['stock' => 'required|integer|min:0']);

            // Đảm bảo máy tồn tại và thuộc quyền quản lý của đúng Shop đang đăng nhập
            $phone = Phone::where('id', $id)
                ->where('shop_id', auth()->user()->shop->id)
                ->firstOrFail();

            $phone->update(['stock' => $request->stock]);

            return response()->json(['success' => true, 'message' => 'Cập nhật kho thành công']);
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => 'Lỗi cập nhật kho'], 500);
        }
    }

    /**
     * Chức năng: Gỡ bỏ hoàn toàn sản phẩm khỏi hệ thống.
     * Tham số đầu vào: $id (Mã định danh sản phẩm cần xóa).
     * Giá trị trả về: JSON xác nhận việc xóa thành công.
     */
    public function destroy($id)
    {
        try {
            // Xác thực quyền sở hữu sản phẩm trước khi thực hiện lệnh xóa
            $phone = Phone::where('id', $id)
                ->where('shop_id', auth()->user()->shop->id)
                ->firstOrFail();

            $phone->delete();
            return response()->json(['success' => true, 'message' => 'Đã xóa máy khỏi hệ thống']);
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => 'Không thể xóa máy này'], 500);
        }
    }

    /**
     * Chức năng: Chỉnh sửa toàn bộ thông tin sản phẩm hiện có, bao gồm xử lý lại hình ảnh và thông số.
     * Tham số đầu vào: Request $request (dữ liệu cập nhật), $id (Mã máy cần sửa).
     * Giá trị trả về: JSON dữ liệu máy sau khi đã cập nhật xong.
     */
    public function update(Request $request, $id)
    {
        try {
            $phone = Phone::where('id', $id)->where('shop_id', auth()->user()->shop->id)->firstOrFail();

            $request->validate([
                'title' => 'required|string|max:255',
                'price' => 'required|numeric|min:0',
                'stock' => 'required|integer|min:0',
                'specs' => 'required|array',
            ]);

            return DB::transaction(function () use ($request, $phone) {
                // Logic xử lý Thumbnail: Nếu người dùng gửi file mới thì lưu, nếu gửi string (URL cũ) thì giữ lại giá trị cũ
                $thumbnailPath = $phone->thumbnail;
                if ($request->hasFile('thumbnail')) {
                    $thumbnailPath = $request->file('thumbnail')->store('products', 'public');
                }

                // Xử lý cập nhật danh sách ảnh chi tiết: Ghi đè mảng ảnh mới nếu có tải file lên
                $imagePaths = $phone->images;
                if ($request->hasFile('images')) {
                    $imagePaths = [];
                    foreach ($request->file('images') as $file) {
                        $imagePaths[] = $file->store('products/details', 'public');
                    }
                }

                // Thực hiện cập nhật dữ liệu vào bảng chính
                $phone->update([
                    'brand_id' => $request->brand_id ?? $phone->brand_id,
                    'category_id' => $request->category_id ?? $phone->category_id,
                    'title' => $request->title,
                    'description' => $request->description ?? $phone->description,
                    'price' => $request->price,
                    'discount_price' => $request->discount_price,
                    'stock' => $request->stock,
                    'condition' => $request->condition ?? $phone->condition,
                    'thumbnail' => $thumbnailPath,
                    'images' => $imagePaths,
                    'status' => 'active',
                ]);

                // Xóa các thông số kỹ thuật cũ và ghi đè lại toàn bộ mảng thông số mới
                $phone->specs()->delete();
                foreach ($request->specs as $spec) {
                    if(!empty($spec['spec_key'])) {
                        $phone->specs()->create([
                            'spec_key' => $spec['spec_key'],
                            'spec_value' => $spec['spec_value']
                        ]);
                    }
                }

                return response()->json(['success' => true, 'message' => 'Cập nhật thành công!', 'data' => $phone->load('specs')]);
            });
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Thiết lập hoặc gỡ bỏ giá khuyến mãi cho một máy cụ thể.
     * Tham số đầu vào: Request $request (chứa discount_price), $id (ID máy).
     * Giá trị trả về: JSON thông báo kết quả.
     */
    public function updateDiscount(Request $request, $id)
    {
        try {
            $phone = Phone::where('id', $id)->where('shop_id', auth()->user()->shop->id)->firstOrFail();

            // Kiểm tra tính hợp lệ của giá khuyến mãi (phải nhỏ hơn giá gốc hiện tại)
            $request->validate([
                'discount_price' => [
                    'nullable', 'numeric', 'min:0',
                    function ($attribute, $value, $fail) use ($phone) {
                        if ($value >= $phone->price) $fail('Giá KM phải nhỏ hơn giá gốc.');
                    },
                ],
            ]);

            $phone->update(['discount_price' => $request->discount_price]);

            return response()->json(['success' => true, 'message' => 'Cập nhật khuyến mãi thành công']);
        } catch (Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }
}
