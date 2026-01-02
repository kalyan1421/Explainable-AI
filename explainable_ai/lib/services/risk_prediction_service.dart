import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class RiskPredictionService {
  // Existing Interpreters
  Interpreter? _heartInterpreter;
  Interpreter? _diabetesInterpreter;
  
  // New Interpreters
  Interpreter? _skinCancerInterpreter;
  Interpreter? _strokeInterpreter;
  Interpreter? _fetalInterpreter;
  Interpreter? _parkinsonsInterpreter;

  // Existing Scalers & Metadata
  Map<String, dynamic>? _heartScaler;
  Map<String, dynamic>? _diabetesScaler;
  Map<String, dynamic>? _heartMappings;
  Map<String, dynamic>? _heartImportance; // For Explainability
  Map<String, dynamic>? _diabetesImportance; // For Explainability

  // New Scalers
  Map<String, dynamic>? _strokeScaler;
  Map<String, dynamic>? _fetalScaler;
  Map<String, dynamic>? _parkinsonsScaler;

  List<String> _skinLabels = [
    'Actinic keratoses', 'Basal cell carcinoma', 'Benign keratosis',
    'Dermatofibroma', 'Melanoma', 'Nevus', 'Vascular lesion'
  ];

  bool isLoaded = false;

  Future<void> loadAssets() async {
    if (isLoaded) return;

    try {
      // 1. Load TFLite Models
      _heartInterpreter = await Interpreter.fromAsset('assets/heart_model.tflite');
      _diabetesInterpreter = await Interpreter.fromAsset('assets/diabetes_model.tflite');
      
      // Load new models (with error handling if files don't exist yet)
      try {
        _skinCancerInterpreter = await Interpreter.fromAsset('assets/skin_cancer.tflite');
      } catch (e) {
        print("⚠️ Skin cancer model not found: $e");
      }
      
      try {
        _strokeInterpreter = await Interpreter.fromAsset('assets/stroke_model.tflite');
      } catch (e) {
        print("⚠️ Stroke model not found: $e");
      }
      
      try {
        _fetalInterpreter = await Interpreter.fromAsset('assets/fetal_model.tflite');
      } catch (e) {
        print("⚠️ Fetal health model not found: $e");
      }
      
      try {
        _parkinsonsInterpreter = await Interpreter.fromAsset('assets/parkinsons_model.tflite');
      } catch (e) {
        print("⚠️ Parkinson's model not found: $e");
      }

      // 2. Load JSON Metadata
      _heartScaler = json.decode(await rootBundle.loadString('assets/heart_scaler.json'));
      _diabetesScaler = json.decode(await rootBundle.loadString('assets/diabetes_scaler.json'));
      _heartMappings = json.decode(await rootBundle.loadString('assets/heart_mappings.json'));
      
      // Load new scalers (with error handling)
      try {
        _strokeScaler = json.decode(await rootBundle.loadString('assets/stroke_scaler.json'));
      } catch (e) {
        print("⚠️ Stroke scaler not found: $e");
      }
      
      try {
        _fetalScaler = json.decode(await rootBundle.loadString('assets/fetal_scaler.json'));
      } catch (e) {
        print("⚠️ Fetal scaler not found: $e");
      }
      
      try {
        _parkinsonsScaler = json.decode(await rootBundle.loadString('assets/parkinsons_scaler.json'));
      } catch (e) {
        print("⚠️ Parkinson's scaler not found: $e");
      }
      
      // Load Feature Importance if available (Optional)
      try {
        _heartImportance = json.decode(await rootBundle.loadString('assets/heart_feature_importance.json'));
        _diabetesImportance = json.decode(await rootBundle.loadString('assets/diabetes_feature_importance.json'));
      } catch (e) {
        print("⚠️ Feature importance file not found: $e");
      }

      isLoaded = true;
      print("✅ All AI Assets Loaded Successfully");
    } catch (e) {
      print("❌ Error loading AI assets: $e");
    }
  }

  // --- Helper: Standard Scaler (Math) ---
  List<double> _standardize(List<double> input, Map<String, dynamic> scaler) {
    List<double> mean = List<double>.from(scaler['mean']);
    List<double> std = List<double>.from(scaler['std']);
    
    List<double> normalized = [];
    for (int i = 0; i < input.length; i++) {
      normalized.add((input[i] - mean[i]) / std[i]);
    }
    return normalized;
  }

  // --- 1. PREDICT HEART DISEASE ---
  Future<Map<String, dynamic>> predictHeart(Map<String, dynamic> userInputs) async {
    await loadAssets();

    List<double> numericVector = [];
    List<String> featureNames = List<String>.from(_heartScaler!['feature_names']);

    for (String feature in featureNames) {
      var val = userInputs[feature];
      if (val == null || val.toString().isEmpty) {
        print("⚠️ Missing value for feature: $feature");
        numericVector.add(0.0);
      } else if (val is String) {
        if (_heartMappings!.containsKey(feature) && _heartMappings![feature].containsKey(val)) {
          numericVector.add(_heartMappings![feature][val].toDouble());
        } else {
          // Try to parse as double, otherwise default to 0.0
          numericVector.add(double.tryParse(val) ?? 0.0);
        }
      } else {
        numericVector.add(double.tryParse(val.toString()) ?? 0.0);
      }
    }

    var processedInput = _standardize(numericVector, _heartScaler!);
    var inputTensor = [processedInput];
    var outputTensor = List.filled(1 * 1, 0.0).reshape([1, 1]);
    
    _heartInterpreter!.run(inputTensor, outputTensor);
    
    double riskScore = outputTensor[0][0];

    // Generate Explanation using feature importance directly
    Map<String, double> explanation = {};
    if (_heartImportance != null) {
      for (String feature in featureNames) {
        if (_heartImportance!.containsKey(feature)) {
          double importance = (_heartImportance![feature] as num).toDouble();
          explanation[feature] = importance;
        }
      }
    }

    return {
      'risk': riskScore,
      'explanation': explanation
    };
  }

  // --- 2. PREDICT DIABETES ---
  Future<Map<String, dynamic>> predictDiabetes(List<double> inputs) async {
    await loadAssets();

    // 1. Normalize
    var processedInput = _standardize(inputs, _diabetesScaler!);

    // 2. Inference
    var inputTensor = [processedInput];
    var outputTensor = List.filled(1 * 1, 0.0).reshape([1, 1]);

    _diabetesInterpreter!.run(inputTensor, outputTensor);

    double risk = outputTensor[0][0];

    // 3. Explanation using feature importance directly
    Map<String, double> explanation = {};
    List<String> featureNames = List<String>.from(_diabetesScaler!['feature_names']);
    
    if (_diabetesImportance != null) {
      for (String feature in featureNames) {
        if (_diabetesImportance!.containsKey(feature)) {
          double importance = (_diabetesImportance![feature] as num).toDouble();
          explanation[feature] = importance;
        }
      }
    }

    return {
      'risk': risk,
      'explanation': explanation
    };
  }

  // --- 3. PREDICT SKIN CANCER (Image) ---
  Future<Map<String, dynamic>> predictSkinCancer(Uint8List imageBytes) async {
    await loadAssets();
    
    if (_skinCancerInterpreter == null) {
      throw Exception("Skin cancer model not loaded");
    }

    // Resize to 224x224
    img.Image? original = img.decodeImage(imageBytes);
    if (original == null) {
      throw Exception("Failed to decode image");
    }
    img.Image resized = img.copyResize(original, width: 224, height: 224);

    // Normalize to [-1, 1] for MobileNetV2
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      var pixel = resized.getPixel(x, y);
      return [
        ((pixel.r / 255.0) - 0.5) * 2.0,
        ((pixel.g / 255.0) - 0.5) * 2.0,
        ((pixel.b / 255.0) - 0.5) * 2.0
      ];
    })));

    // Output: [1, 7]
    var output = List.filled(1 * 7, 0.0).reshape([1, 7]);
    _skinCancerInterpreter!.run(input, output);

    // Find max probability
    List<double> probs = List<double>.from(output[0]);
    double maxProb = 0.0;
    int maxIndex = 0;
    for(int i = 0; i < probs.length; i++) {
      if(probs[i] > maxProb) {
        maxProb = probs[i];
        maxIndex = i;
      }
    }

    return {
      'label': _skinLabels[maxIndex],
      'confidence': maxProb,
      'probabilities': probs
    };
  }

  // --- 4. PREDICT STROKE (Tabular) ---
  Future<Map<String, dynamic>> predictStroke(List<double> inputs) async {
    await loadAssets();
    
    if (_strokeInterpreter == null || _strokeScaler == null) {
      throw Exception("Stroke model or scaler not loaded");
    }
    
    var processedInput = _standardize(inputs, _strokeScaler!);
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    _strokeInterpreter!.run([processedInput], output);
    return {'risk': output[0][0]};
  }

  // --- 5. PREDICT FETAL HEALTH (Multi-class) ---
  Future<Map<String, dynamic>> predictFetalHealth(List<double> inputs) async {
    await loadAssets();
    
    if (_fetalInterpreter == null || _fetalScaler == null) {
      throw Exception("Fetal health model or scaler not loaded");
    }
    
    var processedInput = _standardize(inputs, _fetalScaler!);
    
    // Output shape [1, 3] for 3 classes (Normal, Suspect, Pathological)
    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);
    _fetalInterpreter!.run([processedInput], output);
    
    List<double> probs = List<double>.from(output[0]);
    int predictedClass = probs.indexOf(probs.reduce((curr, next) => curr > next ? curr : next));
    
    // Map 0,1,2 to labels
    String label = ["Normal", "Suspect", "Pathological"][predictedClass];
    
    return {'label': label, 'confidence': probs[predictedClass]};
  }

  // --- 6. PREDICT PARKINSON'S (Voice Features) ---
  Future<Map<String, dynamic>> predictParkinsons(List<double> inputs) async {
    await loadAssets();
    
    if (_parkinsonsInterpreter == null || _parkinsonsScaler == null) {
      throw Exception("Parkinson's model or scaler not loaded");
    }
    
    var processedInput = _standardize(inputs, _parkinsonsScaler!);
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
    _parkinsonsInterpreter!.run([processedInput], output);
    return {'score': output[0][0]}; // Regression score or probability
  }
}
