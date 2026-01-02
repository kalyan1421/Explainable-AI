import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../services/heatmap_helper.dart';
import '../services/firebase_service.dart';
import '../services/database_helper.dart';

class PneumoniaScreen extends StatefulWidget {
  @override
  State<PneumoniaScreen> createState() => _PneumoniaScreenState();
}

class _PneumoniaScreenState extends State<PneumoniaScreen> {
  File? _image;
  Uint8List? _heatmapOverlay;
  String _result = "Upload X-Ray";
  double _confidence = 0.0;
  bool _isLoading = false;
  
  Interpreter? _interpreter;
  List<double>? _denseWeights;
  
  final FirebaseService _db = FirebaseService();
  final DatabaseHelper _localDb = DatabaseHelper();

  final String _simpleExplanation = "Pneumonia is an infection that inflames the air sacs in one or both lungs. This tool scans chest X-rays for signs of infection.";
  final List<String> _recommendations = const [
    "Finish all prescribed antibiotics, drink plenty of fluids, and get plenty of rest.",
  ];

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      // 1. Load Multi-Output Model
      _interpreter = await Interpreter.fromAsset('assets/pneumonia_xai_model.tflite');
      
      // 2. Load Weights JSON
      String jsonString = await rootBundle.loadString('assets/pneumonia_weights.json');
      var jsonData = json.decode(jsonString);
      _denseWeights = List<double>.from(jsonData['weights']);
      
      print("✅ Offline XAI System Ready. Weights loaded: ${_denseWeights?.length}");
    } catch (e) {
      print("❌ Error loading assets: $e");
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null || _denseWeights == null) return;

    setState(() => _isLoading = true);

    try {
      // --- A. Preprocess ---
      var imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      img.Image resized = img.copyResize(originalImage!, width: 224, height: 224);

      var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
        var p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      // --- B. Prepare Outputs ---
      // Get Output Tensor Shapes dynamically
      var outputTensors = _interpreter!.getOutputTensors();
      var shape0 = outputTensors[0].shape; // Prediction [1, 1]
      var shape1 = outputTensors[1].shape; // Features [1, 7, 7, 1280] or similar

      var outputPred = List.filled(shape0.reduce((a, b) => a * b), 0.0).reshape(shape0);
      var outputFeatures = List.filled(shape1.reduce((a, b) => a * b), 0.0).reshape(shape1);

      var outputs = {0: outputPred, 1: outputFeatures};

      // --- C. Run Inference ---
      _interpreter!.runForMultipleInputs([input], outputs);

      // --- D. Process Results ---
      double risk = outputPred[0][0];
      
      // --- E. Generate Heatmap ---
      Uint8List? heatmapBytes;
      if (risk > 0.3) { 
        // Flatten features
        List<double> flatFeatures = (outputFeatures[0] as List)
            .expand((row) => (row as List).expand((col) => (col as List<double>)))
            .toList()
            .cast<double>();

        // DYNAMIC CALCULATION (Fixes the crash)
        int channels = _denseWeights!.length; // Use actual weights length (e.g., 128)
        int totalFeatures = flatFeatures.length;
        
        // Ensure dimensions match to prevent crash
        if (totalFeatures % channels == 0) {
           int gridSize = sqrt(totalFeatures / channels).toInt(); // e.g. 7
           
           heatmapBytes = HeatmapHelper.generateHeatmap(
            flatFeatures, 
            _denseWeights!, 
            gridSize, 
            channels, 
            300, 300 
          );
        } else {
          print("⚠️ Warning: Feature/Weight mismatch. Features: $totalFeatures, Weights: $channels");
        }
      }

      setState(() {
        _confidence = risk;
        _result = risk > 0.5 ? "PNEUMONIA DETECTED" : "NORMAL";
        _heatmapOverlay = heatmapBytes;
        _isLoading = false;
      });

      // Save to Firebase and SQLite
      String riskLevel = risk > 0.5 ? "High" : "Low";
      Map<String, dynamic> inputs = {"imagePath": imageFile.path};
      Map<String, dynamic> explanation = {
        "X-Ray Analysis": risk,
        "hasHeatmap": heatmapBytes != null,
      };
      
      await _db.saveRecord(
        title: "Pneumonia",
        riskScore: risk,
        riskLevel: riskLevel,
        inputs: inputs,
        explanation: explanation,
      );
      
      await _localDb.savePrediction("pneumonia", inputs, {"risk": risk, "explanation": explanation});
      await _db.logPrediction("pneumonia");

    } catch (e) {
      print("❌ Inference Error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _heatmapOverlay = null;
        _result = "Analyzing...";
      });
      await _runInference(_image!);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDanger = _confidence > 0.5;

    return Scaffold(
      appBar: AppBar(title: Text("Visual X-Ray Analysis")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPatientFriendlyCard(),
            SizedBox(height: 12),
            Container(
              height: 300, width: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12)
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_image != null) 
                    Image.file(_image!, fit: BoxFit.cover),
                  if (_heatmapOverlay != null)
                    Opacity(
                      opacity: 0.6,
                      child: Image.memory(_heatmapOverlay!, fit: BoxFit.cover, gaplessPlayback: true),
                    ),
                  if (_image == null)
                    Center(child: Icon(Icons.add_photo_alternate, size: 60, color: Colors.grey)),
                  if (_isLoading)
                    Container(color: Colors.black45, child: Center(child: CircularProgressIndicator())),
                ],
              ),
            ),
            SizedBox(height: 15),
            if (_heatmapOverlay != null)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.circle, color: Colors.red.withOpacity(0.6), size: 16),
                SizedBox(width: 8),
                Text("Red Highlights = AI Focus Area", style: TextStyle(fontWeight: FontWeight.bold)),
              ]),
            SizedBox(height: 20),
            Card(
              elevation: 4,
              color: isDanger ? Colors.red.shade50 : Colors.green.shade50,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(_result, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDanger ? Colors.red : Colors.green)),
                    Text("Confidence: ${(_confidence * 100).toStringAsFixed(1)}%", style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.upload_file),
              label: Text("Select X-Ray Image"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18)
              ),
            ),
          ],
        ),
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
}
