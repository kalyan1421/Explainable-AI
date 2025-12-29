import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../widgets/feature_importance_chart.dart';


class HeartRiskScreen extends StatefulWidget {
  @override
  _HeartRiskScreenState createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends State<HeartRiskScreen> {
  final RiskPredictionService _aiService = RiskPredictionService();
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
  String _fbs = "TRUE";
  String _restecg = "normal";
  String _exang = "FALSE";
  String _slope = "flat";
  String _ca = "0";
  String _thal = "normal";

  // Result State
  bool _showResult = false;
  double _riskScore = 0.0;
  List<Map<String, dynamic>> _explanations = [];

  @override
  void initState() {
    super.initState();
    _aiService.loadAssets();
  }

  void _predict() async {
    if (!_formKey.currentState!.validate()) return;

    // Map inputs to what the Python model expects
    Map<String, dynamic> inputs = {
      "age": _ageCtrl.text,
      "sex": _sex,
      "cp": _cp,
      "trestbps": _bpCtrl.text,
      "chol": _cholCtrl.text,
      "fbs": _fbs,
      "restecg": _restecg,
      "thalach": _thalachCtrl.text,
      "exang": _exang,
      "oldpeak": _oldpeakCtrl.text,
      "slope": _slope,
      "ca": _ca,
      "thal": _thal,
    };

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Heart Disease Risk")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_showResult) ...[
                _buildResultCard(),
                SizedBox(height: 20),
                FeatureImportanceChart(features: _explanations), // Explainability
                Divider(height: 40),
              ],
              Text("Patient Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              _buildRow(_buildNumberInput("Age", _ageCtrl), _buildDropdown("Sex", ["Male", "Female"], (v) => _sex = v!)),
              _buildRow(_buildDropdown("Chest Pain", ["typical angina", "atypical angina", "non-anginal", "asymptomatic"], (v) => _cp = v!), _buildNumberInput("BP (trestbps)", _bpCtrl)),
              _buildRow(_buildNumberInput("Cholesterol", _cholCtrl), _buildDropdown("Fasting BS > 120", ["TRUE", "FALSE"], (v) => _fbs = v!)),
              _buildDropdown("Resting ECG", ["normal", "st-t abnormality", "lv hypertrophy"], (v) => _restecg = v!),
              _buildRow(_buildNumberInput("Max Heart Rate", _thalachCtrl), _buildDropdown("Exercise Angina", ["TRUE", "FALSE"], (v) => _exang = v!)),
              _buildRow(_buildNumberInput("ST Depression", _oldpeakCtrl), _buildDropdown("Slope", ["upsloping", "flat", "downsloping"], (v) => _slope = v!)),
              _buildRow(_buildDropdown("Major Vessels (CA)", ["0", "1", "2", "3"], (v) => _ca = v!), _buildDropdown("Thalassemia", ["normal", "fixed defect", "reversible defect"], (v) => _thal = v!)),
              
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _predict,
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                child: Text("Analyze Risk"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    bool isHigh = _riskScore > 0.5;
    return Card(
      color: isHigh ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(isHigh ? "HIGH RISK DETECTED" : "LOW RISK", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.green)),
            Text("Confidence: ${(_riskScore * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 18)),
          ],
        ),
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

  Widget _buildDropdown(String label, List<String> items, Function(String?) onChanged) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
        value: items.contains(label) ? label : items[0], // simple default
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }
}