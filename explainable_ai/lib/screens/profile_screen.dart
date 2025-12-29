import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'patient/medical_details_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseService _db = FirebaseService();
  final AuthService _auth = AuthService();

  Future<void> _openMedicalDetails(Map<String, dynamic>? data) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicalDetailsScreen(initialData: data),
      ),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Medical details updated"), backgroundColor: Colors.green),
      );
    }
  }

  void _showEditDialog(Map<String, dynamic>? data) {
    final nameCtrl = TextEditingController(text: data?['name'] ?? '');
    final ageCtrl = TextEditingController(text: data?['age']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: data?['phone'] ?? '');
    String gender = data?['gender'] ?? 'Male';
    String bloodGroup = data?['bloodGroup'] ?? 'O+';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit Profile"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: "Name",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: ageCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Age",
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: gender,
                  decoration: InputDecoration(
                    labelText: "Gender",
                    prefixIcon: Icon(Icons.wc),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ["Male", "Female", "Other"].map((g) => 
                    DropdownMenuItem(value: g, child: Text(g))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => gender = v!),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: bloodGroup,
                  decoration: InputDecoration(
                    labelText: "Blood Group",
                    prefixIcon: Icon(Icons.bloodtype),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"].map((b) => 
                    DropdownMenuItem(value: b, child: Text(b))
                  ).toList(),
                  onChanged: (v) => setDialogState(() => bloodGroup = v!),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Phone",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                String? error = await _auth.updateProfile(
                  name: nameCtrl.text.isNotEmpty ? nameCtrl.text : null,
                  age: int.tryParse(ageCtrl.text),
                  gender: gender,
                  bloodGroup: bloodGroup,
                  phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
                );
                Navigator.pop(context);
                if (error == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Profile updated!"), backgroundColor: Colors.green)
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $error"), backgroundColor: Colors.red)
                  );
                }
              },
              child: Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Profile"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(),
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text("Profile not found"));
          }
          
          var data = snapshot.data!.data() as Map<String, dynamic>?;

          return ListView(
            padding: EdgeInsets.all(20),
            children: [
              // Avatar
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.blue.shade100,
                      child: Icon(Icons.person, size: 60, color: Colors.blue.shade700),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue,
                        child: IconButton(
                          icon: Icon(Icons.edit, size: 18, color: Colors.white),
                          onPressed: () => _showEditDialog(data),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),
              
              // Name
              Center(
                child: Text(
                  data?['name'] ?? "N/A",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 8),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text("Patient", style: TextStyle(color: Colors.green.shade800)),
                ),
              ),
              SizedBox(height: 30),
              
              // Info Cards
              _buildInfoCard("Personal Information", [
                _infoRow(Icons.email, "Email", data?['email'] ?? "N/A"),
                _infoRow(Icons.wc, "Gender", data?['gender'] ?? "Not set"),
                _infoRow(Icons.phone, "Phone", data?['phone'] ?? "Not set"),
              ]),
              SizedBox(height: 16),
              _buildInfoCard("Medical Details", [
                _infoRow(Icons.cake, "Age", data?['age']?.toString() ?? "Not set"),
                _infoRow(Icons.bloodtype, "Blood Group", data?['bloodGroup'] ?? "Not set"),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openMedicalDetails(data),
                    icon: Icon(Icons.edit_note),
                    label: Text("Update Medical Details"),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ]),
              SizedBox(height: 16),
              
              _buildInfoCard("Account", [
                _infoRow(Icons.calendar_today, "Member Since", _formatDate(data?['createdAt'])),
                _infoRow(Icons.update, "Last Updated", _formatDate(data?['updatedAt'])),
              ]),
              SizedBox(height: 24),
              
              // Edit Button
              ElevatedButton.icon(
                onPressed: () => _showEditDialog(data),
                icon: Icon(Icons.edit),
                label: Text("Edit Profile"),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
            Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String title, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      DateTime date = timestamp.toDate();
      return "${date.day}/${date.month}/${date.year}";
    }
    return "N/A";
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
