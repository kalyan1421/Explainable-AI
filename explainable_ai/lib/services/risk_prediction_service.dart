import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class RiskPredictionService {
  Interpreter? _interpreter;
  Map<String, dynamic>? _scaler;
  Map<String, dynamic>? _mappings;
  Map<String, dynamic>? _featureImportance;
  Map<String, dynamic>? _metadata;
  List<String>? _featureNames;

  // Initialize the model
  Future<void> initialize(String modelType) async {
    try {
      // modelType: 'heart' or 'diabetes'
      final modelPath = 'assets/${modelType}_model.tflite';
      
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(modelPath);
      print('✅ Model loaded: $modelPath');

      // Load scaler
      final scalerJson = await rootBundle.loadString('assets/${modelType}_scaler.json');
      _scaler = json.decode(scalerJson);
      _featureNames = List<String>.from(_scaler!['feature_names']);
      print('✅ Scaler loaded');

      // Load mappings
      try {
        final mappingsJson = await rootBundle.loadString('assets/${modelType}_mappings.json');
        _mappings = json.decode(mappingsJson);
        print('✅ Mappings loaded');
      } catch (e) {
        _mappings = {}; // No mappings needed
      }

      // Load feature importance
      final importanceJson = await rootBundle.loadString('assets/${modelType}_feature_importance.json');
      _featureImportance = json.decode(importanceJson);
      print('✅ Feature importance loaded');

      // Load metadata
      final metadataJson = await rootBundle.loadString('assets/${modelType}_metadata.json');
      _metadata = json.decode(metadataJson);
      print('✅ Metadata loaded');

    } catch (e) {
      print('❌ Error initializing model: $e');
      rethrow;
    }
  }

  // Convert categorical input using mappings
  Map<String, dynamic> convertCategoricalInputs(Map<String, dynamic> rawInput) {
    final convertedInput = Map<String, dynamic>.from(rawInput);

    if (_mappings == null || _mappings!.isEmpty) {
      return convertedInput;
    }

    _mappings!.forEach((feature, mapping) {
      if (rawInput.containsKey(feature)) {
        final value = rawInput[feature];
        if (mapping is Map && mapping.containsKey(value.toString())) {
          convertedInput[feature] = mapping[value.toString()];
        }
      }
    });

    return convertedInput;
  }

  // Normalize input using scaler
  List<double> normalizeInput(Map<String, dynamic> input) {
    if (_scaler == null || _featureNames == null) {
      throw Exception('Scaler not loaded');
    }

    final means = List<double>.from(_scaler!['mean']);
    final stds = List<double>.from(_scaler!['std']);
    
    final normalized = <double>[];
    
    for (int i = 0; i < _featureNames!.length; i++) {
      final featureName = _featureNames![i];
      
      if (!input.containsKey(featureName)) {
        throw Exception('Missing feature: $featureName');
      }
      
      final value = input[featureName].toDouble();
      final normalizedValue = (value - means[i]) / stds[i];
      normalized.add(normalizedValue);
    }
    
    return normalized;
  }

  // Run prediction
  Future<Map<String, dynamic>> predict(Map<String, dynamic> rawInput) async {
    if (_interpreter == null) {
      throw Exception('Model not initialized');
    }

    try {
      // Step 1: Convert categorical inputs
      final convertedInput = convertCategoricalInputs(rawInput);
      print('📝 Converted input: $convertedInput');

      // Step 2: Normalize input
      final normalizedInput = normalizeInput(convertedInput);
      print('📊 Normalized input: $normalizedInput');

      // Step 3: Prepare input tensor
      final input = [normalizedInput];
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Step 4: Run inference
      _interpreter!.run(input, output);

      final riskProbability = output[0][0] as double;
      final riskLevel = riskProbability >= 0.5 ? 'High Risk' : 'Low Risk';

      print('🎯 Prediction: $riskProbability ($riskLevel)');

      // Step 5: Get top contributing features
      final topFeatures = _getTopContributingFeatures(convertedInput, 5);

      return {
        'probability': riskProbability,
        'risk_level': riskLevel,
        'confidence': (riskProbability >= 0.5 ? riskProbability : 1 - riskProbability) * 100,
        'top_features': topFeatures,
        'metadata': _metadata,
      };

    } catch (e) {
      print('❌ Prediction error: $e');
      rethrow;
    }
  }

  // Get top contributing features for explainability
  List<Map<String, dynamic>> _getTopContributingFeatures(
    Map<String, dynamic> input, 
    int topN
  ) {
    if (_featureImportance == null) return [];

    final contributions = <Map<String, dynamic>>[];

    _featureImportance!.forEach((feature, importance) {
      if (input.containsKey(feature)) {
        contributions.add({
          'feature': feature,
          'value': input[feature],
          'importance': importance,
        });
      }
    });

    contributions.sort((a, b) => (b['importance'] as double).compareTo(a['importance'] as double));
    
    return contributions.take(topN).toList();
  }

  // Get feature names for UI
  List<String> getFeatureNames() {
    return _featureNames ?? [];
  }

  // Get mappings for a specific feature
  Map<String, int>? getMappingsForFeature(String feature) {
    if (_mappings == null || !_mappings!.containsKey(feature)) {
      return null;
    }
    return Map<String, int>.from(_mappings![feature]);
  }

  // Dispose resources
  void dispose() {
    _interpreter?.close();
  }
}