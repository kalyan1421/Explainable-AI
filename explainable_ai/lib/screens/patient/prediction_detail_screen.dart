import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../widgets/feature_importance_chart.dart';
import '../../services/role_guard.dart';

class PredictionDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final String recordId;
  final bool isDoctor;

  const PredictionDetailScreen({
    required this.data,
    required this.recordId,
    this.isDoctor = false,
  });

  @override
  Widget build(BuildContext context) {
    String title = data['title'] ?? 'Health Assessment';
    double riskScore = (data['riskScore'] ?? 0.0).toDouble();
    String riskLevel = data['riskLevel'] ?? 'Unknown';
    bool isHighRisk = riskScore > 0.5;
    
    String dateStr = "Unknown";
    if (data['timestamp'] != null) {
      dateStr = DateFormat('MMMM d, yyyy - h:mm a').format(
        (data['timestamp'] as Timestamp).toDate()
      );
    }

    // Process explanation for chart
    List<Map<String, dynamic>> explanationFeatures = [];
    if (data['explanation'] != null) {
      Map<String, dynamic> rawExpl = Map<String, dynamic>.from(data['explanation']);
      explanationFeatures = rawExpl.entries
          .where((e) => e.value is num)
          .map((e) => {'feature': e.key, 'importance': (e.value as num).toDouble().abs()})
          .toList();
      explanationFeatures.sort((a, b) => (b['importance'] as double).compareTo(a['importance'] as double));
      if (explanationFeatures.length > 6) {
        explanationFeatures = explanationFeatures.sublist(0, 6);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Prediction Details"),
        actions: [
          IconButton(
            icon: Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(data),
            tooltip: "Download Report",
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Card(
              color: isHighRisk ? Colors.red.shade50 : Colors.green.shade50,
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      _getIconForTitle(title),
                      size: 50,
                      color: isHighRisk ? Colors.red : Colors.green,
                    ),
                    SizedBox(height: 10),
                    Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isHighRisk ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        riskLevel.toUpperCase(),
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Risk Score: ${(riskScore * 100).toStringAsFixed(1)}%",
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 5),
                    Text(dateStr, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Explanation Section
            if (explanationFeatures.isNotEmpty) ...[
              Text(
                isDoctor ? "Clinical Explanation (Full)" : "Why This Result?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              FeatureImportanceChart(
                features: explanationFeatures,
                title: "Top Contributing Factors",
              ),
              SizedBox(height: 10),
              _buildExplanationText(explanationFeatures, riskLevel, isDoctor),
              SizedBox(height: 20),
            ],

            // Input Data Section
            if (isDoctor && data['inputs'] != null) ...[
              Text("Clinical Input Data", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: (data['inputs'] as Map<String, dynamic>).entries.map((e) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key, style: TextStyle(color: Colors.grey.shade700)),
                            Text(e.value.toString(), style: TextStyle(fontWeight: FontWeight.w500)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              SizedBox(height: 20),
            ],

            // Doctor Review Section
            Text("Doctor's Review", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getStatusIcon(data['status']),
                          color: _getStatusColor(data['status']),
                        ),
                        SizedBox(width: 10),
                        Text(
                          data['status'] ?? 'Pending Review',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getStatusColor(data['status']),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text("Doctor's Notes:", style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['doctorNotes']?.toString().isNotEmpty == true
                            ? data['doctorNotes']
                            : "Awaiting doctor review...",
                        style: TextStyle(
                          fontStyle: data['doctorNotes']?.toString().isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                      ),
                    ),
                    if (data['reviewedBy']?.toString().isNotEmpty == true) ...[
                      SizedBox(height: 8),
                      Text(
                        "Reviewed by: ${data['reviewedBy']}",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // AI Disclaimer
            Container(
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
                      "AI predictions are for informational purposes only. Always consult a healthcare professional.",
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Download Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.picture_as_pdf),
                label: Text("Download Full Report"),
                onPressed: () => _generatePdf(data),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationText(List<Map<String, dynamic>> features, String riskLevel, bool isDoctor) {
    if (features.isEmpty) return SizedBox.shrink();

    String topFactors = features.take(3).map((e) => e['feature']).join(", ");
    
    String patientText = "Your $riskLevel risk is primarily influenced by: $topFactors. "
        "These factors had the most impact on the AI's prediction.";
    
    String doctorText = "The model's prediction was primarily driven by the following features: $topFactors. "
        "The feature importance values represent the relative contribution of each input variable to the final prediction. "
        "Consider clinical context when interpreting these values.";

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDoctor ? "Clinical Interpretation" : "Simple Explanation",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800),
          ),
          SizedBox(height: 8),
          Text(isDoctor ? doctorText : patientText, style: TextStyle(fontSize: 13)),
        ],
      ),
    );
  }

  IconData _getIconForTitle(String? title) {
    if (title == null) return Icons.medical_services;
    String lower = title.toLowerCase();
    if (lower.contains('heart')) return Icons.favorite;
    if (lower.contains('diabetes')) return Icons.water_drop;
    if (lower.contains('pneumonia')) return Icons.image;
    return Icons.medical_services;
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'Confirmed': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'Needs Tests': return Icons.science;
      case 'False Positive': return Icons.error_outline;
      default: return Icons.access_time;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Confirmed': return Colors.green;
      case 'Rejected': return Colors.red;
      case 'Needs Tests': return Colors.blue;
      case 'False Positive': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Future<void> _generatePdf(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    
    String title = data['title'] ?? 'Health Assessment';
    double riskScore = (data['riskScore'] ?? 0.0).toDouble();
    String riskLevel = data['riskLevel'] ?? 'Unknown';
    
    pdf.addPage(pw.Page(
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Header(
              level: 0,
              child: pw.Text("Explainable AI - Medical Report",
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.Text("Diagnosis: $title", style: pw.TextStyle(fontSize: 18)),
            pw.Text("Risk Level: $riskLevel",
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text("Risk Score: ${(riskScore * 100).toStringAsFixed(1)}%"),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Text("Doctor Review: ${data['status'] ?? 'Pending'}",
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            if (data['doctorNotes']?.toString().isNotEmpty ?? false)
              pw.Text("Notes: ${data['doctorNotes']}"),
            pw.SizedBox(height: 30),
            pw.Divider(),
            pw.Text(
              "Disclaimer: This report is generated by an AI system for informational purposes only.",
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
            pw.Text("Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}",
                style: pw.TextStyle(fontSize: 10)),
          ],
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
}

