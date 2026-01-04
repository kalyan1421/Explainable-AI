import tensorflow as tf
import numpy as np
import json
import os
from datetime import datetime

def convert_keras_to_tflite(keras_model_path='models/stroke_model.keras',
                             tflite_output_path='assets/stroke_model.tflite',
                             quantization=False):
    """
    Convert Keras model to TFLite format for Flutter app
    Handles BatchNormalization layers properly
    
    Args:
        keras_model_path: Path to the .keras model file
        tflite_output_path: Output path for .tflite model
        quantization: Whether to apply quantization (smaller file, slightly less accurate)
    """
    
    print("\n" + "="*70)
    print("🔄 CONVERTING KERAS MODEL TO TFLITE")
    print("="*70)
    print(f"📅 Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"📂 Input: {keras_model_path}")
    print(f"📂 Output: {tflite_output_path}")
    print(f"🔧 Quantization: {'Enabled' if quantization else 'Disabled'}")
    
    # Check if model exists
    if not os.path.exists(keras_model_path):
        print(f"\n❌ Error: Model file not found at '{keras_model_path}'")
        print("   Please train the model first using train_stroke_model.py")
        return False
    
    try:
        # 1. Load the Keras model
        print("\n" + "="*60)
        print("📦 LOADING KERAS MODEL")
        print("="*60)
        
        model = tf.keras.models.load_model(keras_model_path)
        print(f"✅ Model loaded successfully")
        print(f"   Input shape: {model.input_shape}")
        print(f"   Output shape: {model.output_shape}")
        
        # Display model summary
        print("\n📊 Model Architecture:")
        model.summary()
        
        # 2. Set BatchNormalization to inference mode
        print("\n" + "="*60)
        print("🔧 PREPARING MODEL FOR CONVERSION")
        print("="*60)
        print("⚙️  Setting BatchNormalization layers to inference mode...")
        
        # Clone the model and set training=False for all layers
        for layer in model.layers:
            if isinstance(layer, tf.keras.layers.BatchNormalization):
                layer.trainable = False
        
        # Create a concrete function with fixed batch size
        # This helps avoid issues with BatchNormalization
        input_shape = model.input_shape[1:]  # Remove batch dimension
        
        @tf.function(input_signature=[tf.TensorSpec(shape=[1, *input_shape], dtype=tf.float32)])
        def serve_fn(input_tensor):
            return model(input_tensor, training=False)
        
        print("✅ Model prepared for conversion")
        
        # 3. Convert to TFLite
        print("\n" + "="*60)
        print("🔄 CONVERTING TO TFLITE")
        print("="*60)
        
        # Use the concrete function for conversion
        concrete_func = serve_fn.get_concrete_function()
        converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
        
        # Set converter options
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,  # Enable TensorFlow Lite ops
            tf.lite.OpsSet.SELECT_TF_OPS      # Enable TensorFlow ops (for better compatibility)
        ]
        
        # Experimental options for better compatibility
        converter._experimental_lower_tensor_list_ops = False
        
        # Apply optimizations
        if quantization:
            print("⚙️  Applying dynamic range quantization...")
            converter.optimizations = [tf.lite.Optimize.DEFAULT]
            # For float16 quantization (good balance)
            converter.target_spec.supported_types = [tf.float16]
        else:
            print("⚙️  No quantization - full precision model")
        
        # Convert
        print("🔄 Converting...")
        tflite_model = converter.convert()
        
        # 4. Save TFLite model
        print("\n" + "="*60)
        print("💾 SAVING TFLITE MODEL")
        print("="*60)
        
        # Ensure output directory exists
        os.makedirs(os.path.dirname(tflite_output_path), exist_ok=True)
        
        with open(tflite_output_path, 'wb') as f:
            f.write(tflite_model)
        
        file_size = os.path.getsize(tflite_output_path)
        print(f"✅ TFLite model saved successfully")
        print(f"   File size: {file_size:,} bytes ({file_size/1024:.2f} KB)")
        
        # 5. Test the TFLite model
        print("\n" + "="*60)
        print("🧪 TESTING TFLITE MODEL")
        print("="*60)
        
        # Load TFLite model and allocate tensors
        interpreter = tf.lite.Interpreter(model_path=tflite_output_path)
        interpreter.allocate_tensors()
        
        # Get input and output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print(f"✅ TFLite model loaded successfully")
        print(f"\n📥 Input Details:")
        print(f"   Name: {input_details[0]['name']}")
        print(f"   Shape: {input_details[0]['shape']}")
        print(f"   Type: {input_details[0]['dtype']}")
        
        print(f"\n📤 Output Details:")
        print(f"   Name: {output_details[0]['name']}")
        print(f"   Shape: {output_details[0]['shape']}")
        print(f"   Type: {output_details[0]['dtype']}")
        
        # Test with sample data
        print(f"\n🧪 Running test inference...")
        
        # Load scaler and metadata to create realistic test input
        scaler_path = 'assets/stroke_scaler.json'
        metadata_path = 'models/model_metadata.json'
        
        if os.path.exists(scaler_path):
            with open(scaler_path, 'r') as f:
                scaler_data = json.load(f)
            
            # Create test input: [age=65, hypertension=1, heart_disease=1, glucose=200, bmi=32]
            test_input = np.array([[65, 1, 1, 200, 32]], dtype=np.float32)
            
            # Scale the input
            mean = np.array(scaler_data['mean'], dtype=np.float32)
            std = np.array(scaler_data['std'], dtype=np.float32)
            test_input_scaled = (test_input - mean) / std
            
            # Check if model expects more features (engineered features)
            expected_features = input_details[0]['shape'][1]
            if expected_features > 5:
                print(f"   ⚙️  Model expects {expected_features} features (includes engineered features)")
                
                # Load metadata to get engineered features info
                if os.path.exists(metadata_path):
                    with open(metadata_path, 'r') as f:
                        metadata = json.load(f)
                    print(f"   ⚙️  Computing {len(metadata.get('engineered_features', []))} engineered features...")
                
                # Compute engineered features
                age, hypertension, heart_disease, glucose, bmi = test_input[0]
                
                engineered = [
                    age * glucose / 100,      # age_glucose
                    bmi * glucose / 100,      # bmi_glucose
                    age * bmi / 100,          # age_bmi
                    hypertension + heart_disease,  # health_risk
                    age ** 2,                 # age_squared
                    bmi ** 2,                 # bmi_squared
                    2 if age > 60 else (1 if age > 40 else 0),  # age_group_risk
                    2 if glucose > 200 else (1 if glucose > 140 else 0),  # glucose_risk
                    2 if bmi > 30 else (1 if bmi > 25 else 0)  # bmi_category
                ]
                
                # Scale engineered features
                if os.path.exists('models/scaler_complete.json'):
                    with open('models/scaler_complete.json', 'r') as f:
                        complete_scaler = json.load(f)
                    
                    full_input = list(test_input[0]) + engineered
                    mean_all = np.array(complete_scaler['mean'], dtype=np.float32)
                    std_all = np.array(complete_scaler['std'], dtype=np.float32)
                    test_input_scaled = np.array([(np.array(full_input) - mean_all) / std_all], dtype=np.float32)
                else:
                    # Fallback: use basic scaling for engineered features
                    engineered_scaled = [(e - np.mean(engineered)) / (np.std(engineered) + 1e-7) for e in engineered]
                    test_input_scaled = np.concatenate([test_input_scaled, [engineered_scaled]], axis=1).astype(np.float32)
            
            # Ensure correct shape
            test_input_scaled = test_input_scaled.reshape(1, -1).astype(np.float32)
            
            # Run inference
            interpreter.set_tensor(input_details[0]['index'], test_input_scaled)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]['index'])
            
            risk_percentage = output[0][0] * 100
            print(f"✅ Test successful!")
            print(f"   Test input: Age=65, Hypertension=1, Heart Disease=1, Glucose=200, BMI=32")
            print(f"   Predicted stroke risk: {risk_percentage:.2f}%")
            
            # Risk interpretation
            if risk_percentage < 10:
                risk_level = "Low"
            elif risk_percentage < 30:
                risk_level = "Moderate"
            elif risk_percentage < 60:
                risk_level = "High"
            else:
                risk_level = "Very High"
            
            print(f"   Risk Level: {risk_level}")
            
        else:
            print("   ⚠️  Scaler file not found - skipping realistic test")
            # Use zeros as input (neutral test)
            test_input = np.zeros((1, input_details[0]['shape'][1]), dtype=np.float32)
            interpreter.set_tensor(input_details[0]['index'], test_input)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]['index'])
            print(f"✅ Test with zero input successful!")
            print(f"   Output: {output[0][0]:.4f}")
        
        # 6. Create metadata file
        print("\n" + "="*60)
        print("📄 CREATING METADATA")
        print("="*60)
        
        metadata = {
            "model_type": "tflite",
            "conversion_date": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "source_model": keras_model_path,
            "quantization": quantization,
            "input_shape": [int(x) for x in input_details[0]['shape']],
            "output_shape": [int(x) for x in output_details[0]['shape']],
            "input_dtype": str(input_details[0]['dtype']),
            "output_dtype": str(output_details[0]['dtype']),
            "file_size_bytes": int(file_size),
            "file_size_kb": round(file_size/1024, 2),
            "expected_features": int(input_details[0]['shape'][1]),
            "original_features": ["age", "hypertension", "heart_disease", "avg_glucose_level", "bmi"],
            "requires_feature_engineering": bool(input_details[0]['shape'][1] > 5),
            "engineered_features": [
                "age_glucose", "bmi_glucose", "age_bmi", "health_risk",
                "age_squared", "bmi_squared", "age_group_risk", "glucose_risk", "bmi_category"
            ] if input_details[0]['shape'][1] > 5 else []
        }
        
        metadata_path = tflite_output_path.replace('.tflite', '_metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"✅ Metadata saved to: {metadata_path}")
        
        # 7. Final Summary
        print("\n" + "="*70)
        print("✅ CONVERSION COMPLETE!")
        print("="*70)
        print(f"📅 Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"\n📁 Generated Files:")
        print(f"   ├── {tflite_output_path}")
        print(f"   │   └── Size: {file_size/1024:.2f} KB")
        print(f"   └── {metadata_path}")
        
        if input_details[0]['shape'][1] > 5:
            print(f"\n⚠️  IMPORTANT: This model uses feature engineering!")
            print(f"   Your Flutter app must compute {input_details[0]['shape'][1] - 5} additional features")
            print(f"   See the generated Flutter code for implementation details")
        
        print(f"\n🎯 Next Steps for Flutter Integration:")
        print(f"   1. Copy '{tflite_output_path}' to your Flutter project's assets folder")
        print(f"   2. Copy 'assets/stroke_scaler.json' to your Flutter assets folder")
        if os.path.exists('models/scaler_complete.json'):
            print(f"   3. Copy 'models/scaler_complete.json' to your Flutter assets folder")
        print(f"   4. Update your Flutter pubspec.yaml:")
        print(f"      ```yaml")
        print(f"      flutter:")
        print(f"        assets:")
        print(f"          - assets/stroke_model.tflite")
        print(f"          - assets/stroke_scaler.json")
        if os.path.exists('models/scaler_complete.json'):
            print(f"          - assets/scaler_complete.json")
        print(f"      ```")
        print(f"   5. Use tflite_flutter package to load and run inference")
        print("="*70)
        
        return True
        
    except Exception as e:
        print(f"\n❌ Error during conversion: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def create_flutter_helper_code(num_features=14):
    """Generate sample Flutter/Dart code for using the TFLite model"""
    
    flutter_code = f'''
// Add to pubspec.yaml:
// dependencies:
//   tflite_flutter: ^0.10.1
//
// flutter:
//   assets:
//     - assets/stroke_model.tflite
//     - assets/stroke_scaler.json
//     - assets/scaler_complete.json

import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import 'dart:math' as math;

class StrokeRiskPredictor {{
  Interpreter? _interpreter;
  List<double>? _mean;
  List<double>? _std;
  List<double>? _meanComplete;
  List<double>? _stdComplete;
  bool _useFeatureEngineering = false;
  
  Future<void> loadModel() async {{
    try {{
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/stroke_model.tflite');
      
      // Check if model uses feature engineering
      var inputShape = _interpreter!.getInputTensor(0).shape;
      _useFeatureEngineering = inputShape[1] > 5;
      
      print('Model loaded successfully');
      print('Input shape: ${{inputShape}}');
      print('Using feature engineering: $_useFeatureEngineering');
      
      // Load basic scaler parameters
      final scalerJson = await rootBundle.loadString('assets/stroke_scaler.json');
      final scaler = json.decode(scalerJson);
      _mean = List<double>.from(scaler['mean']);
      _std = List<double>.from(scaler['std']);
      
      // Load complete scaler if using feature engineering
      if (_useFeatureEngineering) {{
        try {{
          final completeScalerJson = await rootBundle.loadString('assets/scaler_complete.json');
          final completeScaler = json.decode(completeScalerJson);
          _meanComplete = List<double>.from(completeScaler['mean']);
          _stdComplete = List<double>.from(completeScaler['std']);
          print('Complete scaler loaded');
        }} catch (e) {{
          print('Warning: Could not load complete scaler: $e');
        }}
      }}
      
    }} catch (e) {{
      print('Error loading model: $e');
      rethrow;
    }}
  }}
  
  List<double> _computeEngineeredFeatures(
    double age,
    double hypertension,
    double heartDisease,
    double glucose,
    double bmi,
  ) {{
    return [
      age * glucose / 100,      // age_glucose
      bmi * glucose / 100,      // bmi_glucose
      age * bmi / 100,          // age_bmi
      hypertension + heartDisease,  // health_risk
      age * age,                // age_squared
      bmi * bmi,                // bmi_squared
      age > 60 ? 2.0 : (age > 40 ? 1.0 : 0.0),  // age_group_risk
      glucose > 200 ? 2.0 : (glucose > 140 ? 1.0 : 0.0),  // glucose_risk
      bmi > 30 ? 2.0 : (bmi > 25 ? 1.0 : 0.0),  // bmi_category
    ];
  }}
  
  double predictStrokeRisk({{
    required double age,
    required int hypertension,
    required int heartDisease,
    required double glucose,
    required double bmi,
  }}) {{
    if (_interpreter == null || _mean == null || _std == null) {{
      throw Exception('Model not loaded. Call loadModel() first.');
    }}
    
    // Prepare base input: [age, hypertension, heart_disease, glucose, bmi]
    List<double> input = [
      age,
      hypertension.toDouble(),
      heartDisease.toDouble(),
      glucose,
      bmi
    ];
    
    List<double> scaledInput;
    
    if (_useFeatureEngineering && _meanComplete != null && _stdComplete != null) {{
      // Compute engineered features
      List<double> engineered = _computeEngineeredFeatures(
        age, hypertension.toDouble(), heartDisease.toDouble(), glucose, bmi
      );
      
      // Combine all features
      List<double> allFeatures = [...input, ...engineered];
      
      // Scale using complete scaler
      scaledInput = [];
      for (int i = 0; i < allFeatures.length; i++) {{
        scaledInput.add((allFeatures[i] - _meanComplete![i]) / _stdComplete![i]);
      }}
    }} else {{
      // Scale using basic scaler
      scaledInput = [];
      for (int i = 0; i < input.length; i++) {{
        scaledInput.add((input[i] - _mean![i]) / _std![i]);
      }}
      
      // If model expects more features but we don't have complete scaler,
      // pad with zeros (not ideal, but fallback)
      var expectedFeatures = _interpreter!.getInputTensor(0).shape[1];
      while (scaledInput.length < expectedFeatures) {{
        scaledInput.add(0.0);
      }}
    }}
    
    // Reshape input to [1, numFeatures]
    var inputArray = [scaledInput];
    
    // Prepare output buffer
    var output = List.filled(1, List.filled(1, 0.0)).cast<List<double>>();
    
    // Run inference
    _interpreter!.run(inputArray, output);
    
    // Return stroke risk as percentage
    double riskProbability = output[0][0];
    return riskProbability * 100;
  }}
  
  String getRiskLevel(double riskPercentage) {{
    if (riskPercentage < 10) return 'Low';
    if (riskPercentage < 30) return 'Moderate';
    if (riskPercentage < 60) return 'High';
    return 'Very High';
  }}
  
  void dispose() {{
    _interpreter?.close();
  }}
}}

// Usage example:
void main() async {{
  final predictor = StrokeRiskPredictor();
  await predictor.loadModel();
  
  double risk = predictor.predictStrokeRisk(
    age: 65,
    hypertension: 1,
    heartDisease: 1,
    glucose: 200,
    bmi: 32,
  );
  
  String level = predictor.getRiskLevel(risk);
  
  print('Stroke Risk: ${{risk.toStringAsFixed(2)}}%');
  print('Risk Level: $level');
  
  predictor.dispose();
}}
'''
    
    # Save Flutter helper code
    os.makedirs('assets', exist_ok=True)
    with open('assets/flutter_integration.dart', 'w') as f:
        f.write(flutter_code)
    
    print("\n✅ Flutter integration code saved to: assets/flutter_integration.dart")

def batch_convert():
    """Convert multiple models with different configurations"""
    
    print("\n" + "="*70)
    print("🔄 BATCH CONVERSION")
    print("="*70)
    
    conversions = [
        {
            'name': 'Full Precision',
            'input': 'models/stroke_model.keras',
            'output': 'assets/stroke_model.tflite',
            'quantization': False
        },
        {
            'name': 'Quantized (Float16)',
            'input': 'models/stroke_model.keras',
            'output': 'assets/stroke_model_quantized.tflite',
            'quantization': True
        }
    ]
    
    results = []
    
    for config in conversions:
        print(f"\n{'='*70}")
        print(f"Converting: {config['name']}")
        print(f"{'='*70}")
        
        success = convert_keras_to_tflite(
            keras_model_path=config['input'],
            tflite_output_path=config['output'],
            quantization=config['quantization']
        )
        
        results.append({
            'name': config['name'],
            'success': success,
            'output': config['output']
        })
    
    # Summary
    print("\n" + "="*70)
    print("📊 BATCH CONVERSION SUMMARY")
    print("="*70)
    
    for result in results:
        status = "✅ Success" if result['success'] else "❌ Failed"
        print(f"{status}: {result['name']}")
        if result['success'] and os.path.exists(result['output']):
            size = os.path.getsize(result['output'])
            print(f"         File: {result['output']} ({size/1024:.2f} KB)")
    
    print("="*70)

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Convert Keras model to TFLite for Flutter')
    parser.add_argument('--input', type=str, default='models/stroke_model.keras',
                        help='Input Keras model path')
    parser.add_argument('--output', type=str, default='assets/stroke_model.tflite',
                        help='Output TFLite model path')
    parser.add_argument('--quantize', action='store_true',
                        help='Enable quantization for smaller file size')
    parser.add_argument('--batch', action='store_true',
                        help='Convert multiple versions (full + quantized)')
    parser.add_argument('--flutter-code', action='store_true',
                        help='Generate Flutter integration code')
    
    args = parser.parse_args()
    
    if args.batch:
        # Batch convert multiple versions
        batch_convert()
        create_flutter_helper_code()
    else:
        # Single conversion
        success = convert_keras_to_tflite(
            keras_model_path=args.input,
            tflite_output_path=args.output,
            quantization=args.quantize
        )
        
        if not success:
            exit(1)
        
        # Generate Flutter helper code if requested
        if args.flutter_code:
            create_flutter_helper_code()
    
    print("\n🎉 All done! Your model is ready for Flutter deployment!")