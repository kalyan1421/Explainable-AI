import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get userId => _auth.currentUser?.uid;
  
  // --- USER PROFILE ---
  Stream<DocumentSnapshot> getUserProfile() {
    if (userId == null) return const Stream.empty();
    return _db.collection('users').doc(userId).snapshots();
  }

  // --- 1. SAVE RECORD (Patient Action) ---
  Future<void> saveRecord({
    required String title,
    required double riskScore,
    required String riskLevel,
    required Map<String, dynamic> inputs,
    required Map<String, dynamic> explanation,
  }) async {
    if (userId == null) return;

    // Fetch Patient Name
    DocumentSnapshot userDoc = await _db.collection('users').doc(userId).get();
    String userName = userDoc.get('name') ?? "Unknown";

    // Save to GLOBAL 'records' collection for Doctors to see
    await _db.collection('records').add({
      'patientId': userId,
      'patientName': userName,
      'title': title,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'inputs': inputs,
      'explanation': explanation,
      'timestamp': FieldValue.serverTimestamp(),
      
      // Clinical Workflow Fields
      'status': 'Pending Review', // Initial status
      'doctorNotes': '',
      'reviewedBy': '',
      'reviewedAt': null,
    });
  }

  // --- 2. GET MY HISTORY (Patient View) ---
  Stream<QuerySnapshot> getPatientHistory() {
    if (userId == null) return const Stream.empty();
    return _db.collection('records')
        .where('patientId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- 3. GET ALL RECORDS (Doctor View) ---
  Stream<QuerySnapshot> getDoctorFeed() {
    // Doctors see everything, sorted by newest
    return _db.collection('records')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // --- 4. REVIEW CASE (Doctor Action) ---
  Future<void> submitReview({
    required String recordId,
    required String status, // Confirmed, Rejected, etc.
    required String notes,
  }) async {
    User? doctor = _auth.currentUser;
    
    // Update the record
    await _db.collection('records').doc(recordId).update({
      'status': status,
      'doctorNotes': notes,
      'reviewedBy': doctor?.email ?? 'Doctor',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    
    // Add audit log
    await _addAuditLog(
      action: 'REVIEW_CASE',
      recordId: recordId,
      details: {'status': status, 'hasNotes': notes.isNotEmpty},
    );
  }

  // --- 5. AUDIT LOGGING (For Traceability) ---
  Future<void> _addAuditLog({
    required String action,
    String? recordId,
    Map<String, dynamic>? details,
  }) async {
    User? user = _auth.currentUser;
    await _db.collection('audit_logs').add({
      'userId': user?.uid,
      'userEmail': user?.email,
      'action': action,
      'recordId': recordId,
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
      'deviceInfo': 'Flutter Mobile App',
    });
  }

  // --- 6. GET AUDIT LOGS (Doctor View) ---
  Stream<QuerySnapshot> getAuditLogs({int limit = 50}) {
    return _db.collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // --- 7. GET PATIENT RECORDS FOR DOCTOR ---
  Stream<QuerySnapshot> getPatientRecords(String patientId) {
    return _db.collection('records')
        .where('patientId', isEqualTo: patientId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Log prediction event
  Future<void> logPrediction(String modelType) async {
    await _addAuditLog(
      action: 'RUN_PREDICTION',
      details: {'modelType': modelType},
    );
  }
}