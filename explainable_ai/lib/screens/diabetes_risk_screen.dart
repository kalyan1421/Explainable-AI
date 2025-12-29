import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../widgets/feature_importance_chart.dart';

class DiabetesRiskScreen extends StatefulWidget {
  @override
  _DiabetesRiskScreenState createState() => _DiabetesRiskScreenState();
}

class _DiabetesRiskScreenState extends State<DiabetesRiskScreen> {
  final _service = RiskPredictionService();
  bool _isLoading = true;
  bool _isPredicting = false;
  Map<String, dynamic>? _result;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _pregnanciesController = TextEditingController();
  final _glucoseController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _skinThicknessController = TextEditingController();
  final _insulinController = TextEditingController();
  final _bmiController = TextEditingController();
  final _dpfController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() => _isLoading = true);
    try {
      await _service.initialize('diabetes');
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load model: $e');
    }
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) {
      _showError('Please fill all required fields');
      return;
    }

    setState(() => _isPredicting = true);

    try {
      // Build input data with exact feature names from diabetes_scaler.json
      final input = {
        'Pregnancies': double.parse(_pregnanciesController.text),
        'Glucose': double.parse(_glucoseController.text),
        'BloodPressure': double.parse(_bloodPressureController.text),
        'SkinThickness': double.parse(_skinThicknessController.text),
        'Insulin': double.parse(_insulinController.text),
        'BMI': double.parse(_bmiController.text),
        'DiabetesPedigreeFunction': double.parse(_dpfController.text),
        'Age': double.parse(_ageController.text),
      };

      final result = await _service.predict(input);
      
      setState(() {
        _result = result;
        _isPredicting = false;
      });

      _showResultDialog(result);

    } catch (e) {
      setState(() => _isPredicting = false);
      _showError('Prediction error: $e');
    }
  }

  void _showResultDialog(Map<String, dynamic> result) {
    final isHighRisk = result['risk_level'] == 'High Risk';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isHighRisk ? Icons.warning_amber_rounded : Icons.check_circle,
              color: isHighRisk ? Colors.orange : Colors.green,
              size: 32,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Diabetes Risk',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Risk Level Card
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isHighRisk ? Colors.orange.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isHighRisk ? Colors.orange : Colors.green,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      result['risk_level'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isHighRisk ? Colors.orange.shade900 : Colors.green.shade900,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${(result['probability'] * 100).toStringAsFixed(1)}% Probability',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    Text(
                      '${result['confidence'].toStringAsFixed(1)}% Confidence',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 20),
              
              // Top Contributing Factors
              Text(
                'Top Contributing Factors:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 12),
              
              ...((result['top_features'] as List).map((f) => 
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatFeatureName(f['feature']),
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(f['importance'] * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              )),
              
              SizedBox(height: 20),
              
              // Health Tips
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Health Tips:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      isHighRisk
                          ? '• Consult an endocrinologist\n• Monitor blood glucose regularly\n• Follow a diabetes-friendly diet\n• Exercise 30 minutes daily\n• Maintain healthy weight'
                          : '• Keep a balanced diet\n• Stay physically active\n• Monitor glucose periodically\n• Maintain healthy weight\n• Get regular check-ups',
                      style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            icon: Icon(Icons.refresh),
            label: Text('New Test'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _pregnanciesController.clear();
    _glucoseController.clear();
    _bloodPressureController.clear();
    _skinThicknessController.clear();
    _insulinController.clear();
    _bmiController.clear();
    _dpfController.clear();
    _ageController.clear();
    setState(() {
      _result = null;
    });
  }

  String _formatFeatureName(String feature) {
    const Map<String, String> names = {
      'Pregnancies': 'Number of Pregnancies',
      'Glucose': 'Glucose Level',
      'BloodPressure': 'Blood Pressure',
      'SkinThickness': 'Skin Thickness',
      'Insulin': 'Insulin Level',
      'BMI': 'Body Mass Index',
      'DiabetesPedigreeFunction': 'Diabetes Pedigree',
      'Age': 'Age',
    };
    return names[feature] ?? feature;
  }

  double _calculateBMI() {
    // Helper function - not used in this version but useful for future
    // BMI = weight(kg) / height(m)^2
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Diabetes Risk'),
          backgroundColor: Colors.orange.shade700,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading model...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Diabetes Risk Prediction'),
        backgroundColor: Colors.orange.shade700,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _resetForm,
            tooltip: 'Reset Form',
          ),
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(),
            tooltip: 'Information',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Header Card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.orange, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fill in your medical data for diabetes risk assessment. All fields are required.',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Medical History Section
            _buildSectionHeader('Medical History'),
            _buildNumberField(
              controller: _pregnanciesController,
              label: 'Number of Pregnancies',
              hint: 'Enter number (0-17)',
              icon: Icons.child_care,
              helpText: 'Total number of times pregnant',
            ),
            SizedBox(height: 16),
            
            _buildNumberField(
              controller: _ageController,
              label: 'Age',
              hint: 'Enter age (21-81)',
              icon: Icons.cake,
              helpText: 'Age in years',
            ),
            
            SizedBox(height: 24),
            
            // Blood Tests Section
            _buildSectionHeader('Blood Tests'),
            _buildNumberField(
              controller: _glucoseController,
              label: 'Plasma Glucose Concentration',
              hint: 'Enter glucose (0-199 mg/dL)',
              icon: Icons.opacity,
              helpText: 'Glucose level (2 hours in oral glucose tolerance test)',
            ),
            SizedBox(height: 16),
            
            _buildNumberField(
              controller: _insulinController,
              label: '2-Hour Serum Insulin',
              hint: 'Enter insulin (0-846 mu U/ml)',
              icon: Icons.water_drop,
              helpText: 'Serum insulin level',
              isDecimal: true,
            ),
            
            SizedBox(height: 24),
            
            // Physical Measurements Section
            _buildSectionHeader('Physical Measurements'),
            _buildNumberField(
              controller: _bloodPressureController,
              label: 'Diastolic Blood Pressure',
              hint: 'Enter BP (0-122 mm Hg)',
              icon: Icons.favorite,
              helpText: 'Diastolic blood pressure',
            ),
            SizedBox(height: 16),
            
            _buildNumberField(
              controller: _skinThicknessController,
              label: 'Triceps Skin Fold Thickness',
              hint: 'Enter thickness (0-99 mm)',
              icon: Icons.straighten,
              helpText: 'Skin fold thickness measurement',
            ),
            SizedBox(height: 16),
            
            _buildNumberField(
              controller: _bmiController,
              label: 'Body Mass Index (BMI)',
              hint: 'Enter BMI (0-67.1)',
              icon: Icons.monitor_weight,
              helpText: 'Weight in kg / (Height in m)²',
              isDecimal: true,
            ),
            
            SizedBox(height: 24),
            
            // Genetic Factors Section
            _buildSectionHeader('Genetic Factors'),
            _buildNumberField(
              controller: _dpfController,
              label: 'Diabetes Pedigree Function',
              hint: 'Enter DPF (0.078-2.42)',
              icon: Icons.family_restroom,
              helpText: 'Family history score (genetic predisposition)',
              isDecimal: true,
            ),
            
            SizedBox(height: 32),
            
            // Info Box
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This tool uses AI to assess diabetes risk based on clinical data. It should not replace professional medical advice.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Predict Button
            ElevatedButton(
              onPressed: _isPredicting ? null : _predict,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              child: _isPredicting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Analyzing...', style: TextStyle(fontSize: 16)),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics),
                        SizedBox(width: 8),
                        Text('Assess Risk', style: TextStyle(fontSize: 16)),
                      ],
                    ),
            ),
            
            SizedBox(height: 24),
            
            // Feature Importance Chart (if prediction made)
            if (_result != null) ...[
              FeatureImportanceChart(
                features: _result!['top_features'],
                title: 'Key Risk Factors',
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
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helpText,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: Colors.orange.shade700),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Required';
            if (double.tryParse(v) == null) return 'Enter valid number';
            return null;
          },
        ),
        if (helpText != null) ...[
          SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              helpText,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About This Assessment'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This diabetes risk prediction tool uses machine learning to assess your risk based on:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _buildInfoItem('Medical History', 'Pregnancies, age, family history'),
              _buildInfoItem('Blood Tests', 'Glucose and insulin levels'),
              _buildInfoItem('Physical Measurements', 'BMI, blood pressure, skin thickness'),
              SizedBox(height: 12),
              Text(
                'Model Accuracy: 80-85%',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              SizedBox(height: 8),
              Text(
                'Important: This is a screening tool, not a diagnosis. Always consult healthcare professionals for medical advice.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pregnanciesController.dispose();
    _glucoseController.dispose();
    _bloodPressureController.dispose();
    _skinThicknessController.dispose();
    _insulinController.dispose();
    _bmiController.dispose();
    _dpfController.dispose();
    _ageController.dispose();
    _service.dispose();
    super.dispose();
  }
}