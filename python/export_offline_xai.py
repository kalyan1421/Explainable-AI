import os

# --- CRITICAL FIX: Disable GPU for Conversion ---
# This forces TensorFlow to use CPU, avoiding the Metal/LLVM crash on Mac
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
import tensorflow as tf

# Try to disable GPU visibility programmatically as a backup
try:
    tf.config.set_visible_devices([], 'GPU')
    print("✅ Disabled GPU for TFLite conversion stability")
except:
    pass

import numpy as np
import json

def export_model():
    # 1. Load your existing trained model
    MODEL_PATH = 'models/pneumonia_model.h5' 
    if not os.path.exists(MODEL_PATH):
        print(f"❌ Error: {MODEL_PATH} not found. Train the model first.")
        return

    try:
        model = tf.keras.models.load_model(MODEL_PATH)
        print("✅ Loaded Keras Model")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # 2. Identify The Last Convolutional Layer
    last_conv_layer = None
    for layer in reversed(model.layers):
        try:
            # Check if layer output is 4D: (Batch, Height, Width, Channels)
            if len(layer.output.shape) == 4:
                last_conv_layer = layer.name
                print(f"🔍 Found Feature Layer: {last_conv_layer} {layer.output.shape}")
                break
        except AttributeError:
            continue

    if last_conv_layer is None:
        print("❌ Critical Error: Could not find a 4D Convolutional layer.")
        return

    # 3. Create Multi-Output Model
    # Output 1: Prediction [1, 1]
    # Output 2: Feature Map [1, 7, 7, 1280]
    multi_out_model = tf.keras.models.Model(
        inputs=model.input,
        outputs=[model.output, model.get_layer(last_conv_layer).output]
    )

    # 4. Prepare Concrete Function (The Fix for LLVM Error)
    # We define exactly what the input looks like so TFLite doesn't have to guess
    run_model = tf.function(lambda x: multi_out_model(x))
    
    # Create a concrete function with a fixed input signature
    # Assuming input is float32 and shape (1, 224, 224, 3)
    concrete_func = run_model.get_concrete_function(
        tf.TensorSpec(multi_out_model.inputs[0].shape, multi_out_model.inputs[0].dtype)
    )

    # 5. Convert to TFLite
    print("⏳ Converting to TFLite (via Concrete Function)...")
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # OPTIONAL: Optimizations (Try commenting this out if it still fails)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    
    try:
        tflite_model = converter.convert()
    except Exception as e:
        print("⚠️ Optimization failed, trying without optimization...")
        converter.optimizations = []
        tflite_model = converter.convert()

    # Ensure assets folder exists
    assets_dir = '../explainable_ai/assets'
    os.makedirs(assets_dir, exist_ok=True)

    tflite_path = os.path.join(assets_dir, 'pneumonia_xai_model.tflite')
    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f"✅ Saved Multi-Output TFLite Model: {tflite_path}")

    # 6. Extract & Save Classifier Weights
    dense_layer = model.layers[-1] 
    weights_list = []

    try:
        weights = dense_layer.get_weights()[0] # Shape: (1280, 1) or (1280, 2)
        
        if len(weights.shape) > 1 and weights.shape[1] > 1:
            # If binary classification (2 output nodes), take the "Pneumonia" column (usually index 1)
            weights_list = weights[:, 1].flatten().tolist()
        else:
            # If binary classification (1 output node)
            weights_list = weights.flatten().tolist()

        json_path = os.path.join(assets_dir, 'pneumonia_weights.json')
        with open(json_path, 'w') as f:
            json.dump({'weights': weights_list}, f)
        print(f"✅ Saved Weights to JSON: {json_path}")

    except Exception as e:
        print(f"❌ Error extracting weights: {e}")

if __name__ == "__main__":
    export_model()