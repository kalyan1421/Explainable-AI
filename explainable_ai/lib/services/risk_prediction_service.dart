import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class RiskPredictionService {
  Interpreter? _heartInterpreter;
  Interpreter? _diabetesInterpreter;
  
  Map<String, dynamic>? _heartScaler;
  Map<String, dynamic>? _diabetesScaler;
  
  Map<String, dynamic>? _heartMappings;
  Map<String, dynamic>? _heartImportance; // For Explainability
  Map<String, dynamic>? _diabetesImportance; // For Explainability

  bool isLoaded = false;

  Future<void> loadAssets() async {
    if (isLoaded) return;

    try {
      // 1. Load TFLite Models
      _heartInterpreter = await Interpreter.fromAsset('assets/heart_model.tflite');
      _diabetesInterpreter = await Interpreter.fromAsset('assets/diabetes_model.tflite');

      // 2. Load JSON Metadata
      _heartScaler = json.decode(await rootBundle.loadString('assets/heart_scaler.json'));
      _diabetesScaler = json.decode(await rootBundle.loadString('assets/diabetes_scaler.json'));
      _heartMappings = json.decode(await rootBundle.loadString('assets/heart_mappings.json'));
      
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
      if (val is String) {
        if (_heartMappings!.containsKey(feature) && _heartMappings![feature].containsKey(val)) {
          numericVector.add(_heartMappings![feature][val].toDouble());
        } else {
          numericVector.add(0.0);
        }
      } else {
        numericVector.add(double.parse(val.toString()));
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
}
