import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../widgets/feature_importance_chart.dart';

class HeartRiskScreen extends StatefulWidget {
  @override
  _HeartRiskScreenState createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends State<HeartRiskScreen> {
  final _service = RiskPredictionService();
  bool _isLoading = true;
  Map<String, dynamic>? _result;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _inputData = {};

  // Example fields for Heart Disease
  String? _selectedSex;
  String? _selectedChestPainType;
  double? _age;
  double? _restingBP;
  double? _cholesterol;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize('heart');
      setState(() => _isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading model: $e')),
      );
    }
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Build input data (example - adjust based on your features)
      final input = {
        'age': _age!,
        'sex': _selectedSex!,
        'cp': _selectedChestPainType!,
        'trestbps': _restingBP!,
        'chol': _cholesterol!,
        // Add all other features...
      };

      final result = await _service.predict(input);
      
      setState(() {
        _result = result;
        _isLoading = false;
      });

      _showResultDialog(result);

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prediction error: $e')),
      );
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Risk Assessment Result'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result['risk_level'],
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: result['risk_level'] == 'High Risk' ? Colors.red : Colors.green,
                ),
              ),
              SizedBox(height: 10),
              Text('Probability: ${(result['probability'] * 100).toStringAsFixed(1)}%'),
              Text('Confidence: ${result['confidence'].toStringAsFixed(1)}%'),
              SizedBox(height: 20),
              Text('Top Contributing Factors:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...((result['top_features'] as List).map((f) => 
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(f['feature']),
                      Text('${(f['importance'] * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                )
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Heart Disease Risk')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Heart Disease Risk Prediction')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Age
            TextFormField(
              decoration: InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _age = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Sex
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Sex'),
              items: ['Male', 'Female']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSex = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 16),

            // Chest Pain Type
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Chest Pain Type'),
              items: ['typical angina', 'atypical angina', 'non-anginal', 'asymptomatic']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedChestPainType = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 16),

            // Resting Blood Pressure
            TextFormField(
              decoration: InputDecoration(labelText: 'Resting Blood Pressure'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _restingBP = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Cholesterol
            TextFormField(
              decoration: InputDecoration(labelText: 'Cholesterol'),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _cholesterol = double.tryParse(v),
            ),
            SizedBox(height: 32),

            // Add more fields based on your feature_names from scaler.json

            ElevatedButton(
              onPressed: _predict,
              child: Text('Predict Risk'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            if (_result != null) ...[
              SizedBox(height: 32),
              FeatureImportanceChart(
                features: _result!['top_features'],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}