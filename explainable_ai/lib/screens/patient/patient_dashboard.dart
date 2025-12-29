import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../heart_risk_screen.dart';
import '../diabetes_risk_screen.dart';
import '../pneumonia_screen.dart';
import 'history_screen.dart';
import '../profile_screen.dart';

class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;
  final AuthService _auth = AuthService();

  final List<Widget> _tabs = [
    HomeTab(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: "Screening"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("AI Health Screening"), automaticallyImplyLeading: false),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _menuCard(context, "Heart Disease", "Cardiovascular Risk Analysis", Icons.favorite, Colors.red, HeartRiskScreen()),
          _menuCard(context, "Diabetes", "Glucose & Metabolic Analysis", Icons.water_drop, Colors.blue, DiabetesRiskScreen()),
          _menuCard(context, "Pneumonia", "Chest X-Ray Analysis", Icons.image, Colors.purple, PneumoniaScreen()),
        ],
      ),
    );
  }

  Widget _menuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget page) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 15),
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        leading: CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}