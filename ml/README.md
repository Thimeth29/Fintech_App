# Expenditure prediction model

This folder holds the source Keras artifacts for the LSTM that predicts
next month's total expenditure from the last 3 months' totals:

- `expenditure_lstm_model.keras` — the trained model (Input(3,1) ->
  LSTM(64) -> Dropout -> LSTM(32) -> Dropout -> Dense(16, relu) ->
  Dense(1, linear); trained with MinMax-scaled inputs).
- `expenditure_scaler.pkl` — the `sklearn.preprocessing.MinMaxScaler` fit
  on the training data (`data_min_=7925498.79`, `data_max_=8157745.74`,
  `feature_range=(0, 1)`).
- `convert_model_to_tflite.py` — one-time conversion script.

## Why a conversion step is needed

Flutter/Dart runs on-device via TensorFlow Lite (`tflite_flutter`), not
raw Keras/`.keras` files. This repo doesn't ship a pre-converted
`.tflite` because that requires the exact TensorFlow build the model was
trained with — safest to generate it yourself, once:

```bash
cd ml
pip install tensorflow
python convert_model_to_tflite.py
```

That writes `assets/models/expenditure_lstm_model.tflite`. Then from the
project root:

```bash
flutter pub get
flutter run
```

## How the scaler is applied

The Dart side (`lib/services/expenditure_prediction_service.dart`)
reimplements the same `MinMaxScaler` math using the constants above —
no need to ship or parse the `.pkl` file on-device:

```
scaled = (value - data_min_) / (data_max_ - data_min_)
value  = scaled * (data_max_ - data_min_) + data_min_
```

If you retrain the model on new data, re-run `joblib.load` on the new
scaler, copy the new `data_min_` / `data_max_` values into
`ExpenditurePredictionService`, and re-run the conversion script.
