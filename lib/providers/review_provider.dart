import '../data/models/review_model.dart';
import 'base_provider.dart';

class ReviewProvider extends BaseProvider {
  List<ReviewModel> _reviews = [];
  List<ReviewModel> get reviews => _reviews;

  Future<void> fetchReviews(int phoneId) async {
    final res = await apiService.getReviews(phoneId);
    if (res.data['success']) {
      _reviews = (res.data['data'] as List).map((e) => ReviewModel.fromJson(e)).toList();
      notifyListeners();
    }
  }
}