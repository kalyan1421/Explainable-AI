import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import '../../services/firebase_service.dart';
import '../../services/database_helper.dart';
import 'prediction_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final FirebaseService _db = FirebaseService();
  final DatabaseHelper _localDb = DatabaseHelper();
  late TabController _tabController;
  List<Map<String, dynamic>> _offlineHistory = [];
  String? _reportInProgressId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOfflineHistory();
  }

  Future<void> _loadOfflineHistory() async {
    final history = await _localDb.getAllPredictions();
    setState(() => _offlineHistory = history);
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> data, {bool isOffline = false}) async {
    final pdf = pw.Document();
    String title = isOffline ? _getModelTitle(data['model_type']) : (data['title'] ?? 'Assessment');
    double riskScore = isOffline ? (data['risk_score'] ?? 0.0) : (data['riskScore'] ?? 0.0);
    String riskLevel = isOffline ? (data['risk_level'] ?? 'Unknown') : (data['riskLevel'] ?? 'Unknown');
    String patientName = data['patientName'] ?? 'Patient';
    String? heatmapUrl = data['heatmapUrl'];

    List<MapEntry<String, double>> topFactors = _extractTopFactors(data);
    pw.ImageProvider? heatmapImage;

    if (heatmapUrl != null && heatmapUrl.toString().isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(heatmapUrl));
        if (resp.statusCode == 200) {
          heatmapImage = pw.MemoryImage(resp.bodyBytes);
        }
      } catch (_) {
        // Ignore heatmap failures; PDF still generates.
      }
    }
    
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text(
                  "Explainable AI - Medical Report",
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text("Patient: $patientName", style: pw.TextStyle(fontSize: 14)),
              pw.Text("Date: ${DateFormat('yMMMd').format(DateTime.now())}", style: pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 16),
              pw.Text("Assessment: $title", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text("Prediction: ${riskLevel.toUpperCase()} ( ${(riskScore * 100).toStringAsFixed(1)}% )"),
              if (!isOffline) ...[
                pw.SizedBox(height: 10),
                pw.Text("Doctor Review Status: ${data['status'] ?? 'Pending'}",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                if (data['doctorNotes']?.toString().isNotEmpty ?? false)
                  pw.Text("Doctor Notes: ${data['doctorNotes']}"),
              ],
              pw.SizedBox(height: 16),
              if (topFactors.isNotEmpty) ...[
                pw.Text("Top Factors", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  headers: const ['Feature', 'Importance'],
                  data: topFactors
                      .map((e) => [e.key, (e.value * 100).toStringAsFixed(2) + "%"])
                      .toList(),
                ),
                pw.SizedBox(height: 16),
              ],
              if (heatmapImage != null) ...[
                pw.Text("Visual Explainability (Grad-CAM)",
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 200,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: PdfColors.grey300),
                  ),
                  child: pw.ClipRRect(
                    verticalRadius: 8,
                    horizontalRadius: 8,
                    child: pw.Image(heatmapImage, fit: pw.BoxFit.cover),
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                "Disclaimer: This report is generated by an AI system for informational purposes only. "
                "It should not be used as a substitute for professional medical advice, diagnosis, or treatment. "
                "Always consult a qualified healthcare provider.",
                style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              ),
            ],
          );
        },
      ),
    );
    
    return Uint8List.fromList(await pdf.save());
  }

  List<MapEntry<String, double>> _extractTopFactors(Map<String, dynamic> data) {
    if (data['explanation'] is Map) {
      final Map raw = data['explanation'];
      final parsed = raw.entries
          .where((e) => e.value is num)
          .map<MapEntry<String, double>>((e) => MapEntry(e.key.toString(), (e.value as num).toDouble()))
          .toList();
      parsed.sort((a, b) => b.value.compareTo(a.value));
      return parsed.take(5).toList();
    }
    return [];
  }

  String _getModelTitle(String? modelType) {
    switch (modelType) {
      case 'heart': return 'Heart Disease';
      case 'diabetes': return 'Diabetes';
      case 'pneumonia': return 'Pneumonia';
      default: return 'Health Assessment';
    }
  }

  IconData _getModelIcon(String? modelType) {
    switch (modelType) {
      case 'heart': return Icons.favorite;
      case 'diabetes': return Icons.water_drop;
      case 'pneumonia': return Icons.image;
      default: return Icons.medical_services;
    }
  }

  Color _getModelColor(String? modelType) {
    switch (modelType) {
      case 'heart': return Colors.red;
      case 'diabetes': return Colors.blue;
      case 'pneumonia': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Medical History"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.cloud), text: "Cloud"),
            Tab(icon: Icon(Icons.phone_android), text: "Offline"),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _loadOfflineHistory();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCloudHistory(),
          _buildOfflineHistory(),
        ],
      ),
    );
  }

  Future<void> _handleReportAction({
    required Map<String, dynamic> data,
    required String? recordId,
    required bool isOffline,
    required bool share,
  }) async {
    final inProgressKey = recordId ?? 'offline';
    setState(() => _reportInProgressId = inProgressKey);

    try {
      Uint8List? pdfBytes;

      // Re-use existing stored PDF if available
      if (!isOffline && data['reportUrl'] != null) {
        try {
          final resp = await http.get(Uri.parse(data['reportUrl']));
          if (resp.statusCode == 200) {
            pdfBytes = resp.bodyBytes;
          }
        } catch (_) {
          // fall back to regenerate
        }
      }

      pdfBytes ??= await _buildPdfBytes(data, isOffline: isOffline);

      if (!isOffline && recordId != null && data['reportUrl'] == null) {
        try {
          final url = await _db.uploadReportForRecord(recordId, pdfBytes);
          data['reportUrl'] = url; // cache for subsequent taps
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Upload failed: $e"), backgroundColor: Colors.red),
          );
        }
      }

      if (share) {
        await Printing.sharePdf(bytes: pdfBytes!, filename: 'medical_report.pdf');
      } else {
        await Printing.layoutPdf(onLayout: (_) async => pdfBytes!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not generate report: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _reportInProgressId = null);
    }
  }

  Widget _buildCloudHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getPatientHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                SizedBox(height: 16),
                Text("Unable to connect to cloud", style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => _tabController.animateTo(1),
                  child: Text("View Offline History"),
                ),
              ],
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        var docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          padding: EdgeInsets.all(10),
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String recordId = docs[index].id;
            return _buildCloudHistoryCard(data, recordId);
          },
        );
      },
    );
  }

  Widget _buildCloudHistoryCard(Map<String, dynamic> data, String recordId) {
    // UI logic for status
    IconData statusIcon = Icons.access_time;
    Color statusColor = Colors.orange;
    if (data['status'] == 'Confirmed') { statusIcon = Icons.check_circle; statusColor = Colors.green; }
    if (data['status'] == 'Rejected') { statusIcon = Icons.cancel; statusColor = Colors.red; }
    if (data['status'] == 'Needs Tests') { statusIcon = Icons.science; statusColor = Colors.blue; }

    String dateStr = "Unknown";
    if (data['timestamp'] != null) {
      dateStr = DateFormat('MMM d, yyyy - h:mm a').format(
        (data['timestamp'] as Timestamp).toDate()
      );
    }

    bool isHighRisk = (data['riskScore'] ?? 0) > 0.5;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PredictionDetailScreen(
                data: data,
                recordId: recordId,
                isDoctor: false,
              ),
            ),
          );
        },
        child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getModelColor(data['title']?.toString().toLowerCase().split(' ')[0]).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getModelIcon(data['title']?.toString().toLowerCase().split(' ')[0]),
            color: _getModelColor(data['title']?.toString().toLowerCase().split(' ')[0]),
          ),
        ),
        title: Text(data['title'] ?? 'Assessment', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                SizedBox(width: 5),
                Text(data['status'] ?? 'Pending', style: TextStyle(color: statusColor, fontSize: 12)),
              ],
            ),
            Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHighRisk ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${((data['riskScore'] ?? 0) * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighRisk ? Colors.red : Colors.green,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Risk Level
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHighRisk ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(isHighRisk ? Icons.warning : Icons.check_circle, 
                        color: isHighRisk ? Colors.red : Colors.green),
                      SizedBox(width: 10),
                      Text(
                        "Risk Level: ${data['riskLevel'] ?? 'Unknown'}",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                
                // Doctor's Notes
                Text("Doctor's Review:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
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
                SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _reportInProgressId == recordId
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(Icons.picture_as_pdf),
                        label: Text(_reportInProgressId == recordId ? "Preparing..." : "Download Report"),
                        onPressed: _reportInProgressId == recordId
                            ? null
                            : () => _handleReportAction(
                                  data: data,
                                  recordId: recordId,
                                  isOffline: false,
                                  share: false,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.share),
                        label: Text("Share with Doctor"),
                        onPressed: _reportInProgressId == recordId
                            ? null
                            : () => _handleReportAction(
                                  data: data,
                                  recordId: recordId,
                                  isOffline: false,
                                  share: true,
                                ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: Icon(Icons.visibility),
                  label: Text("View Full Details"),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PredictionDetailScreen(
                          data: data,
                          recordId: recordId,
                          isDoctor: false,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildOfflineHistory() {
    if (_offlineHistory.isEmpty) {
      return _buildEmptyState(isOffline: true);
    }

    return RefreshIndicator(
      onRefresh: _loadOfflineHistory,
      child: ListView.builder(
        itemCount: _offlineHistory.length,
        padding: EdgeInsets.all(10),
        itemBuilder: (context, index) {
          var data = _offlineHistory[index];
          return _buildOfflineHistoryCard(data, index);
        },
      ),
    );
  }

  Widget _buildOfflineHistoryCard(Map<String, dynamic> data, int index) {
    String modelType = data['model_type'] ?? '';
    String title = _getModelTitle(modelType);
    double riskScore = data['risk_score'] ?? 0.0;
    String riskLevel = data['risk_level'] ?? 'Unknown';
    bool isHighRisk = riskScore > 0.5;
    bool isSynced = data['synced'] == 1;
    
    String dateStr = "Unknown";
    if (data['timestamp'] != null) {
      dateStr = DateFormat('MMM d, yyyy - h:mm a').format(DateTime.parse(data['timestamp']));
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getModelColor(modelType).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_getModelIcon(modelType), color: _getModelColor(modelType)),
        ),
        title: Row(
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(
              isSynced ? Icons.cloud_done : Icons.cloud_off,
              size: 16,
              color: isSynced ? Colors.green : Colors.orange,
            ),
          ],
        ),
        subtitle: Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey)),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isHighRisk ? Colors.red.shade100 : Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${(riskScore * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isHighRisk ? Colors.red : Colors.green,
            ),
          ),
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Risk Level
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isHighRisk ? Colors.red.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(isHighRisk ? Icons.warning : Icons.check_circle, 
                        color: isHighRisk ? Colors.red : Colors.green),
                      SizedBox(width: 10),
                      Text("Risk Level: $riskLevel", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                
                // Sync Status
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSynced ? Colors.green.shade50 : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSynced ? Icons.cloud_done : Icons.cloud_upload,
                        color: isSynced ? Colors.green : Colors.orange,
                      ),
                      SizedBox(width: 10),
                      Text(
                        isSynced ? "Synced to cloud" : "Stored locally (will sync when online)",
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _reportInProgressId == 'offline_$modelType$index'
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Icon(Icons.picture_as_pdf),
                        label: Text(_reportInProgressId == 'offline_$modelType$index'
                            ? "Preparing..."
                            : "Download Report"),
                        onPressed: _reportInProgressId == 'offline_$modelType$index'
                            ? null
                            : () => _handleReportAction(
                                  data: data,
                                  recordId: 'offline_$modelType$index',
                                  isOffline: true,
                                  share: false,
                                ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.share),
                        label: Text("Share"),
                        onPressed: _reportInProgressId == 'offline_$modelType$index'
                            ? null
                            : () => _handleReportAction(
                                  data: data,
                                  recordId: 'offline_$modelType$index',
                                  isOffline: true,
                                  share: true,
                                ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({bool isOffline = false}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isOffline ? Icons.phone_android : Icons.history,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            isOffline ? "No offline records" : "No medical records yet",
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            isOffline 
              ? "Records will be stored here when you're offline"
              : "Complete an AI health screening to see your history",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
