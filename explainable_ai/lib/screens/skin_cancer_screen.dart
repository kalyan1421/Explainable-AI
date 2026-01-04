import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/risk_prediction_service.dart';

class SkinCancerScreen extends StatefulWidget {
  @override
  _SkinCancerScreenState createState() => _SkinCancerScreenState();
}

class _SkinCancerScreenState extends State<SkinCancerScreen> {
  final RiskPredictionService _aiService = RiskPredictionService();
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _result;

  // Recommendations based on labels
  final Map<String, String> _recommendations = {
    'Melanoma': "Consult a dermatologist URGENTLY. Avoid sun exposure and cover the area.",
    'Basal cell carcinoma': "Schedule an appointment with a skin specialist. It is treatable but needs attention.",
    'Nevus': "This appears to be a common mole. Monitor it monthly for any changes in shape or color.",
    'Benign keratosis': "Likely harmless. Use sunscreen to prevent further skin damage.",
  };

  final List<String> _generalTips = const [
    "Wear sunscreen (SPF 30+) daily.",
    "Monitor existing moles for changes in size, shape, or color.",
    "Avoid direct sun exposure between 10 AM and 4 PM.",
  ];

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
      _result = null;
    });

    try {
      var bytes = await _image!.readAsBytes();
      var res = await _aiService.predictSkinCancer(bytes);
      
      setState(() {
        _result = res;
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
      appBar: AppBar(title: Text("Skin Health Scanner")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildExplanationCard(),
            SizedBox(height: 12),
            _buildTipsCard(),
            SizedBox(height: 20),

            // Image Preview
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
                image: _image != null ? DecorationImage(image: FileImage(_image!), fit: BoxFit.cover) : null
              ),
              child: _image == null 
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [Icon(Icons.add_a_photo, size: 50, color: Colors.grey), Text("Upload a photo of the mole/spot")],
                    ) 
                  : null,
            ),
            SizedBox(height: 20),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: Icon(Icons.camera_alt), label: Text("Camera")),
                ElevatedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: Icon(Icons.photo_library), label: Text("Gallery")),
              ],
            ),
            SizedBox(height: 30),

            // Results
            if (_loading) CircularProgressIndicator(),
            if (_result != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
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
              "This checks for abnormal skin growths. It looks at moles or spots to see if they might be dangerous (like Melanoma) or harmless (Benign).",
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
            Text("Everyday Recommendations", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            ..._generalTips.map((tip) => Padding(
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
    String label = _result!['label'];
    double confidence = _result!['confidence'];
    bool isRisk = label == 'Melanoma' || label == 'Basal cell carcinoma';
    String recText = _recommendations[label] ?? "Please consult a doctor for a professional opinion.";

    return Column(
      children: [
        Card(
          elevation: 4,
          color: isRisk ? Colors.red.shade50 : Colors.green.shade50,
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(isRisk ? Icons.warning : Icons.check_circle, size: 50, color: isRisk ? Colors.red : Colors.green),
                SizedBox(height: 10),
                Text(label, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text("Confidence: ${(confidence * 100).toStringAsFixed(1)}%"),
              ],
            ),
          ),
        ),
        SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(15),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: Colors.orange, width: 4)),
            color: Colors.grey.shade50,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Recommendation:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 5),
              Text(recText),
            ],
          ),
        )
      ],
    );
  }
}

