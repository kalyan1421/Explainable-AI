import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../services/firebase_service.dart';
import '../services/database_helper.dart';
import '../widgets/feature_importance_chart.dart';

class DiabetesRiskScreen extends StatefulWidget {
  @override
  _DiabetesRiskScreenState createState() => _DiabetesRiskScreenState();
}

class _DiabetesRiskScreenState extends State<DiabetesRiskScreen> {
  final RiskPredictionService _aiService = RiskPredictionService();
  final FirebaseService _db = FirebaseService();
  final DatabaseHelper _localDb = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _pregnanciesCtrl = TextEditingController(text: "1");
  final TextEditingController _glucoseCtrl = TextEditingController(text: "120");
  final TextEditingController _bpCtrl = TextEditingController(text: "70");
  final TextEditingController _skinCtrl = TextEditingController(text: "20");
  final TextEditingController _insulinCtrl = TextEditingController(text: "80");
  final TextEditingController _bmiCtrl = TextEditingController(text: "25.0");
  final TextEditingController _dpfCtrl = TextEditingController(text: "0.5");
  final TextEditingController _ageCtrl = TextEditingController(text: "30");

  double _riskResult = 0.0;
  bool _showResult = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _explanations = [];

  final String _simpleExplanation = "Diabetes means your blood sugar is too high. This tool calculates your risk based on glucose levels, weight, and age.";
  final List<String> _recommendations = const [
    "Cut down on sugary drinks, eat more leafy greens, and walk daily.",
  ];

  @override
  void initState() {
    super.initState();
    _aiService.loadAssets();
  }

  void _analyzeRisk() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> inputMap = {
      "Pregnancies": _pregnanciesCtrl.text,
      "Glucose": _glucoseCtrl.text,
      "BloodPressure": _bpCtrl.text,
      "SkinThickness": _skinCtrl.text,
      "Insulin": _insulinCtrl.text,
      "BMI": _bmiCtrl.text,
      "DiabetesPedigreeFunction": _dpfCtrl.text,
      "Age": _ageCtrl.text,
    };

    List<double> inputs = [
      double.parse(_pregnanciesCtrl.text),
      double.parse(_glucoseCtrl.text),
      double.parse(_bpCtrl.text),
      double.parse(_skinCtrl.text),
      double.parse(_insulinCtrl.text),
      double.parse(_bmiCtrl.text),
      double.parse(_dpfCtrl.text),
      double.parse(_ageCtrl.text),
    ];

    try {
      var result = await _aiService.predictDiabetes(inputs);

      setState(() {
        _riskResult = result['risk'];
        
        // Process Explanations
        Map<String, double> rawExpl = result['explanation'] ?? {};
        _explanations = rawExpl.entries
            .map((e) => {'feature': e.key, 'importance': e.value})
            .toList();
        _explanations.sort((a, b) => b['importance'].compareTo(a['importance']));
        if (_explanations.length > 5) _explanations = _explanations.sublist(0, 5);

        _showResult = true;
        _isLoading = false;
      });

      // Save to Firebase and SQLite
      String riskLevel = _riskResult > 0.7 ? "High" : (_riskResult > 0.4 ? "Medium" : "Low");
      
      await _db.saveRecord(
        title: "Diabetes",
        riskScore: _riskResult,
        riskLevel: riskLevel,
        inputs: inputMap,
        explanation: result['explanation'] ?? {},
      );
      
      await _localDb.savePrediction("diabetes", inputMap, result);
      await _db.logPrediction("diabetes");

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Diabetes Assessment"),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // AI Disclaimer
              _buildDisclaimer(),
              SizedBox(height: 16),
              _buildPatientFriendlyCard(),
              SizedBox(height: 16),
              
              if (_showResult) ...[
                _buildResultCard(),
                SizedBox(height: 20),
                FeatureImportanceChart(
                  features: _explanations,
                  title: 'Top Risk Factors',
                ),
                _buildExplanationText(),
                Divider(height: 40),
              ],
              
              Text("Patient Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              
              _buildInput("Pregnancies", _pregnanciesCtrl, "Number of pregnancies"),
              _buildInput("Glucose Level (mg/dL)", _glucoseCtrl, "Plasma glucose concentration"),
              _buildInput("Blood Pressure (mm Hg)", _bpCtrl, "Diastolic blood pressure"),
              _buildInput("Skin Thickness (mm)", _skinCtrl, "Triceps skin fold thickness"),
              _buildInput("Insulin Level (mu U/ml)", _insulinCtrl, "2-Hour serum insulin"),
              _buildInput("BMI", _bmiCtrl, "Body mass index"),
              _buildInput("Diabetes Pedigree Function", _dpfCtrl, "Family history factor (0.0 - 2.5)"),
              _buildInput("Age", _ageCtrl, "Age in years"),
              
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _analyzeRisk,
                  icon: _isLoading 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.analytics),
                  label: Text(_isLoading ? "Analyzing..." : "Analyze Risk"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade800),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "AI is an assistant, not a doctor. Always consult a healthcare professional for medical decisions.",
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientFriendlyCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Simple Explanation", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(_simpleExplanation),
            SizedBox(height: 8),
            Text("Recommendations", style: TextStyle(fontWeight: FontWeight.bold)),
            ..._recommendations.map((tip) => Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(tip)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    bool isHigh = _riskResult > 0.7;
    bool isMedium = _riskResult > 0.4 && _riskResult <= 0.7;
    Color cardColor = isHigh ? Colors.red.shade50 : (isMedium ? Colors.orange.shade50 : Colors.green.shade50);
    Color textColor = isHigh ? Colors.red : (isMedium ? Colors.orange : Colors.green);
    String riskText = isHigh ? "HIGH RISK" : (isMedium ? "MEDIUM RISK" : "LOW RISK");
    
    return Card(
      color: cardColor,
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isHigh ? Icons.warning_amber_rounded : (isMedium ? Icons.info_outline : Icons.check_circle_outline),
              size: 48,
              color: textColor,
            ),
            SizedBox(height: 10),
            Text(riskText, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            SizedBox(height: 5),
            Text("Confidence: ${(_riskResult * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationText() {
    if (_explanations.isEmpty) return SizedBox.shrink();
    
    String topFactors = _explanations.take(3).map((e) => e['feature']).join(", ");
    String riskLevel = _riskResult > 0.7 ? "high" : (_riskResult > 0.4 ? "moderate" : "low");
    
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("AI Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
          SizedBox(height: 8),
          Text(
            "Your $riskLevel risk is primarily influenced by: $topFactors. These factors contribute most significantly to the prediction.",
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }
}
