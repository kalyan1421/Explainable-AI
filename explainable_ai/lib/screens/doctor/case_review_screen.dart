import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../../widgets/feature_importance_chart.dart'; // Reuse your existing widget

class CaseReviewScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String recordId;

  const CaseReviewScreen({required this.data, required this.recordId});

  @override
  _CaseReviewScreenState createState() => _CaseReviewScreenState();
}

class _CaseReviewScreenState extends State<CaseReviewScreen> {
  final FirebaseService _db = FirebaseService();
  final TextEditingController _noteCtrl = TextEditingController();
  String _status = "Pending Review";

  @override
  void initState() {
    super.initState();
    _status = widget.data['status'] ?? "Pending Review";
    _noteCtrl.text = widget.data['doctorNotes'] ?? "";
  }

  void _saveReview() async {
    await _db.submitReview(
      recordId: widget.recordId,
      status: _status,
      notes: _noteCtrl.text
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Review Saved Successfully")));
  }

  @override
  Widget build(BuildContext context) {
    // Process Features for Chart
    List<Map<String, dynamic>> features = [];
    if (widget.data['explanation'] != null) {
      Map<String, dynamic> raw = widget.data['explanation'];
      features = raw.entries.map((e) => {'feature': e.key, 'importance': e.value}).toList();
      features.sort((a, b) => (b['importance'] as num).compareTo(a['importance']));
      if (features.length > 5) features = features.sublist(0, 5);
    }

    return Scaffold(
      appBar: AppBar(title: Text("Review Case")),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header
            Text("Patient: ${widget.data['patientName']}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text("AI Predicted Risk: ${(widget.data['riskScore'] * 100).toStringAsFixed(1)}%", 
              style: TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.w600)),
            Divider(height: 30),

            // AI Explanation
            Text("AI Reasoning (Top Factors):", style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            FeatureImportanceChart(features: features, title: "Impact on Prediction"),
            
            // Raw Inputs
            SizedBox(height: 20),
            ExpansionTile(
              title: Text("View Clinical Data Inputs"),
              children: [
                Container(
                  height: 150,
                  child: ListView(
                    children: (widget.data['inputs'] as Map<String, dynamic>).entries.map((e) {
                      return ListTile(title: Text(e.key), trailing: Text(e.value.toString()));
                    }).toList(),
                  ),
                )
              ],
            ),
            Divider(height: 30),

            // Doctor Action Area
            Text("Clinical Validation", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              items: ["Pending Review", "Confirmed", "Rejected", "Needs Tests", "False Positive"]
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _status = v!),
              decoration: InputDecoration(border: OutlineInputBorder(), labelText: "Status"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _noteCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Clinical Notes",
                hintText: "Add your observations..."
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saveReview,
              icon: Icon(Icons.save),
              label: Text("Submit Review"),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white
              ),
            )
          ],
        ),
      ),
    );
  }
}