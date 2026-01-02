import 'package:flutter/material.dart';
import '../services/risk_prediction_service.dart';

class ParkinsonsScreen extends StatefulWidget {
  @override
  _ParkinsonsScreenState createState() => _ParkinsonsScreenState();
}

class _ParkinsonsScreenState extends State<ParkinsonsScreen> {
  // Input Controllers with default "Healthy" values
  final _jitterCtrl = TextEditingController(text: "0.006"); // Voice Stability
  final _shimmerCtrl = TextEditingController(text: "0.03"); // Loudness Stability
  final _nhrCtrl = TextEditingController(text: "0.02");     // Noise Ratio
  
  double? _score;
  bool _loading = false;

  final List<String> _recommendations = const [
    "Engage in physical therapy or regular stretching.",
    "Practice speaking loud and clear (speech therapy).",
    "Maintain a balanced diet rich in fiber.",
  ];

  void _analyze() async {
    setState(() => _loading = true);
    await Future.delayed(Duration(seconds: 1));
    
    try {
      List<double> inputs = [
        double.parse(_jitterCtrl.text),
        double.parse(_shimmerCtrl.text),
        double.parse(_nhrCtrl.text),
      ];
      
      var res = await RiskPredictionService().predictParkinsons(inputs);
      setState(() {
        _score = res['score'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Voice Pattern Analysis")),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildExplanationCard(),
          SizedBox(height: 12),
          _buildRecommendationsCard(),
          SizedBox(height: 20),

          Text("Voice Metrics", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          SizedBox(height: 10),
          _buildInput("Voice Stability (%)", _jitterCtrl, "Measures pitch stability (Lower is better)"),
          _buildInput("Loudness Stability (dB)", _shimmerCtrl, "Measures loudness stability"),
          _buildInput("Noise-to-Harmonics Ratio", _nhrCtrl, "Voice clarity/breathiness"),

          SizedBox(height: 20),
          ElevatedButton.icon(
            icon: Icon(Icons.mic),
            label: Text("Analyze Voice Data"),
            style: ElevatedButton.styleFrom(padding: EdgeInsets.all(16), backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: _loading ? null : _analyze,
          ),

          if (_score != null) _buildResult(),
        ],
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Simple Explanation", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text(
              "Parkinson's affects movement and speech. This tool analyzes voice patterns (like tremors or shakiness) to detect early signs.",
              style: TextStyle(color: Colors.purple.shade900),
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

  Widget _buildInput(String label, TextEditingController ctrl, String hint) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.graphic_eq),
        ),
      ),
    );
  }

  Widget _buildResult() {
    bool detected = _score! > 0.5; // Threshold
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: detected ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: detected ? Colors.red : Colors.green),
      ),
      child: Column(
        children: [
          Text(detected ? "Potential Indicators Found" : "No Signs Detected", 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: detected ? Colors.red : Colors.green)),
          SizedBox(height: 10),
          Text(detected 
            ? "The analysis shows voice patterns consistent with early stage Parkinson's. Please visit a neurologist for a full exam."
            : "Your voice metrics appear within the healthy range. Maintain this by reading aloud and staying active.",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
