// lib/services/expenditure_prediction_service.dart
//
// Platform switch: tflite_flutter (used for on-device LSTM inference)
// depends on dart:ffi, which doesn't exist on Flutter Web. Every caller
// imports *this* file and uses `ExpenditurePredictionService` — Dart
// picks which implementation actually gets compiled in based on which
// platform libraries are available:
//   - dart:io exists (Android/iOS/desktop) -> the real, tflite-backed
//     implementation in expenditure_prediction_service_io.dart runs.
//   - otherwise (web) -> the stub in
//     expenditure_prediction_service_stub.dart runs, which always
//     reports isAvailable == false instead of crashing at compile time.
export 'expenditure_prediction_service_stub.dart'
    if (dart.library.io) 'expenditure_prediction_service_io.dart';
