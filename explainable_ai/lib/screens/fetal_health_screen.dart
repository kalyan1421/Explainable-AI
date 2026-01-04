import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';

class FetalHealthScreen extends StatefulWidget {
  @override
  _FetalHealthScreenState createState() => _FetalHealthScreenState();
}

class _FetalHealthScreenState extends State<FetalHealthScreen> {
  // Default values for a healthy pregnancy
  final _heartRateCtrl = TextEditingController(text: "140"); 
  final _movementCtrl = TextEditingController(text: "0.0"); 
  final _contractionsCtrl = TextEditingController(text: "0.005"); 
  
  String? _resultLabel;
  double? _confidence;

  final List<String> _recommendations = const [
    "Count fetal kicks daily (aim for 10 movements in 2 hours).",
    "Stay hydrated and rest on your left side to improve blood flow.",
    "Attend all scheduled prenatal checkups.",
  ];

  void _analyze() async {
    List<double> inputs = [
      double.parse(_heartRateCtrl.text),
      double.parse(_movementCtrl.text),
      double.parse(_contractionsCtrl.text),
    ];
    
    var res = await RiskPredictionService().predictFetalHealth(inputs);
    setState(() {
      _resultLabel = res['label'];
      _confidence = res['confidence'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Maternal & Fetal Monitor")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _buildExplanationCard(),
            SizedBox(height: 12),
            _buildRecommendationsCard(),
            SizedBox(height: 20),

            Text("Enter CTG Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text("Normally obtained from your doctor's report.", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),
            
            _buildField("Baseline Heart Rate (bpm)", _heartRateCtrl, "Normal: 110-160"),
            _buildField("Fetal Movements (per sec)", _movementCtrl, "Activity level"),
            _buildField("Uterine Contractions (per sec)", _contractionsCtrl, "Frequency"),
            
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _analyze, 
                child: Padding(padding: EdgeInsets.all(12), child: Text("Analyze Health")),
              ),
            ),
            
            if (_resultLabel != null) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      color: Colors.pink.shade50,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Simple Explanation", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              "This assesses the well-being of your baby using heart rate and movement data. It helps identify if the baby is healthy or needs a closer look by a doctor.",
              style: TextStyle(color: Colors.pink.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsCard() {
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

  Widget _buildField(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, helperText: hint, border: OutlineInputBorder()),
      ),
    );
  }

  Widget _buildResult() {
    Color color = _resultLabel == "Normal" ? Colors.green : (_resultLabel == "Suspect" ? Colors.orange : Colors.red);
    String rec = "";
    if (_resultLabel == "Normal") rec = "Everything looks good! Continue monitoring kicks daily.";
    else if (_resultLabel == "Suspect") rec = "Readings are slightly off. Drink water, rest on your side, and re-test in 1 hour.";
    else rec = "Please contact your OB/GYN immediately for a check-up.";

    return Card(
      margin: EdgeInsets.only(top: 20),
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_resultLabel!, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 5),
            Text("Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%"),
            Divider(),
            Text(rec, textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

