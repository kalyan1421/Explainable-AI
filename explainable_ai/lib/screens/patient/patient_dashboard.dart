import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../heart_risk_screen.dart';
import '../diabetes_risk_screen.dart';
import '../pneumonia_screen.dart';
import '../skin_cancer_screen.dart';
import '../stroke_risk_screen.dart';
import '../fetal_health_screen.dart';
import '../parkinsons_screen.dart';
import 'history_screen.dart';
import '../profile_screen.dart';
import '../health_chat_screen.dart';

class PatientDashboard extends StatefulWidget {
  @override
  _PatientDashboardState createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentIndex = 0;
  final AuthService _auth = AuthService();

  final List<Widget> _tabs = [HomeTab(), HistoryScreen(), HealthChatScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: "Screening",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chatbot"),
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
      appBar: AppBar(
        title: Text("AI Health Screening"),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: EdgeInsets.all(20),
        children: [
          _menuCard(
            context,
            "Heart Disease",
            "Cardiovascular Risk Analysis",
            Icons.favorite,
            Colors.red,
            HeartRiskScreen(),
          ),
          _menuCard(
            context,
            "Diabetes",
            "Glucose & Metabolic Analysis",
            Icons.water_drop,
            Colors.blue,
            DiabetesRiskScreen(),
          ),
          _menuCard(
            context,
            "Pneumonia",
            "Chest X-Ray Analysis",
            Icons.image,
            Colors.purple,
            PneumoniaScreen(),
          ),
          _menuCard(
            context,
            "Skin Cancer",
            "Dermatology AI Scanner",
            Icons.face,
            Colors.orange,
            SkinCancerScreen(),
          ),
          _menuCard(
            context,
            "Stroke Risk",
            "Cardiovascular Risk Assessment",
            Icons.warning,
            Colors.deepOrange,
            StrokeRiskScreen(),
          ),
          _menuCard(
            context,
            "Fetal Health",
            "Maternal & Fetal AI Analysis",
            Icons.child_care,
            Colors.pink,
            FetalHealthScreen(),
          ),
          _menuCard(
            context,
            "Parkinson's",
            "Voice pattern analysis",
            Icons.hearing,
            Colors.deepPurple,
            ParkinsonsScreen(),
          ),
          _menuCard(
            context,
            "Health Chatbot",
            "Ask health-only questions safely",
            Icons.chat_bubble_outline,
            Colors.teal,
            HealthChatScreen(),
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget page,
  ) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 15),
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      ),
    );
  }
}
