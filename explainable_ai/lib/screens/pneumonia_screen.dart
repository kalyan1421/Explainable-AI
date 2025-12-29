import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Rename to avoid conflict

class OnDeviceScreen extends StatefulWidget {
  const OnDeviceScreen({super.key});

  @override
  State<OnDeviceScreen> createState() => _OnDeviceScreenState();
}

class _OnDeviceScreenState extends State<OnDeviceScreen> {
  File? _image;
  String _result = "Waiting for X-Ray...";
  String _confidence = "";
  bool _isLoading = false;
  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadModel();
  }

  // 1. Check & Request Permissions on Open
  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
    ].request();

    if (statuses[Permission.camera]!.isDenied || statuses[Permission.photos]!.isDenied) {
      _showSnack("Permissions are required to use this feature.");
    }
  }

  // 2. Load the TFLite Model
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/pneumonia_model.tflite');
      print("AI Model Loaded");
    } catch (e) {
      print("Error loading model: $e");
      _showSnack("Failed to load AI Model");
    }
  }

  // 3. Pick Image
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isLoading = true;
      });
      // Run AI immediately
      await _runInference(_image!);
    }
  }

  // 4. Run AI (The Brain)
  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) {
      _showSnack("Model not loaded yet.");
      return;
    }

    // A. Preprocess Image (Resize to 224x224 & Normalize to 0-1)
    var imageBytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    img.Image resizedImage = img.copyResize(originalImage!, width: 224, height: 224);

    // Convert pixels to input array [1, 224, 224, 3]
    var input = List.generate(1, (i) => List.generate(224, (y) => List.generate(224, (x) {
      var pixel = resizedImage.getPixel(x, y);
      return [
        pixel.r / 255.0,
        pixel.g / 255.0,
        pixel.b / 255.0
      ];
    })));

    // B. Setup Output Container [1, 1]
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

    // C. Run
    _interpreter!.run(input, output);

    // D. Parse Result
    double score = output[0][0];
    bool isPneumonia = score > 0.5;

    setState(() {
      _result = isPneumonia ? "PNEUMONIA DETECTED" : "NORMAL";
      _confidence = "${(isPneumonia ? score : 1 - score) * 100}% Confidence";
      _isLoading = false;
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Doctor (Offline)")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Image Display
            Container(
              height: 300,
              width: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12)
              ),
              child: _image == null
                  ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                  : ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_image!, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 20),
            
            // Upload Button
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload X-Ray"),
            ),

            const SizedBox(height: 30),

            // Results
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _image != null) ...[
              Text(
                _result,
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: _result.contains("NORMAL") ? Colors.green : Colors.red
                ),
              ),
              Text(_confidence, style: const TextStyle(fontSize: 18, color: Colors.grey)),
            ]
          ],
        ),
      ),
    );
  }
}