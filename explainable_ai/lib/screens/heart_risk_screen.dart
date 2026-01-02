import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../services/firebase_service.dart';
import '../services/database_helper.dart';
import '../widgets/feature_importance_chart.dart';

class HeartRiskScreen extends StatefulWidget {
  @override
  _HeartRiskScreenState createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends State<HeartRiskScreen> {
  final RiskPredictionService _aiService = RiskPredictionService();
  final FirebaseService _db = FirebaseService();
  final DatabaseHelper _localDb = DatabaseHelper();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _ageCtrl = TextEditingController(text: "55");
  final TextEditingController _bpCtrl = TextEditingController(text: "140");
  final TextEditingController _cholCtrl = TextEditingController(text: "240");
  final TextEditingController _thalachCtrl = TextEditingController(text: "150");
  final TextEditingController _oldpeakCtrl = TextEditingController(text: "1.5");

  // Dropdown Values (Must match mappings.json keys)
  String _sex = "Male";
  String _cp = "typical angina";
  String _fbs = "True";
  String _restecg = "normal";
  String _exang = "False";
  String _slope = "flat";
  String _ca = "0";
  String _thal = "normal";

  // Result State
  bool _showResult = false;
  bool _isLoading = false;
  double _riskScore = 0.0;
  List<Map<String, dynamic>> _explanations = [];

  final String _simpleExplanation = "This checks for potential heart issues by looking at chest pain type, blood pressure, and cholesterol.";
  final List<String> _recommendations = const [
    "Limit saturated fats, manage stress, and ensure you get 7-8 hours of sleep.",
  ];

  @override
  void initState() {
    super.initState();
    _aiService.loadAssets();
  }

  void _predict() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Map inputs to what the Python model expects
    Map<String, dynamic> inputs = {
      "age": _ageCtrl.text,
      "sex": _sex,
      "cp": _cp,
      "trestbps": _bpCtrl.text,
      "chol": _cholCtrl.text,
      "fbs": _fbs,
      "restecg": _restecg,
      "thalch": _thalachCtrl.text,
      "exang": _exang,
      "oldpeak": _oldpeakCtrl.text,
      "slope": _slope,
      "ca": _ca,
      "thal": _thal,
    };

    try {
      var result = await _aiService.predictHeart(inputs);
      
      setState(() {
        _riskScore = result['risk'];
        
        // Sort explanations by importance
        Map<String, double> rawExpl = result['explanation'];
        _explanations = rawExpl.entries
            .map((e) => {'feature': e.key, 'importance': e.value.abs()})
            .toList();
        _explanations.sort((a, b) => b['importance'].compareTo(a['importance']));
        
        // Take top 5 for the chart
        if (_explanations.length > 5) _explanations = _explanations.sublist(0, 5);
        
        _showResult = true;
        _isLoading = false;
      });

      // Save to Firebase (online) and SQLite (offline)
      String riskLevel = _riskScore > 0.7 ? "High" : (_riskScore > 0.4 ? "Medium" : "Low");
      
      await _db.saveRecord(
        title: "Heart Disease",
        riskScore: _riskScore,
        riskLevel: riskLevel,
        inputs: inputs,
        explanation: result['explanation'],
      );
      
      // Save locally for offline access
      await _localDb.savePrediction("heart", inputs, result);
      
      // Log audit
      await _db.logPrediction("heart");

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
        title: Text("Heart Disease Risk"),
        backgroundColor: Colors.red.shade50,
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
                FeatureImportanceChart(features: _explanations, title: "Top Risk Factors"),
                _buildExplanationText(),
                Divider(height: 40),
              ],
              
              Text("Patient Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildRow(_buildNumberInput("Age", _ageCtrl), _buildDropdown("Sex", ["Male", "Female"], _sex, (v) => _sex = v!)),
              _buildRow(_buildDropdown("Chest Pain", ["typical angina", "atypical angina", "non-anginal", "asymptomatic"], _cp, (v) => _cp = v!), _buildNumberInput("BP (trestbps)", _bpCtrl)),
              _buildRow(_buildNumberInput("Cholesterol", _cholCtrl), _buildDropdown("Fasting BS > 120", ["True", "False"], _fbs, (v) => _fbs = v!)),
              _buildDropdown("Resting ECG", ["normal", "st-t abnormality", "lv hypertrophy"], _restecg, (v) => _restecg = v!),
              _buildRow(_buildNumberInput("Max Heart Rate", _thalachCtrl), _buildDropdown("Exercise Angina", ["True", "False"], _exang, (v) => _exang = v!)),
              _buildRow(_buildNumberInput("ST Depression", _oldpeakCtrl), _buildDropdown("Slope", ["upsloping", "flat", "downsloping"], _slope, (v) => _slope = v!)),
              _buildRow(_buildDropdown("Major Vessels (CA)", ["0", "1", "2", "3"], _ca, (v) => _ca = v!), _buildDropdown("Thalassemia", ["normal", "fixed defect", "reversible defect"], _thal, (v) => _thal = v!)),
              
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _predict,
                  icon: _isLoading 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.analytics),
                  label: Text(_isLoading ? "Analyzing..." : "Analyze Risk"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
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
    bool isHigh = _riskScore > 0.7;
    bool isMedium = _riskScore > 0.4 && _riskScore <= 0.7;
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
            Text("Confidence: ${(_riskScore * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationText() {
    if (_explanations.isEmpty) return SizedBox.shrink();
    
    String topFactors = _explanations.take(3).map((e) => e['feature']).join(", ");
    String riskLevel = _riskScore > 0.7 ? "high" : (_riskScore > 0.4 ? "moderate" : "low");
    
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

  Widget _buildRow(Widget w1, Widget w2) {
    return Row(children: [Expanded(child: w1), SizedBox(width: 10), Expanded(child: w2)]);
  }

  Widget _buildNumberInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String currentValue, Function(String?) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        value: items.contains(currentValue) ? currentValue : items[0],
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
