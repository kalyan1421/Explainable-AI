import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> savePredictionToCloud(
    String modelType,
    Map<String, dynamic> inputData,
    Map<String, dynamic> result,
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('predictions')
        .add({
      'model_type': modelType,
      'input_data': inputData,
      'result': result,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}