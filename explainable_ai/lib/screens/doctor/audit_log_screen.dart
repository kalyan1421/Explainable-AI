import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';

class AuditLogScreen extends StatelessWidget {
  final FirebaseService _db = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getAuditLogs(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text("No audit logs yet", style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        var logs = snapshot.data!.docs;

        return Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Audit Trail", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Spacer(),
                  Text("${logs.length} entries", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                padding: EdgeInsets.all(10),
                itemBuilder: (context, index) {
                  var data = logs[index].data() as Map<String, dynamic>;
                  
                  String action = data['action'] ?? 'Unknown';
                  String userEmail = data['userEmail'] ?? 'Unknown User';
                  String dateStr = "Unknown";
                  if (data['timestamp'] != null) {
                    dateStr = DateFormat('MMM d, yyyy h:mm a').format(
                      (data['timestamp'] as Timestamp).toDate()
                    );
                  }

                  // Action Icon & Color
                  IconData actionIcon = Icons.info;
                  Color actionColor = Colors.blue;
                  
                  switch (action) {
                    case 'RUN_PREDICTION':
                      actionIcon = Icons.analytics;
                      actionColor = Colors.purple;
                      break;
                    case 'REVIEW_CASE':
                      actionIcon = Icons.rate_review;
                      actionColor = Colors.green;
                      break;
                    case 'SAVE_RECORD':
                      actionIcon = Icons.save;
                      actionColor = Colors.orange;
                      break;
                  }

                  // Details
                  String details = "";
                  if (data['details'] != null) {
                    Map<String, dynamic> d = data['details'];
                    if (d.containsKey('modelType')) {
                      details = "Model: ${d['modelType'].toString().toUpperCase()}";
                    }
                    if (d.containsKey('status')) {
                      details = "Status: ${d['status']}";
                    }
                  }

                  return Card(
                    margin: EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: actionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(actionIcon, color: actionColor),
                      ),
                      title: Text(_formatAction(action), style: TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 4),
                          Text(userEmail, style: TextStyle(fontSize: 12)),
                          if (details.isNotEmpty)
                            Text(details, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          SizedBox(height: 4),
                          Text(dateStr, style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _showLogDetails(context, data),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatAction(String action) {
    switch (action) {
      case 'RUN_PREDICTION': return 'AI Prediction Run';
      case 'REVIEW_CASE': return 'Case Reviewed';
      case 'SAVE_RECORD': return 'Record Saved';
      default: return action.replaceAll('_', ' ');
    }
  }

  void _showLogDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 10),
            Text("Log Details"),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow("Action", _formatAction(data['action'] ?? '')),
              _detailRow("User", data['userEmail'] ?? 'Unknown'),
              _detailRow("User ID", data['userId'] ?? 'N/A'),
              if (data['recordId'] != null)
                _detailRow("Record ID", data['recordId']),
              _detailRow("Device", data['deviceInfo'] ?? 'Unknown'),
              if (data['timestamp'] != null)
                _detailRow("Timestamp", DateFormat('yyyy-MM-dd HH:mm:ss').format(
                  (data['timestamp'] as Timestamp).toDate()
                )),
              if (data['details'] != null) ...[
                SizedBox(height: 10),
                Text("Additional Details:", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 5),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(data['details'].toString()),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

