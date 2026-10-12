"""
One-time conversion script: expenditure_lstm_model.keras -> assets/models/expenditure_lstm_model.tflite

Why this exists: Flutter/Dart can't load a .keras file directly. The app
runs the model on-device via tflite_flutter, which needs the TensorFlow
Lite format instead. This script does that conversion once, on your own
machine (wherever you trained the model, since that's where TensorFlow
is already installed) -- it is NOT run as part of the Flutter build.

Model recap (read from this project's ml/expenditure_lstm_model.keras):
    Input:  (batch, 3, 1)  -> last 3 periods' total expenditure, scaled
    LSTM(64, return_sequences=True) -> Dropout(0.2)
    LSTM(32) -> Dropout(0.2)
    Dense(16, relu) -> Dense(1, linear)  -> next period's total, scaled

Usage:
    pip install tensorflow
    python ml/convert_model_to_tflite.py

Output:
    assets/models/expenditure_lstm_model.tflite
"""

import pathlib
import tensorflow as tf

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_MODEL = ROOT / "ml" / "expenditure_lstm_model.keras"
OUT_DIR = ROOT / "assets" / "models"
OUT_FILE = OUT_DIR / "expenditure_lstm_model.tflite"


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Loading {SRC_MODEL} ...")
    model = tf.keras.models.load_model(SRC_MODEL)
    model.summary()

    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # LSTM ops need this resolver combo to convert cleanly.
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    tflite_model = converter.convert()

    OUT_FILE.write_bytes(tflite_model)
    print(f"Wrote {OUT_FILE} ({len(tflite_model) / 1024:.1f} KB)")
    print(
        "\nDone. Run `flutter pub get` and rebuild the app - "
        "ExpenditurePredictionService will pick this file up automatically."
    )


if __name__ == "__main__":
    main()
