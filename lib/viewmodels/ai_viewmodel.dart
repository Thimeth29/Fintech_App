import 'package:flutter/foundation.dart';
import '../services/ai_service.dart';

class AiViewModel extends ChangeNotifier {
  final _aiService = AiService();
  
  bool isLoading = false;
  Map<String, dynamic>? recommendationData;
  String? errorMessage;

  Future<void> fetchGuidance() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      recommendationData = await _aiService.getRecommendation();
    } catch (e) {
      errorMessage = "Failed to connect to AI Advisor.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
