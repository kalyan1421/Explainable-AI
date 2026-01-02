import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';

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
  bool _loading = false;

  final List<String> _recommendations = const [
    "Keep your blood pressure in a healthy range.",
    "Reduce salt intake and avoid smoking.",
    "Aim for 30 minutes of moderate exercise 5 days a week.",
  ];

  void _predict() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      List<double> inputs = [
        double.parse(_ageCtrl.text),
        _hypertension.toDouble(),
        _heartDisease.toDouble(),
        double.parse(_glucoseCtrl.text),
        double.parse(_bmiCtrl.text),
      ];
      
      var res = await RiskPredictionService().predictStroke(inputs);
      setState(() {
        _riskScore = res['risk'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Stroke Risk Assessment")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            _buildInfoTile(),
            SizedBox(height: 12),
            _buildTipsCard(),
            SizedBox(height: 20),
            
            Text("Health Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            
            _buildInput("Age", _ageCtrl, "Years"),
            _buildInput("Avg Glucose Level", _glucoseCtrl, "mg/dL"),
            _buildInput("BMI", _bmiCtrl, "e.g., 25.5"),
            
            SwitchListTile(
              title: Text("Do you have Hypertension?"),
              value: _hypertension == 1,
              onChanged: (v) => setState(() => _hypertension = v ? 1 : 0),
            ),
            SwitchListTile(
              title: Text("History of Heart Disease?"),
              value: _heartDisease == 1,
              onChanged: (v) => setState(() => _heartDisease = v ? 1 : 0),
            ),
            
            SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: EdgeInsets.all(15), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              onPressed: _loading ? null : _predict,
              child: Text(_loading ? "Analyzing..." : "Calculate Risk"),
            ),
            
            if (_riskScore != null) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Simple Explanation", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              "A stroke happens when blood flow to part of the brain is blocked. This tool estimates your risk based on your lifestyle and health history.",
              style: TextStyle(color: Colors.blue.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Recommendations", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
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

  Widget _buildInput(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, hintText: hint, border: OutlineInputBorder()),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _buildResult() {
    bool isHigh = _riskScore! > 0.5;
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHigh ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isHigh ? Colors.red : Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(isHigh ? "High Risk Detected" : "Low Risk", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isHigh ? Colors.red : Colors.green)),
                SizedBox(height: 5),
                Text("Probability: ${(_riskScore! * 100).toStringAsFixed(1)}%"),
              ],
            ),
          ),
          Divider(),
          Text("Recommendations", style: TextStyle(fontWeight: FontWeight.bold)),
          ..._recommendations.map((tip) => Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.arrow_right, color: Colors.blue),
                Expanded(child: Text(tip)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
