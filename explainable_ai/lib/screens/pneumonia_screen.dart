import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class PneumoniaScreen extends StatefulWidget {
  @override
  State<PneumoniaScreen> createState() => _PneumoniaScreenState();
}

class _PneumoniaScreenState extends State<PneumoniaScreen> {
  File? _image;
  String _result = "Waiting for X-Ray...";
  String _confidence = "";
  bool _isLoading = false;
  Interpreter? _interpreter;

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

  Future<void> _pickImage() async {
    // Request permissions first
    await [Permission.camera, Permission.storage].request();
    
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _isLoading = true;
      });
      await _runInference(_image!);
    }
  }

  Future<void> _runInference(File imageFile) async {
    if (_interpreter == null) return;

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
      _result = isPneumonia ? "PNEUMONIA POSITIVE ⚠️" : "NORMAL ✅";
      _confidence = "Confidence: ${(isPneumonia ? score : 1 - score) * 100}%";
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Pneumonia Detection")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 300, width: 300,
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
              child: _image == null
                  ? Icon(Icons.add_a_photo, size: 50, color: Colors.grey)
                  : Image.file(_image!, fit: BoxFit.cover),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.upload),
              label: Text("Analyze X-Ray"),
            ),
            SizedBox(height: 30),
            if (_isLoading) CircularProgressIndicator(),
            if (!_isLoading && _image != null) ...[
              Text(_result, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _result.contains("NORMAL") ? Colors.green : Colors.red)),
              Text(_confidence),
            ]
          ],
        ),
      ),
    );
  }
}