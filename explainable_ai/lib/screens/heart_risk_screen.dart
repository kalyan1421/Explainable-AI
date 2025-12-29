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

  // All 13 required features for Heart Disease prediction
  double? _age;
  String? _selectedSex;
  String? _selectedChestPainType;
  double? _restingBP;
  double? _cholesterol;
  String? _fastingBloodSugar;  // fbs
  String? _restingECG;          // restecg
  double? _maxHeartRate;        // thalch
  String? _exerciseAngina;      // exang
  double? _oldpeak;             // ST depression
  String? _slope;               // slope
  double? _ca;                  // number of major vessels
  String? _thal;                // thalassemia

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
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading model: $e')),
      );
    }
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Build input data with all 13 features
      final input = {
        'age': _age!,
        'sex': _selectedSex!,
        'cp': _selectedChestPainType!,
        'trestbps': _restingBP!,
        'chol': _cholesterol!,
        'fbs': _fastingBloodSugar!,
        'restecg': _restingECG!,
        'thalch': _maxHeartRate!,
        'exang': _exerciseAngina!,
        'oldpeak': _oldpeak!,
        'slope': _slope!,
        'ca': _ca!,
        'thal': _thal!,
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
            // Section: Basic Information
            _buildSectionHeader('Basic Information'),
            
            // Age
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Age',
                hintText: 'Enter age in years',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _age = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Sex
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Sex',
                border: OutlineInputBorder(),
              ),
              items: ['Male', 'Female']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedSex = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 24),

            // Section: Symptoms
            _buildSectionHeader('Symptoms'),

            // Chest Pain Type
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Chest Pain Type',
                border: OutlineInputBorder(),
              ),
              items: ['typical angina', 'atypical angina', 'non-anginal', 'asymptomatic']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedChestPainType = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 16),

            // Exercise Induced Angina
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Exercise Induced Angina',
                border: OutlineInputBorder(),
              ),
              items: ['Yes', 'No']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _exerciseAngina = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 24),

            // Section: Vital Signs
            _buildSectionHeader('Vital Signs'),

            // Resting Blood Pressure
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Resting Blood Pressure (mm Hg)',
                hintText: 'e.g., 120',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _restingBP = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Max Heart Rate
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Maximum Heart Rate Achieved',
                hintText: 'e.g., 150',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _maxHeartRate = double.tryParse(v),
            ),
            SizedBox(height: 24),

            // Section: Lab Results
            _buildSectionHeader('Lab Results'),

            // Cholesterol
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Serum Cholesterol (mg/dl)',
                hintText: 'e.g., 200',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _cholesterol = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Fasting Blood Sugar
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Fasting Blood Sugar > 120 mg/dl',
                border: OutlineInputBorder(),
              ),
              items: ['Yes', 'No']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _fastingBloodSugar = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 24),

            // Section: ECG Results
            _buildSectionHeader('ECG Results'),

            // Resting ECG
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Resting ECG Results',
                border: OutlineInputBorder(),
              ),
              items: ['normal', 'ST-T abnormality', 'LV hypertrophy']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _restingECG = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 16),

            // ST Depression (Oldpeak)
            TextFormField(
              decoration: InputDecoration(
                labelText: 'ST Depression (Oldpeak)',
                hintText: 'e.g., 1.5',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              onChanged: (v) => _oldpeak = double.tryParse(v),
            ),
            SizedBox(height: 16),

            // Slope
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Slope of Peak Exercise ST Segment',
                border: OutlineInputBorder(),
              ),
              items: ['upsloping', 'flat', 'downsloping']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _slope = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 24),

            // Section: Cardiac Tests
            _buildSectionHeader('Cardiac Tests'),

            // Number of Major Vessels
            DropdownButtonFormField<double>(
              decoration: InputDecoration(
                labelText: 'Number of Major Vessels (0-3)',
                border: OutlineInputBorder(),
              ),
              items: [0.0, 1.0, 2.0, 3.0]
                  .map((n) => DropdownMenuItem(value: n, child: Text(n.toInt().toString())))
                  .toList(),
              onChanged: (v) => setState(() => _ca = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 16),

            // Thalassemia
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Thalassemia',
                border: OutlineInputBorder(),
              ),
              items: ['normal', 'fixed defect', 'reversable defect']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _thal = v),
              validator: (v) => v == null ? 'Required' : null,
            ),
            SizedBox(height: 32),

            // Predict Button
            ElevatedButton(
              onPressed: _predict,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Predict Risk', style: TextStyle(fontSize: 18)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
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
