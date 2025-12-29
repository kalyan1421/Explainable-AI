import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Role-based access control guard
class RoleGuard {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Check if current user has the required role
  static Future<bool> hasRole(String requiredRole) async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return false;
      
      String userRole = doc.get('role') ?? 'patient';
      return userRole == requiredRole;
    } catch (e) {
      return false;
    }
  }

  /// Get current user's role
  static Future<String> getCurrentRole() async {
    User? user = _auth.currentUser;
    if (user == null) return 'patient';

    try {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) return 'patient';
      return doc.get('role') ?? 'patient';
    } catch (e) {
      return 'patient';
    }
  }

  /// Widget wrapper that checks role before showing content
  static Widget protectedScreen({
    required String requiredRole,
    required Widget child,
    Widget? fallback,
  }) {
    return FutureBuilder<bool>(
      future: hasRole(requiredRole),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          return child;
        }

        // Access denied
        return fallback ?? _accessDeniedScreen(context, requiredRole);
      },
    );
  }

  static Widget _accessDeniedScreen(BuildContext context, String requiredRole) {
    return Scaffold(
      appBar: AppBar(title: Text("Access Denied")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 80, color: Colors.red.shade300),
            SizedBox(height: 20),
            Text(
              "Access Denied",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              "This screen is only available for ${requiredRole}s.",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Go Back"),
            ),
          ],
        ),
      ),
    );
  }
}

