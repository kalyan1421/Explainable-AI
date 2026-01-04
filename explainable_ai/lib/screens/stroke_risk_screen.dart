import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:tflite_flutter/tflite_flutter.dart';

class StrokeRiskScreen extends StatefulWidget {
  @override
  _StrokeRiskScreenState createState() => _StrokeRiskScreenState();
}

class _StrokeRiskScreenState extends State<StrokeRiskScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _ageCtrl = TextEditingController();
  final _glucoseCtrl = TextEditingController();
  final _bmiCtrl = TextEditingController();
  
  int _hypertension = 0;
  int _heartDisease = 0;
  
  double? _riskScore;
  String? _riskLevel;
  bool _loading = false;
  
  // Model components
  Interpreter? _interpreter;
  List<double>? _mean;
  List<double>? _std;
  List<double>? _meanComplete;
  List<double>? _stdComplete;
  bool _useFeatureEngineering = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Load TFLite model
      _interpreter = await Interpreter.fromAsset('assets/stroke_model.tflite');
      
      // Check if model uses feature engineering
      var inputShape = _interpreter!.getInputTensor(0).shape;
      _useFeatureEngineering = inputShape[1] > 5;
      
      print('✅ Model loaded successfully');
      print('📊 Input shape: $inputShape');
      print('🔧 Using feature engineering: $_useFeatureEngineering');
      
      // Load basic scaler parameters
      final scalerJson = await rootBundle.loadString('assets/stroke_scaler.json');
      final scaler = json.decode(scalerJson);
      _mean = List<double>.from(scaler['mean']);
      _std = List<double>.from(scaler['std']);
      
      // Load complete scaler if using feature engineering
      if (_useFeatureEngineering) {
        try {
          final completeScalerJson = await rootBundle.loadString('assets/scaler_complete.json');
          final completeScaler = json.decode(completeScalerJson);
          _meanComplete = List<double>.from(completeScaler['mean']);
          _stdComplete = List<double>.from(completeScaler['std']);
          print('✅ Complete scaler loaded');
        } catch (e) {
          print('⚠️  Warning: Could not load complete scaler: $e');
        }
      }
      
      setState(() {
        _modelError = null;
      });
      
    } catch (e) {
      print('❌ Error loading model: $e');
      setState(() {
        _modelError = 'Failed to load model: $e';
      });
    }
  }

  List<double> _computeEngineeredFeatures({
    required double age,
    required double hypertension,
    required double heartDisease,
    required double glucose,
    required double bmi,
  }) {
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
  }

  String _getRiskLevel(double riskPercentage) {
    if (riskPercentage < 10) return 'Low';
    if (riskPercentage < 30) return 'Moderate';
    if (riskPercentage < 60) return 'High';
    return 'Very High';
  }

  Color _getRiskColor(String level) {
    switch (level) {
      case 'Low':
        return Colors.green;
      case 'Moderate':
        return Colors.orange;
      case 'High':
        return Colors.deepOrange;
      case 'Very High':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<String> _getRecommendations(String level, double age, double glucose, double bmi) {
    List<String> recommendations = [];
    
    // Age-based recommendations
    if (age > 55) {
      recommendations.add("Regular health check-ups are crucial at your age");
      recommendations.add("Consider aspirin therapy after consulting your doctor");
    }
    
    // Glucose-based recommendations
    if (glucose > 140) {
      recommendations.add("Monitor blood sugar levels regularly");
      recommendations.add("Limit sugar and refined carbohydrate intake");
      recommendations.add("Consult a doctor about diabetes management");
    } else if (glucose > 100) {
      recommendations.add("Watch your sugar intake to prevent pre-diabetes");
    }
    
    // BMI-based recommendations
    if (bmi > 30) {
      recommendations.add("Work on gradual weight loss with your healthcare provider");
      recommendations.add("Aim for 30 minutes of moderate exercise daily");
    } else if (bmi > 25) {
      recommendations.add("Maintain a healthy weight through balanced diet and exercise");
    }
    
    // Hypertension recommendations
    if (_hypertension == 1) {
      recommendations.add("Monitor blood pressure regularly");
      recommendations.add("Reduce sodium intake (limit salt)");
      recommendations.add("Take prescribed medications as directed");
    }
    
    // Heart disease recommendations
    if (_heartDisease == 1) {
      recommendations.add("Follow cardiac rehabilitation guidelines");
      recommendations.add("Take heart medications as prescribed");
      recommendations.add("Regular cardiology follow-ups are essential");
    }
    
    // General recommendations
    recommendations.add("Eat a Mediterranean-style diet rich in fruits and vegetables");
    recommendations.add("Quit smoking and limit alcohol consumption");
    recommendations.add("Manage stress through meditation or yoga");
    recommendations.add("Get 7-8 hours of quality sleep each night");
    
    return recommendations;
  }

  void _predict() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_interpreter == null || _mean == null || _std == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_modelError ?? "Model not loaded. Please restart the app."),
          backgroundColor: Colors.red,
        )
      );
      return;
    }
    
    setState(() => _loading = true);

    try {
      // Parse inputs
      double age = double.parse(_ageCtrl.text);
      double glucose = double.parse(_glucoseCtrl.text);
      double bmi = double.parse(_bmiCtrl.text);
      
      // Prepare base input: [age, hypertension, heart_disease, glucose, bmi]
      List<double> input = [
        age,
        _hypertension.toDouble(),
        _heartDisease.toDouble(),
        glucose,
        bmi
      ];
      
      List<double> scaledInput;
      
      if (_useFeatureEngineering && _meanComplete != null && _stdComplete != null) {
        // Compute engineered features
        List<double> engineered = _computeEngineeredFeatures(
          age: age,
          hypertension: _hypertension.toDouble(),
          heartDisease: _heartDisease.toDouble(),
          glucose: glucose,
          bmi: bmi,
        );
        
        // Combine all features
        List<double> allFeatures = [...input, ...engineered];
        
        // Scale using complete scaler
        scaledInput = [];
        for (int i = 0; i < allFeatures.length; i++) {
          scaledInput.add((allFeatures[i] - _meanComplete![i]) / _stdComplete![i]);
        }
      } else {
        // Scale using basic scaler
        scaledInput = [];
        for (int i = 0; i < input.length; i++) {
          scaledInput.add((input[i] - _mean![i]) / _std![i]);
        }
        
        // If model expects more features but we don't have complete scaler,
        // pad with zeros (fallback)
        var expectedFeatures = _interpreter!.getInputTensor(0).shape[1];
        while (scaledInput.length < expectedFeatures) {
          scaledInput.add(0.0);
        }
      }
      
      // Reshape input to [1, numFeatures]
      var inputArray = [scaledInput];
      
      // Prepare output buffer
      var output = List.filled(1, List.filled(1, 0.0)).cast<List<double>>();
      
      // Run inference
      _interpreter!.run(inputArray, output);
      
      // Get risk percentage
      double riskProbability = output[0][0];
      double riskPercentage = riskProbability * 100;
      
      setState(() {
        _riskScore = riskPercentage;
        _riskLevel = _getRiskLevel(riskPercentage);
        _loading = false;
      });
      
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error during prediction: $e"),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _glucoseCtrl.dispose();
    _bmiCtrl.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("AI Stroke Risk Assessment"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            if (_modelError != null) _buildErrorBanner(),
            _buildInfoTile(),
            SizedBox(height: 12),
            _buildModelInfoCard(),
            SizedBox(height: 20),
            
            Text(
              "Health Vitals",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              )
            ),
            SizedBox(height: 10),
            
            _buildInput("Age", _ageCtrl, "Years (1-120)", Icons.cake),
            _buildInput("Average Glucose Level", _glucoseCtrl, "mg/dL (e.g., 120)", Icons.science),
            _buildInput("BMI (Body Mass Index)", _bmiCtrl, "e.g., 25.5", Icons.monitor_weight),
            
            SizedBox(height: 10),
            
            Card(
              elevation: 2,
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text("Do you have Hypertension?"),
                    subtitle: Text("High blood pressure"),
                    secondary: Icon(Icons.favorite, color: Colors.red),
                    value: _hypertension == 1,
                    onChanged: (v) => setState(() => _hypertension = v ? 1 : 0),
                    activeColor: Colors.blueAccent,
                  ),
                  Divider(height: 1),
                  SwitchListTile(
                    title: Text("History of Heart Disease?"),
                    subtitle: Text("Previous heart conditions"),
                    secondary: Icon(Icons.monitor_heart, color: Colors.red),
                    value: _heartDisease == 1,
                    onChanged: (v) => setState(() => _heartDisease = v ? 1 : 0),
                    activeColor: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.all(16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 3,
              ),
              onPressed: _loading ? null : _predict,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  if (_loading) SizedBox(width: 12),
                  Text(
                    _loading ? "Analyzing with AI..." : "Calculate Stroke Risk",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            
            if (_riskScore != null) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _modelError!,
              style: TextStyle(color: Colors.red.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile() {
    return Card(
      color: Colors.blue.shade50,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text(
                  "About Stroke Risk",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),
            Text(
              "A stroke occurs when blood flow to part of the brain is blocked or reduced. "
              "This AI-powered tool analyzes your health data using advanced machine learning "
              "to estimate your stroke risk and provide personalized recommendations.",
              style: TextStyle(
                color: Colors.blue.shade900,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelInfoCard() {
    return Card(
      color: Colors.green.shade50,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  "AI Model Status",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade900,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _interpreter != null ? Icons.check_circle : Icons.cancel,
                  color: _interpreter != null ? Colors.green : Colors.red,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  _interpreter != null ? "Model Loaded Successfully" : "Model Loading Failed",
                  style: TextStyle(color: Colors.green.shade900),
                ),
              ],
            ),
            if (_useFeatureEngineering) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.engineering, color: Colors.green, size: 16),
                  SizedBox(width: 6),
                  Text(
                    "Using Advanced Feature Engineering (14 features)",
                    style: TextStyle(color: Colors.green.shade900, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, String hint, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.blueAccent),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return "This field is required";
          if (double.tryParse(v) == null) return "Please enter a valid number";
          return null;
        },
      ),
    );
  }

  Widget _buildResult() {
    double age = double.tryParse(_ageCtrl.text) ?? 0;
    double glucose = double.tryParse(_glucoseCtrl.text) ?? 0;
    double bmi = double.tryParse(_bmiCtrl.text) ?? 0;
    
    Color riskColor = _getRiskColor(_riskLevel!);
    List<String> recommendations = _getRecommendations(_riskLevel!, age, glucose, bmi);
    
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Column(
        children: [
          // Risk Score Card
          Card(
            elevation: 4,
            color: riskColor.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: riskColor, width: 2),
            ),
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _riskLevel == 'Low' ? Icons.check_circle :
                    _riskLevel == 'Moderate' ? Icons.warning :
                    Icons.error,
                    color: riskColor,
                    size: 60,
                  ),
                  SizedBox(height: 12),
                  Text(
                    _riskLevel!,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: riskColor,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Stroke Risk",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${_riskScore!.toStringAsFixed(2)}%",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Probability Score",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Visual Risk Indicator
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Risk Level Indicator",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _riskScore! / 100,
                      minHeight: 20,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(riskColor),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Low", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text("High", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Recommendations Card
          Card(
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.recommend, color: Colors.blueAccent),
                      SizedBox(width: 8),
                      Text(
                        "Personalized Recommendations",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  ...recommendations.take(6).map((tip) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_right,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 16),
          
          // Disclaimer Card
          Card(
            color: Colors.amber.shade50,
            elevation: 2,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.medical_services, color: Colors.amber.shade900),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Important Disclaimer",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "This AI tool is for informational purposes only and is not a substitute for professional medical advice. "
                          "Please consult with a healthcare provider for proper diagnosis and treatment.",
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}