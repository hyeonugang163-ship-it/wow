import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseUserProfileRepository {
  FirebaseUserProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> upsertUserProfile({
    required String uid,
    required String appEnv,
    required String platform,
  }) async {
    final DocumentReference<Map<String, dynamic>> docRef =
        _firestore.collection('users').doc(uid);

    await docRef.set(
      <String, Object?>{
        'uid': uid,
        'appEnv': appEnv,
        'platform': platform,
        'lastLoginAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    debugPrint(
      '[Firebase][UserProfile] upserted uid=$uid env=$appEnv platform=$platform',
    );
  }
}

