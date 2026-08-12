// lib/services/expenditure_prediction_service_io.dart
//
// Real, on-device implementation — used on Android/iOS/desktop, where
// dart:ffi (which tflite_flutter depends on) is available. Never
// imported on Flutter Web; see expenditure_prediction_service.dart and
// expenditure_prediction_service_stub.dart for the platform switch.
//
// Runs the trained expenditure_lstm_model.keras (converted to TFLite —
// see ml/convert_model_to_tflite.py) on-device to forecast next month's
// total expenditure from the user's last 3 months of spending.
//
// Model shape: input (1, 3, 1) -> LSTM(64) -> Dropout -> LSTM(32) ->
// Dropout -> Dense(16, relu) -> Dense(1, linear), trained on data scaled
// with a MinMaxScaler(feature_range=(0, 1)). The scaler constants below
// are copied verbatim from the fitted expenditure_scaler.pkl
// (data_min_=7925498.79, data_max_=8157745.74) so we don't need to ship
// or parse the pickle file on-device — see ml/README.md if the model is
// ever retrained on new data and these need updating.

import 'dart:developer' as developer;
import 'package:tflite_flutter/tflite_flutter.dart';

class ExpenditurePredictionService {
  static const String _modelAsset = 'assets/models/expenditure_lstm_model.tflite';

  // MinMaxScaler constants fit during training (from expenditure_scaler.pkl).
  static const double _dataMin = 7925498.79;
  static const double _dataMax = 8157745.74;

  Interpreter? _interpreter;
  bool _loadFailed = false;

  /// True once the .tflite asset has been bundled (see ml/README.md) and
  /// loaded successfully. Callers should check this before predicting and
  /// show a "prediction unavailable" state otherwise, rather than crash.
  bool get isAvailable => _interpreter != null;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null || _loadFailed) return;
    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);
    } catch (e) {
      // Most likely cause: the .tflite file hasn't been generated yet
      // (see ml/README.md) or wasn't added to pubspec.yaml assets.
      _loadFailed = true;
      developer.log(
        'ExpenditurePredictionService: could not load $_modelAsset ($e). '
        'Run ml/convert_model_to_tflite.py and rebuild.',
        name: 'ExpenditurePredictionService',
      );
    }
  }

  double _scale(double value) => (value - _dataMin) / (_dataMax - _dataMin);

  double _unscale(double scaled) => scaled * (_dataMax - _dataMin) + _dataMin;

  /// Predicts next month's total expenditure given the last 3 months'
  /// totals (oldest first, newest last), in the same currency unit the
  /// model was trained on. Returns null if the model isn't bundled or
  /// [lastThreeMonthTotals] doesn't have exactly 3 values.
  Future<double?> predictNextMonth(List<double> lastThreeMonthTotals) async {
    if (lastThreeMonthTotals.length != 3) return null;

    await _ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    // Input shape (1, 3, 1): batch of 1, 3 timesteps, 1 feature.
    final input = [
      lastThreeMonthTotals.map((v) => [_scale(v)]).toList(),
    ];
    // Output shape (1, 1): the single next-period prediction.
    final output = [
      [0.0],
    ];

    try {
      interpreter.run(input, output);
      return _unscale(output[0][0]);
    } catch (e) {
      developer.log(
        'ExpenditurePredictionService: inference failed ($e).',
        name: 'ExpenditurePredictionService',
      );
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
