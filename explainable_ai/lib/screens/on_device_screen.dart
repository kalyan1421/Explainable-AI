import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Rename to avoid conflict with Flutter Image widget

class OnDeviceScreen extends StatefulWidget {
  const OnDeviceScreen({super.key});

  @override
  State<OnDeviceScreen> createState() => _OnDeviceScreenState();
}

class _OnDeviceScreenState extends State<OnDeviceScreen> {
  File? _selectedImage;
  String _result = "Waiting for image...";
  String _confidence = "";
  bool _isLoading = false;
  
  Interpreter? _interpreter;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestPermissions(); // Ask permissions on app open
    _loadModel();
  }

  // 1. Request Permissions on Startup
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
    ].request();

    if (statuses[Permission.camera]!.isDenied || statuses[Permission.photos]!.isDenied) {
      _showSnackBar("Permissions are required to use this app.");
    }
  }

  // 2. Load TFLite Model
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/pneumonia_model.tflite');
      print("Model Loaded Successfully");
    } catch (e) {
      print("Error loading model: $e");
      _showSnackBar("Failed to load model.");
    }
  }

  // 3. Pick Image
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _result = "Analyzing...";
        _confidence = "";
      });
      // Run inference immediately after picking
      _runInference(_selectedImage!);
    }
  }

  // 4. Run On-Device Inference
  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) return;

    setState(() => _isLoading = true);

    // A. Preprocess Image (Resize to 224x224 & Normalize)
    // Note: This must match your Python training preprocessing (1./255)
    var imageBytes = await imageFile.readAsBytes();
    var decodedImage = img.decodeImage(imageBytes);
    var resizedImage = img.copyResize(decodedImage!, width: 224, height: 224);

    // Convert to Float32 List [1, 224, 224, 3]
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      var pixel = resizedImage.getPixel(x, y);
      return [
        pixel.r / 255.0, // Normalize 0-1
        pixel.g / 255.0,
        pixel.b / 255.0
      ];
    })));

    // B. Setup Output
    // Output shape [1, 1] for binary classification (Sigmoid)
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

    // C. Run Interpreter
    _interpreter!.run(input, output);

    // D. Interpret Results
    double score = output[0][0];
    bool isPneumonia = score > 0.5;
    
    // Calculate display confidence (0.5 to 1.0 -> 50% to 100%)
    double confidenceValue = isPneumonia ? score : (1 - score);

    setState(() {
      _isLoading = false;
      _result = isPneumonia ? "PNEUMONIA" : "NORMAL";
      _confidence = "${(confidenceValue * 100).toStringAsFixed(1)}%";
    });
  }

  void _showSnackBar(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("On-Device AI Doctor")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
              child: _selectedImage == null
                  ? const Center(child: Text("No Image Selected"))
                  : Image.file(_selectedImage!, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage, 
              child: const Text("Upload X-Ray")
            ),
            const SizedBox(height: 30),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _selectedImage != null) ...[
              Text(
                _result, 
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: _result == "PNEUMONIA" ? Colors.red : Colors.green
                )
              ),
              Text("Confidence: $_confidence", style: const TextStyle(fontSize: 18)),
            ]
          ],
        ),
      ),
    );
  }
}