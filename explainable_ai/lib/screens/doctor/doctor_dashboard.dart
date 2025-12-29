import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../services/auth_service.dart';
import 'case_review_screen.dart';
import 'audit_log_screen.dart';

class DoctorDashboard extends StatefulWidget {
  @override
  _DoctorDashboardState createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> {
  final FirebaseService _db = FirebaseService();
  final AuthService _auth = AuthService();
  int _currentIndex = 0;
  String _filterStatus = "All";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Doctor Portal 👨‍⚕️"),
        backgroundColor: Colors.blue.shade50,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filterStatus = value),
            itemBuilder: (context) => [
              PopupMenuItem(value: "All", child: Text("All Cases")),
              PopupMenuItem(value: "Pending Review", child: Text("Pending Review")),
              PopupMenuItem(value: "Confirmed", child: Text("Confirmed")),
              PopupMenuItem(value: "Rejected", child: Text("Rejected")),
            ],
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          )
        ],
      ),
      body: _currentIndex == 0 ? _buildCasesList() : AuditLogScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.medical_services), label: "Cases"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Audit Logs"),
        ],
      ),
    );
  }

  Widget _buildCasesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _db.getDoctorFeed(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData) {
          return Center(child: Text("No cases found"));
        }
        
        var docs = snapshot.data!.docs;
        
        // Apply filter
        if (_filterStatus != "All") {
          docs = docs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return data['status'] == _filterStatus;
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 80, color: Colors.grey.shade400),
                SizedBox(height: 16),
                Text("No ${_filterStatus == 'All' ? '' : _filterStatus.toLowerCase()} cases", 
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              ],
            ),
          );
        }

        // Statistics Header
        int pending = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Pending Review').length;
        int confirmed = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Confirmed').length;
        int rejected = snapshot.data!.docs.where((d) => (d.data() as Map)['status'] == 'Rejected').length;

        return Column(
          children: [
            // Stats Bar
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statBadge("Pending", pending, Colors.orange),
                  _statBadge("Confirmed", confirmed, Colors.green),
                  _statBadge("Rejected", rejected, Colors.red),
                ],
              ),
            ),
            
            // Cases List
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                padding: EdgeInsets.all(10),
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String recordId = docs[index].id;
                  
                  // Formatting
                  bool isHighRisk = data['riskLevel'] == 'High';
                  String dateStr = "Just now";
                  if (data['timestamp'] != null) {
                    dateStr = DateFormat('MMM d, h:mm a').format((data['timestamp'] as Timestamp).toDate());
                  }

                  // Status Badge Color
                  Color statusColor = Colors.orange;
                  if (data['status'] == 'Confirmed') statusColor = Colors.green;
                  if (data['status'] == 'Rejected') statusColor = Colors.red;
                  if (data['status'] == 'Needs Tests') statusColor = Colors.blue;

                  return Card(
                    elevation: 3,
                    margin: EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CaseReviewScreen(data: data, recordId: recordId)
                        ));
                      },
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: Colors.grey.shade200,
                                      child: Icon(Icons.person, color: Colors.grey.shade600),
                                    ),
                                    SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(data['patientName'] ?? 'Patient', 
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                      ],
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: statusColor.withOpacity(0.5)),
                                  ),
                                  child: Text(data['status'], 
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ],
                            ),
                            Divider(height: 20),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isHighRisk ? Colors.red.shade50 : Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getIconForTitle(data['title']),
                                    color: isHighRisk ? Colors.red : Colors.green,
                                    size: 28,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("${data['title']} Assessment", 
                                        style: TextStyle(fontWeight: FontWeight.w600)),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text("Risk: ", style: TextStyle(color: Colors.grey)),
                                          Text("${(data['riskScore'] * 100).toStringAsFixed(1)}%",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isHighRisk ? Colors.red : Colors.green,
                                            )),
                                          SizedBox(width: 10),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isHighRisk ? Colors.red.shade100 : Colors.green.shade100,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(data['riskLevel'] ?? 'Unknown',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ],
                        ),
                      ),
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

  Widget _statBadge(String label, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Text("$count", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  IconData _getIconForTitle(String? title) {
    switch (title) {
      case 'Heart Disease': return Icons.favorite;
      case 'Diabetes': return Icons.water_drop;
      case 'Pneumonia': return Icons.image;
      default: return Icons.medical_services;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _auth.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Logout", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
