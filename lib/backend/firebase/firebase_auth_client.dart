import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseAuthClient {
  FirebaseAuthClient({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Future<String> signInAnonymouslyAndGetUid() async {
    final UserCredential credential =
        await _auth.signInAnonymously();
    final String? uid = credential.user?.uid;
    if (uid == null) {
      throw StateError('Firebase anonymous user uid is null');
    }
    debugPrint(
      '[Firebase][Auth] signed in anonymously uid=$uid',
    );
    return uid;
  }
}

