import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/heart_risk_screen.dart';
import 'screens/diabetes_risk_screen.dart';
import 'screens/pneumonia_screen.dart'; // Renamed from on_device_screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Explainable AI Healthcare',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Health Diagnostics')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMenuButton(
              context, 
              "Heart Disease Risk", 
              Icons.favorite, 
              Colors.redAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => HeartRiskScreen())),
            ),
            SizedBox(height: 20),
            _buildMenuButton(
              context, 
              "Diabetes Risk", 
              Icons.water_drop, 
              Colors.blueAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiabetesRiskScreen())),
            ),
            SizedBox(height: 20),
            _buildMenuButton(
              context, 
              "Pneumonia Detection (X-Ray)", 
              Icons.image_search, 
              Colors.purpleAccent,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => PneumoniaScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 30, color: Colors.white),
      label: Text(title, style: TextStyle(fontSize: 18, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}