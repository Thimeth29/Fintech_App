// lib/services/expenditure_prediction_service_stub.dart
//
// Web fallback — tflite_flutter depends on dart:ffi, which doesn't exist
// in a browser, so on-device LSTM inference simply isn't possible on
// Flutter Web. This stub keeps the app compiling and running there by
// matching ExpenditurePredictionService's public API exactly, but always
// reports itself unavailable instead of crashing.
//
// See expenditure_prediction_service.dart for the platform switch and
// expenditure_prediction_service_io.dart for the real implementation.

class ExpenditurePredictionService {
  bool get isAvailable => false;

  Future<double?> predictNextMonth(List<double> lastThreeMonthTotals) async {
    return null;
  }

  void dispose() {}
}
