import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';
import '../widgets/feature_importance_chart.dart';

class DiabetesRiskScreen extends StatefulWidget {
  @override
  _DiabetesRiskScreenState createState() => _DiabetesRiskScreenState();
}

class _DiabetesRiskScreenState extends State<DiabetesRiskScreen> {
  final RiskPredictionService _aiService = RiskPredictionService();
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
  List<Map<String, dynamic>> _explanations = [];

  @override
  void initState() {
    super.initState();
    _aiService.loadAssets();
  }

  void _analyzeRisk() async {
    if (!_formKey.currentState!.validate()) return;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Diabetes Assessment")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_showResult) ...[
                _buildResultCard(),
                SizedBox(height: 20),
                FeatureImportanceChart(
                  features: _explanations,
                  title: 'Top Risk Factors', // Now works because we added the parameter
                ),
                Divider(height: 40),
              ],
              _buildInput("Pregnancies", _pregnanciesCtrl),
              _buildInput("Glucose Level (mg/dL)", _glucoseCtrl),
              _buildInput("Blood Pressure (mm Hg)", _bpCtrl),
              _buildInput("Skin Thickness (mm)", _skinCtrl),
              _buildInput("Insulin Level", _insulinCtrl),
              _buildInput("BMI", _bmiCtrl),
              _buildInput("Diabetes Pedigree Function", _dpfCtrl),
              _buildInput("Age", _ageCtrl),
              
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _analyzeRisk,
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
    bool isHigh = _riskResult > 0.5;
    return Card(
      color: isHigh ? Colors.red.shade50 : Colors.green.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(isHigh ? "HIGH RISK DETECTED" : "LOW RISK", 
                 style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.green)),
            Text("Confidence: ${(_riskResult * 100).toStringAsFixed(1)}%"),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder()),
      ),
    );
  }
}