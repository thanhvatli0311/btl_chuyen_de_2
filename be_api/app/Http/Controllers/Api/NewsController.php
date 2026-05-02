<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{NewsPost, NewsComment, Phone, NewsPostLike};
use Illuminate\Support\Facades\Auth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class NewsController extends Controller
{
    /**
     * Chức năng: Lấy danh sách toàn bộ bản tin công khai dành cho khách hàng.
     * Tham số đầu vào: Không có (Lấy thông tin User qua Sanctum nếu đã đăng nhập).
     * Giá trị trả về: JSON chứa danh sách bài viết phân trang, bao gồm thông tin shop, bình luận và trạng thái yêu thích.
     */
    public function index()
    {
        try {
            // Xác định ID người dùng từ Token nếu có để kiểm tra trạng thái Like bài viết
            $userId = request()->user('sanctum')?->id;

            $posts = NewsPost::with(['shop', 'comments.user'])
                ->when($userId, function($q) use ($userId) {
                    // Nếu đã đăng nhập, kiểm tra xem người dùng hiện tại đã nhấn Like bài này chưa
                    $q->withExists(['likes as is_liked' => function($query) use ($userId) {
                        $query->where('user_id', $userId);
                    }]);
                })
                ->latest()
                ->paginate(10);

            // Duyệt qua từng bài viết để xử lý việc gắn kèm dữ liệu các sản phẩm điện thoại
            $posts->getCollection()->transform(function ($post) {
                return $this->attachLinkedProducts($post);
            });

            return response()->json(['success' => true, 'data' => $posts]);
        } catch (\Exception $e) {
            // Trả về lỗi hệ thống dưới dạng JSON
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Lấy danh sách bài viết cho giao diện quản lý (Admin xem hết, Shop chỉ xem bài của mình).
     * Tham số đầu vào: Request $request.
     * Giá trị trả về: JSON danh sách bài viết kèm thông tin shop và sản phẩm đính kèm.
     */
    public function manageIndex(Request $request)
    {
        $user = auth()->user();
        $query = NewsPost::with('shop');

        // Logic phân quyền: Nếu tài khoản là Shop, chỉ truy vấn các bài viết thuộc sở hữu của Shop đó
        if ($user->role === 'shop') {
            if (!$user->shop) return response()->json(['success' => true, 'data' => []]);
            $query->where('shop_id', $user->shop->id);
        }

        $posts = $query->latest()->get();

        // Xử lý nạp dữ liệu sản phẩm dựa trên thẻ tag nhúng trong nội dung bài viết
        $posts->transform(function ($post) {
            return $this->attachLinkedProducts($post);
        });

        return response()->json(['success' => true, 'data' => $posts]);
    }

    /**
     * Chức năng: Bóc tách mã sản phẩm từ nội dung và nạp dữ liệu Model Phone tương ứng.
     * Tham số đầu vào: $post (Đối tượng bài viết cần xử lý).
     * Giá trị trả về: Đối tượng bài viết đã được gắn thêm thuộc tính linked_products.
     */
    private function attachLinkedProducts($post) {
        // Sử dụng Regex để tìm chuỗi định dạng [[products:ID1,ID2]] trong nội dung
        preg_match('/\[\[products:(.*?)\]\]/', $post->content, $matches);
        $productIds = isset($matches[1]) ? explode(',', $matches[1]) : [];

        // Nếu tìm thấy ID sản phẩm, truy vấn lấy thông tin chi tiết từ bảng phones
        if (!empty($productIds)) {
            $post->linked_products = Phone::whereIn('id', $productIds)->get();
        } else {
            $post->linked_products = [];
        }
        return $post;
    }

    /**
     * Chức năng: Khởi tạo bài viết bản tin mới kèm theo việc lưu trữ hình ảnh.
     * Tham số đầu vào: Request $request (Tiêu đề, Nội dung, Mảng tệp tin ảnh).
     * Giá trị trả về: JSON thông tin bài viết vừa được tạo.
     */
    public function store(Request $request)
    {
        // Xác thực dữ liệu đầu vào và giới hạn định dạng/dung lượng ảnh
        $request->validate([
            'title' => 'required|string',
            'content' => 'required|string',
            'news_images.*' => 'image|mimes:jpeg,png,jpg|max:2048'
        ]);

        $imagePaths = [];
        // Xử lý lưu từng tệp ảnh vào thư mục 'news' trong ổ đĩa public
        if ($request->hasFile('news_images')) {
            foreach ($request->file('news_images') as $image) {
                $path = $image->store('news', 'public');
                $imagePaths[] = $path;
            }
        }

        // Tạo bản ghi mới, lưu danh sách đường dẫn ảnh dưới dạng chuỗi JSON
        $news = NewsPost::create([
            'shop_id' => auth()->user()->shop->id,
            'title' => $request->title,
            'content' => $request->content,
            'images' => json_encode($imagePaths),
        ]);

        return response()->json(['success' => true, 'data' => $news]);
    }

    /**
     * Chức năng: Hiển thị chi tiết một bài viết cụ thể và các sản phẩm liên quan.
     * Tham số đầu vào: $id (Mã ID của bài viết).
     * Giá trị trả về: JSON cấu trúc dữ liệu bài viết, tác giả, hình ảnh, bình luận và object sản phẩm.
     */
public function show($id)
    {
        try {
            // Nạp bài viết kèm theo thông tin shop (author), và bình luận
            $news = NewsPost::with(['shop', 'comments.user'])->findOrFail($id);

            // Bóc tách sản phẩm đính kèm từ nội dung (Dùng -> thay vì .)
            $attachedProducts = [];
            preg_match('/\[\[products:(.*?)\]\]/', $news->content, $matches);

            if (!empty($matches[1])) {
                $productIds = explode(',', $matches[1]);
                $attachedProducts = Phone::whereIn('id', $productIds)
                    ->select('id', 'title', 'price', 'discount_price', 'thumbnail', 'slug')
                    ->get();
            }

            // Xử lý mảng ảnh (giải mã JSON nếu cần)
            $images = is_string($news->images) ? json_decode($news->images, true) : $news->images;

            return response()->json([
                'success' => true,
                'data' => [
                    'id' => $news->id,
                    'title' => $news->title,
                    'content' => $news->content,
                    'author' => [
                        'name' => $news->shop->name ?? 'Admin',
                        'avatar' => $news->shop->avatar ?? null,
                    ],
                    'images' => $images,
                    'comments' => $news->comments,
                    'attached_products' => $attachedProducts,
                    'created_at' => $news->created_at->format('Y-m-d H:i:s'),
                ]
            ], 200);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Lỗi: ' . $e->getMessage()
            ], 404);
        }
    }

    /**
     * Chức năng: Cập nhật thông tin bài viết và thay thế hình ảnh cũ bằng hình ảnh mới.
     * Tham số đầu vào: Request $request, $id.
     * Giá trị trả về: JSON dữ liệu bài viết mới nhất sau khi cập nhật.
     */
    public function update(Request $request, $id)
{
    try {
        $news = NewsPost::findOrFail($id);
        $user = $request->user();

        // Kiểm tra quyền: Chỉ Admin hoặc chủ sở hữu của Shop đăng bài mới được phép chỉnh sửa
        $shopId = $user->shop ? $user->shop->id : null;
        if ($user->role !== 'admin' && $news->shop_id !== $shopId) {
            return response()->json(['success' => false, 'message' => 'Bạn không có quyền!'], 403);
        }

        $request->validate([
            'title' => 'required|string',
            'content' => 'required|string',
            'news_images.*' => 'image|mimes:jpeg,png,jpg|max:2048'
        ]);

        $updateData = [
            'title' => $request->title,
            'content' => $request->content,
        ];

        // Nếu người dùng tải lên ảnh mới, thực hiện quy trình dọn dẹp ảnh cũ và lưu ảnh mới
        if ($request->hasFile('news_images')) {
            // Giải mã danh sách ảnh cũ và xóa tệp tin vật lý khỏi ổ đĩa
            $oldImages = is_string($news->images) ? json_decode($news->images, true) : $news->images;
            $oldImages = (array)($oldImages ?? []);
            foreach ($oldImages as $img) {
                Storage::disk('public')->delete($img);
            }

            // Lưu trữ các tệp ảnh mới
            $imagePaths = [];
            foreach ($request->file('news_images') as $image) {
                $imagePaths[] = $image->store('news', 'public');
            }
            $updateData['images'] = json_encode($imagePaths);
        }

        // Thực hiện cập nhật đồng loạt các trường thông tin vào cơ sở dữ liệu
        $news->update($updateData);

        return response()->json(['success' => true, 'data' => $news->fresh()]);
    } catch (\Exception $e) {
        return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
    }
}

    /**
     * Chức năng: Xóa bỏ hoàn toàn bài viết và các hình ảnh liên quan khỏi hệ thống.
     * Tham số đầu vào: $id (ID bài viết cần xóa).
     * Giá trị trả về: JSON xác nhận việc xóa thành công.
     */
    public function destroy($id)
    {
        $user = auth()->user();
        $news = NewsPost::findOrFail($id);

        // Chốt bảo mật phân quyền trước khi thực hiện hành động xóa
        if ($user->role !== 'admin' && $news->shop_id !== $user->shop->id) {
            return response()->json(['success' => false, 'message' => 'Không có quyền xóa bài này!'], 403);
        }

        // Xử lý giải mã JSON để lấy danh sách ảnh cần xóa khỏi bộ nhớ server
        $imagesData = $news->images;
        $images = is_string($imagesData) ? json_decode($imagesData, true) : $imagesData;
        $images = $images ?? [];

        foreach ($images as $img) {
            Storage::disk('public')->delete($img);
        }

        // Xóa bản ghi bài viết khỏi bảng news_posts
        $news->delete();
        return response()->json(['success' => true, 'message' => 'Đã xóa tin!']);
    }

    /**
     * Chức năng: Lưu trữ bình luận mới hoặc phản hồi cho bài viết.
     * Tham số đầu vào: Request $request (content, parent_id), $postId.
     * Giá trị trả về: JSON thông tin bình luận kèm theo dữ liệu người dùng vừa đăng.
     */
    public function storeComment(Request $request, $postId)
{
    // Nội dung bình luận là bắt buộc, parent_id dùng cho trường hợp trả lời bình luận khác
    $request->validate([
        'content' => 'required|string',
        'parent_id' => 'nullable|exists:news_comments,id'
    ]);

    try {
        $comment = NewsComment::create([
            'post_id'   => (int)$postId,
            'user_id'   => auth()->id(),
            'content'   => $request->content,
            'parent_id' => $request->parent_id
        ]);

        // Tăng bộ đếm tổng số bình luận trong bài viết để tối ưu hiển thị ở trang danh sách
        NewsPost::where('id', $postId)->increment('comments_count');

        return response()->json([
            'success' => true,
            'data' => $comment->load('user')
        ]);
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => 'Lỗi SQL: ' . $e->getMessage()
        ], 500);
    }
}

    /**
     * Chức năng: Xử lý hành động Like hoặc Bỏ Like (Toggle) của người dùng đối với bài viết.
     * Tham số đầu vào: Request $request, $id (Mã ID bài viết).
     * Giá trị trả về: JSON trạng thái hiện tại (Đã like hay chưa) và tổng số lượng lượt Like mới nhất.
     */
    public function likePost(Request $request, $id)
    {
        $user = $request->user();
        $post = NewsPost::findOrFail($id);

        // Truy vấn thủ công vào bảng trung gian để kiểm tra sự tồn tại của lượt tương tác
        $like = DB::table('news_post_likes')
            ->where('user_id', $user->id)
            ->where('news_post_id', $id)
            ->first();

        if ($like) {
            // Nếu đã tồn tại lượt Like: Thực hiện xóa lượt Like và giảm bộ đếm của bài viết
            DB::table('news_post_likes')->where('id', $like->id)->delete();
            $post->decrement('likes_count');
            return response()->json(['success' => true, 'is_liked' => false, 'likes_count' => $post->likes_count]);
        } else {
            // Nếu chưa tồn tại: Chèn bản ghi mới và tăng bộ đếm tổng lượt Like
            DB::table('news_post_likes')->insert([
                'user_id' => $user->id,
                'news_post_id' => $id,
                'created_at' => now()
            ]);
            $post->increment('likes_count');
            return response()->json(['success' => true, 'is_liked' => true, 'likes_count' => $post->likes_count]);
        }
    }
}
