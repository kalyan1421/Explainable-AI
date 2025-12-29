import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get user => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // Sign Up with Role (Patient or Doctor)
  Future<String?> signUp({
    required String email, 
    required String password, 
    required String name, 
    required String role, // 'doctor' or 'patient'
    int? age,
    String? gender,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      
      // Save rich profile data
      await _db.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'name': name,
        'email': email,
        'role': role,
        'age': age,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // Sign In
  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Get Role for Routing
  Future<String> getUserRole() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.get('role') ?? 'patient';
      }
    }
    return 'patient'; // Default
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Verify Doctor Registration Code against admin collection
  Future<bool> verifyDoctorCode(String code) async {
    try {
      // Get the admin document from Firebase
      DocumentSnapshot adminDoc = await _db.collection('admin').doc('admin').get();
      
      if (!adminDoc.exists) {
        print("⚠️ Admin document not found");
        return false;
      }
      
      // Get the stored code
      String? storedCode = adminDoc.get('code')?.toString();
      
      if (storedCode == null) {
        print("⚠️ Doctor code not set in admin collection");
        return false;
      }
      
      // Compare codes
      bool isValid = code == storedCode;
      print(isValid ? "✅ Doctor code verified" : "❌ Invalid doctor code");
      return isValid;
      
    } catch (e) {
      print("❌ Error verifying doctor code: $e");
      return false;
    }
  }

  // Update user profile
  Future<String?> updateProfile({
    String? name,
    int? age,
    String? gender,
    String? bloodGroup,
    String? phone,
  }) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return "User not logged in";

      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (age != null) updates['age'] = age;
      if (gender != null) updates['gender'] = gender;
      if (bloodGroup != null) updates['bloodGroup'] = bloodGroup;
      if (phone != null) updates['phone'] = phone;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _db.collection('users').doc(user.uid).update(updates);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}