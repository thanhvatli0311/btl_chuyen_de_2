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
     * Chức năng: Lấy danh sách toàn bộ bản tin công khai.
     * ✅ FIX: Sử dụng paginate() để tránh tải quá nhiều data một lúc gây chậm App[cite: 20].
     */
    public function index()
    {
        try {
            $userId = request()->user('sanctum')?->id;

           $posts = NewsPost::with(['user', 'shop', 'comments.user'])
                ->when($userId, function($q) use ($userId) {
                    $q->withExists(['likes as is_liked' => function($query) use ($userId) {
                        $query->where('user_id', $userId);
                    }]);
                })
                ->latest()
                ->paginate(10);

            // ✅ FIX: Thu thập tất cả ID sản phẩm trước rồi mới Query 1 lần (Tránh N+1)
            $allProductIds = [];
            foreach ($posts as $post) {
                preg_match('/\[\[products:(.*?)\]\]/', $post->content, $matches);
                if (!empty($matches[1])) {
                    $allProductIds = array_merge($allProductIds, explode(',', $matches[1]));
                }
            }
            $products = Phone::whereIn('id', array_unique($allProductIds))->get()->keyBy('id');

            $posts->getCollection()->transform(function ($post) use ($products) {
                preg_match('/\[\[products:(.*?)\]\]/', $post->content, $matches);
                $ids = !empty($matches[1]) ? explode(',', $matches[1]) : [];
                $post->linked_products = collect($ids)->map(fn($id) => $products->get($id))->filter();
                return $post;
            });

            return response()->json(['success' => true, 'data' => $posts]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Lấy danh sách bài viết cho giao diện quản lý.
     */
    public function manageIndex(Request $request)
    {
        $user = auth()->user();
        $query = NewsPost::with(['user', 'shop']);

        if ($user->role === 'shop') {
            if (!$user->shop) return response()->json(['success' => true, 'data' => []]);
            // ✅ FIX: Đồng bộ dùng user_id vì FK trỏ về bảng users
            $query->where('shop_id', $user->id);
        }

        $posts = $query->latest()->get();

        // Tối ưu gắn sản phẩm (tương tự hàm index)
        $posts->transform(function ($post) {
             preg_match('/\[\[products:(.*?)\]\]/', $post->content, $matches);
             $productIds = isset($matches[1]) ? explode(',', $matches[1]) : [];
             $post->linked_products = !empty($productIds) ? Phone::whereIn('id', $productIds)->get() : [];
             return $post;
        });

        return response()->json(['success' => true, 'data' => $posts]);
    }

    /**
     * Chức năng: Khởi tạo bài viết bản tin mới.
     * ✅ FIX: Chặn lỗi 500 Integrity Constraint bằng cách dùng auth()->id()[cite: 9, 20].
     */
    public function store(Request $request)
    {
        $request->validate([
            'title' => 'required|string|max:255',
            'content' => 'required|string',
            'news_images.*' => 'image|mimes:jpeg,png,jpg|max:2048'
        ]);

        $imagePaths = [];
        if ($request->file('news_images')) {
            foreach ($request->file('news_images') as $image) {
                $imagePaths[] = $image->store('news', 'public');
            }
        }

        $news = NewsPost::create([
            'shop_id' => auth()->id(), // Trỏ về users.id để khớp Database[cite: 9, 20]
            'title'   => $request->title,
            'content' => $request->content,
            'images'  => $imagePaths,
            'status'  => 'active'
        ]);

        return response()->json(['success' => true, 'data' => $news], 201);
    }

    /**
     * Chức năng: Cập nhật bài viết.
     */
    public function update(Request $request, $id)
    {
        try {
            $news = NewsPost::findOrFail($id);
            $user = $request->user();

            if ($user->role !== 'admin' && $news->shop_id !== $user->id) {
                return response()->json(['success' => false, 'message' => 'Bạn không có quyền!'], 403);
            }

            $request->validate([
                'title' => 'required|string|max:255',
                'content' => 'required|string',
            ]);

            $updateData = ['title' => $request->title, 'content' => $request->content];

            if ($request->hasFile('news_images')) {
                // Xóa ảnh cũ vật lý
                $oldImages = is_string($news->images) ? json_decode($news->images, true) : $news->images;
                foreach ((array)($oldImages ?? []) as $img) {
                    Storage::disk('public')->delete($img);
                }

                $imagePaths = [];
                foreach ($request->file('news_images') as $image) {
                    $imagePaths[] = $image->store('news', 'public');
                }
                $updateData['images'] = $imagePaths;
            }

            $news->update($updateData);
            return response()->json(['success' => true, 'data' => $news->fresh()]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function destroy($id)
    {
        $user = auth()->user();
        $news = NewsPost::findOrFail($id);

        if ($user->role !== 'admin' && $news->shop_id !== $user->id) {
            return response()->json(['success' => false, 'message' => 'Không có quyền!'], 403);
        }

        $images = is_string($news->images) ? json_decode($news->images, true) : $news->images;
        foreach ((array)($images ?? []) as $img) {
            Storage::disk('public')->delete($img);
        }

        $news->delete();
        return response()->json(['success' => true, 'message' => 'Đã xóa!']);
    }

    public function storeComment(Request $request, $postId)
    {
        $request->validate(['content' => 'required|string', 'parent_id' => 'nullable|exists:news_comments,id']);
        try {
            $comment = NewsComment::create([
                'post_id'   => (int)$postId,
                'user_id'   => auth()->id(),
                'content'   => $request->content,
                'parent_id' => $request->parent_id
            ]);
            NewsPost::where('id', $postId)->increment('comments_count');
            return response()->json(['success' => true, 'data' => $comment->load('user')]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    public function likePost(Request $request, $id)
    {
        $user = $request->user();
        $post = NewsPost::findOrFail($id);
        $like = DB::table('news_post_likes')->where('user_id', $user->id)->where('news_post_id', $id)->first();

        if ($like) {
            DB::table('news_post_likes')->where('id', $like->id)->delete();
            $post->decrement('likes_count');
            return response()->json(['success' => true, 'is_liked' => false, 'likes_count' => max(0, $post->likes_count)]);
        } else {
            DB::table('news_post_likes')->insert(['user_id' => $user->id, 'news_post_id' => $id, 'created_at' => now()]);
            $post->increment('likes_count');
            return response()->json(['success' => true, 'is_liked' => true, 'likes_count' => $post->likes_count]);
        }
    }
}
