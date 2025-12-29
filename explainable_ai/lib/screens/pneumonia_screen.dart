import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../services/firebase_service.dart';
import '../services/database_helper.dart';

class PneumoniaScreen extends StatefulWidget {
  @override
  State<PneumoniaScreen> createState() => _PneumoniaScreenState();
}

class _PneumoniaScreenState extends State<PneumoniaScreen> {
  File? _image;
  String _result = "";
  double _confidence = 0.0;
  bool _isLoading = false;
  bool _showResult = false;
  Interpreter? _interpreter;
  
  final FirebaseService _db = FirebaseService();
  final DatabaseHelper _localDb = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/pneumonia_model.tflite');
      print("✅ X-Ray Model Loaded");
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // Request permissions first
    if (source == ImageSource.camera) {
      await Permission.camera.request();
    } else {
      await Permission.storage.request();
    }
    
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isLoading = true;
        _showResult = false;
      });
      await _runInference(_image!);
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Model not loaded"), backgroundColor: Colors.red)
      );
      return;
    }

    try {
      // 1. Preprocess: Resize to 224x224 & Normalize
      var imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      img.Image resizedImage = img.copyResize(originalImage!, width: 224, height: 224);

      // 2. Convert to Float32 List [1, 224, 224, 3]
      var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
        var pixel = resizedImage.getPixel(x, y);
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      })));

      // 3. Inference
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);
      _interpreter!.run(input, output);

      double score = output[0][0];
      bool isPneumonia = score > 0.5;

      setState(() {
        _result = isPneumonia ? "PNEUMONIA DETECTED" : "NORMAL";
        _confidence = isPneumonia ? score : 1 - score;
        _isLoading = false;
        _showResult = true;
      });

      // Save to Firebase and SQLite
      String riskLevel = isPneumonia ? "High" : "Low";
      Map<String, dynamic> inputs = {"imagePath": imageFile.path};
      Map<String, dynamic> resultData = {
        "risk": score,
        "isPneumonia": isPneumonia,
        "explanation": {"X-Ray Analysis": isPneumonia ? score : 1 - score},
      };
      
      await _db.saveRecord(
        title: "Pneumonia",
        riskScore: score,
        riskLevel: riskLevel,
        inputs: inputs,
        explanation: resultData['explanation'],
      );
      
      await _localDb.savePrediction("pneumonia", inputs, resultData);
      await _db.logPrediction("pneumonia");

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error analyzing image: $e"), backgroundColor: Colors.red)
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Pneumonia Detection"),
        backgroundColor: Colors.purple.shade50,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // AI Disclaimer
            _buildDisclaimer(),
            SizedBox(height: 20),
            
            // Image Preview
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _image == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, size: 60, color: Colors.grey.shade400),
                        SizedBox(height: 10),
                        Text("Upload Chest X-Ray", style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_image!, fit: BoxFit.cover),
                    ),
            ),
            SizedBox(height: 20),
            
            // Upload Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    icon: Icon(Icons.photo_library),
                    label: Text("Gallery"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                    icon: Icon(Icons.camera_alt),
                    label: Text("Camera"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.purple.shade400,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),
            
            // Loading Indicator
            if (_isLoading)
              Column(
                children: [
                  CircularProgressIndicator(color: Colors.purple),
                  SizedBox(height: 10),
                  Text("Analyzing X-Ray...", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
            
            // Results
            if (_showResult && !_isLoading) ...[
              _buildResultCard(),
              SizedBox(height: 20),
              _buildExplanationCard(),
            ],
          ],
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
              "AI is an assistant, not a doctor. X-ray analysis should be confirmed by a radiologist.",
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    bool isPneumonia = _result.contains("PNEUMONIA");
    
    return Card(
      color: isPneumonia ? Colors.red.shade50 : Colors.green.shade50,
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              isPneumonia ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              size: 60,
              color: isPneumonia ? Colors.red : Colors.green,
            ),
            SizedBox(height: 12),
            Text(
              _result,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: isPneumonia ? Colors.red : Colors.green,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Confidence: ${(_confidence * 100).toStringAsFixed(1)}%",
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    bool isPneumonia = _result.contains("PNEUMONIA");
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text("AI Explanation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue.shade800)),
            ],
          ),
          SizedBox(height: 12),
          Text(
            isPneumonia 
              ? "The AI detected patterns in the X-ray that are consistent with pneumonia. Areas of opacity or consolidation may indicate infection. Please consult a healthcare professional for proper diagnosis and treatment."
              : "The AI did not detect significant patterns associated with pneumonia in this X-ray. The lung fields appear relatively clear. However, this should be confirmed by a qualified radiologist.",
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            "Note: Grad-CAM visualization highlighting affected areas can be added for enhanced explainability.",
            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
