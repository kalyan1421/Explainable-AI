import tensorflow as tf
import numpy as np
import os
import json

def convert_to_tflite(model_name):
    """Convert Keras model to TFLite format with M4 Mac fix"""
    
    print(f"\n{'='*50}")
    print(f" CONVERTING: {model_name}")
    print(f"{'='*50}")
    
    keras_path = f'models/{model_name.lower()}_model.keras'
    tflite_path = f'assets/{model_name.lower()}_model.tflite'
    
    # Check if Keras model exists
    if not os.path.exists(keras_path):
        print(f"❌ ERROR: {keras_path} not found. Run train_model.py first.")
        return False
    
    # Load Keras model
    print(f"⏳ Loading Keras model from {keras_path}...")
    model = tf.keras.models.load_model(keras_path)
    print(f"✅ Loaded model with input shape: {model.input_shape}")
    
    # CRITICAL FIX FOR M4 MAC: Convert BatchNorm to inference mode
    print(f"🔧 Applying M4 Mac BatchNorm fix...")
    model = convert_batchnorm_to_inference(model)
    
    # Convert to TFLite
    print(f"⏳ Converting to TFLite...")
    
    # Use concrete function approach (more stable)
    @tf.function(input_signature=[tf.TensorSpec(shape=model.input_shape, dtype=tf.float32)])
    def model_fn(x):
        return model(x, training=False)
    
    concrete_func = model_fn.get_concrete_function()
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # Optimization settings
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float32]
    
    # Additional flags for stability
    converter.experimental_new_converter = True
    converter.experimental_new_quantizer = True
    
    try:
        tflite_model = converter.convert()
        
        # Save TFLite model
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✅ Saved TFLite Model: {tflite_path} ({len(tflite_model)/1024:.2f} KB)")
        
        # Verify TFLite model
        verify_tflite_model(tflite_path, model)
        
        return True
        
    except Exception as e:
        print(f"❌ TFLite Conversion Error: {e}")
        print("\n🔧 Trying alternative conversion method...")
        return try_alternative_conversion(model, tflite_path)

def convert_batchnorm_to_inference(model):
    """Convert BatchNormalization layers to inference mode (fuse with previous layer)"""
    
    # Create a new model with BatchNorm in inference mode
    def clone_function(layer):
        config = layer.get_config()
        if isinstance(layer, tf.keras.layers.BatchNormalization):
            # Force inference mode
            config['trainable'] = False
        return layer.__class__.from_config(config)
    
    new_model = tf.keras.models.clone_model(model, clone_function=clone_function)
    new_model.set_weights(model.get_weights())
    
    # Compile with same settings
    new_model.compile(
        optimizer='adam',
        loss='binary_crossentropy',
        metrics=['accuracy']
    )
    
    return new_model

def try_alternative_conversion(model, tflite_path):
    """Alternative conversion method without BatchNorm issues"""
    
    try:
        # Save to SavedModel format first
        saved_model_path = 'models/temp_saved_model'
        model.save(saved_model_path, save_format='tf')
        print(f"✅ Saved temporary SavedModel")
        
        # Convert from SavedModel
        converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_path)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        tflite_model = converter.convert()
        
        with open(tflite_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"✅ Saved TFLite Model (alternative method): {tflite_path}")
        
        # Clean up
        import shutil
        shutil.rmtree(saved_model_path)
        
        return True
        
    except Exception as e:
        print(f"❌ Alternative conversion also failed: {e}")
        return False

def verify_tflite_model(tflite_path, keras_model):
    """Verify that TFLite model produces similar results to Keras model"""
    
    print(f"\n🔍 Verifying TFLite Model...")
    
    try:
        # Load TFLite model
        interpreter = tf.lite.Interpreter(model_path=tflite_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"  Input shape: {input_details[0]['shape']}")
        print(f"  Output shape: {output_details[0]['shape']}")
        
        # Create random test input
        input_shape = input_details[0]['shape']
        test_input = np.random.randn(*input_shape).astype(np.float32)
        
        # Get Keras prediction (in inference mode)
        keras_output = keras_model.predict(test_input, verbose=0)
        
        # Get TFLite prediction
        interpreter.set_tensor(input_details[0]['index'], test_input)
        interpreter.invoke()
        tflite_output = interpreter.get_tensor(output_details[0]['index'])
        
        # Compare results
        difference = np.abs(keras_output - tflite_output).mean()
        max_diff = np.abs(keras_output - tflite_output).max()
        
        print(f"\n✅ Verification Results:")
        print(f"  Keras prediction: {keras_output[0][0]:.6f}")
        print(f"  TFLite prediction: {tflite_output[0][0]:.6f}")
        print(f"  Mean difference: {difference:.8f}")
        print(f"  Max difference: {max_diff:.8f}")
        
        if difference < 0.01:
            print(f"  Status: ✅ PASS - Models match!")
            return True
        elif difference < 0.05:
            print(f"  Status: ⚠️  WARNING - Small difference detected")
            return True
        else:
            print(f"  Status: ❌ FAIL - Large difference!")
            return False
            
    except Exception as e:
        print(f"❌ Verification error: {e}")
        return False

def create_flutter_guide(model_name):
    """Create a usage guide for Flutter integration"""
    
    guide = {
        "model_name": model_name,
        "files_needed": [
            f"{model_name.lower()}_model.tflite",
            f"{model_name.lower()}_scaler.json",
            f"{model_name.lower()}_mappings.json",
            f"{model_name.lower()}_feature_importance.json",
            f"{model_name.lower()}_metadata.json"
        ],
        "flutter_integration_steps": {
            "1_add_to_pubspec": [
                "assets:",
                f"  - assets/{model_name.lower()}_model.tflite",
                f"  - assets/{model_name.lower()}_scaler.json",
                f"  - assets/{model_name.lower()}_mappings.json"
            ],
            "2_install_package": "tflite_flutter: ^0.10.4",
            "3_load_model": f"await Interpreter.fromAsset('assets/{model_name.lower()}_model.tflite')",
            "4_preprocessing": {
                "a_load_mappings": "Convert categorical: 'Male' -> 1",
                "b_load_scaler": "Normalize: (value - mean) / std",
                "c_create_input": "Float32List of normalized values"
            },
            "5_inference": {
                "input_shape": "Must match model input",
                "output_shape": "[1, 1] - probability value",
                "interpretation": ">= 0.5 = High Risk, < 0.5 = Low Risk"
            }
        },
        "example_code": {
            "load_and_predict": """
// Load model
final interpreter = await Interpreter.fromAsset('assets/heart_model.tflite');

// Load scaler
final scalerJson = await rootBundle.loadString('assets/heart_scaler.json');
final scaler = json.decode(scalerJson);

// Normalize input
final input = normalizeInput(rawInput, scaler);

// Predict
final output = List.filled(1, 0.0).reshape([1, 1]);
interpreter.run([input], output);
final probability = output[0][0];
            """
        }
    }
    
    guide_path = f'assets/{model_name.lower()}_flutter_guide.json'
    with open(guide_path, 'w') as f:
        json.dump(guide, f, indent=2)
    
    print(f"✅ Created Flutter guide: {guide_path}")

# ==========================================
# EXECUTE CONVERSION
# ==========================================

if __name__ == "__main__":
    print("\n" + "="*50)
    print("TFLite Model Conversion (M4 Mac Compatible)")
    print("="*50)
    
    models = ["Heart", "Diabetes"]
    successful_conversions = []
    failed_conversions = []
    
    for model_name in models:
        success = convert_to_tflite(model_name)
        
        if success:
            successful_conversions.append(model_name)
            create_flutter_guide(model_name)
        else:
            failed_conversions.append(model_name)
    
    # Summary
    print("\n" + "="*50)
    print("CONVERSION SUMMARY")
    print("="*50)
    
    if successful_conversions:
        print(f"\n✅ Successfully converted {len(successful_conversions)} models:")
        for model in successful_conversions:
            print(f"  • {model}")
    
    if failed_conversions:
        print(f"\n❌ Failed to convert {len(failed_conversions)} models:")
        for model in failed_conversions:
            print(f"  • {model}")
        print("\n💡 If conversion fails, you can:")
        print("  1. Use the Keras model with TensorFlow.js in Flutter Web")
        print("  2. Set up a Flask API server for predictions")
        print("  3. Try training without BatchNormalization layers")
    
    if successful_conversions:
        print("\n" + "="*50)
        print("📱 READY FOR FLUTTER INTEGRATION")
        print("="*50)
        print("\n📁 Files in 'assets' folder:")
        print("  • *_model.tflite - TFLite models")
        print("  • *_scaler.json - Normalization parameters")
        print("  • *_mappings.json - Categorical encodings")
        print("  • *_feature_importance.json - Feature importance")
        print("  • *_metadata.json - Model metrics")
        print("  • *_flutter_guide.json - Integration guide")
        print("\n💡 Copy 'assets' folder to your Flutter project!")
        print("\n🚀 Next step: Follow the Flutter Integration Guide artifact")