from pathlib import Path
import tensorflow as tf

BASE_DIR = Path(__file__).resolve().parents[1]

keras_path = BASE_DIR / "models" / "onion_health_mobilenetv2_best.keras"
tflite_path = BASE_DIR / "models" / "onion_health_mobilenetv2.tflite"

print("STEP 1: Loading Keras model...", flush=True)

model = tf.keras.models.load_model(
    str(keras_path),
    compile=False,
)

print("STEP 2: Keras model loaded", flush=True)
print(f"Input: {model.input_shape}", flush=True)
print(f"Output: {model.output_shape}", flush=True)

print("STEP 3: Creating TFLite converter...", flush=True)

converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = []

print("STEP 4: Starting conversion...", flush=True)

tflite_model = converter.convert()

print("STEP 5: Conversion successful", flush=True)

tflite_path.write_bytes(tflite_model)

print(f"STEP 6: Written to: {tflite_path}", flush=True)
print(
    f"STEP 7: Size: {tflite_path.stat().st_size / (1024 * 1024):.2f} MB",
    flush=True,
)