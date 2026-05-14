import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import 'firebase_service.dart';

class AuthService {
  static Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        final credential = await FirebaseAuth.instance.signInWithPopup(
          provider,
        );
        await FirebaseService().saveFcmTokenToFirestore();
        return credential.user;
      }

      final googleUser = await GoogleSignIn().signIn();
      final googleAuth = await googleUser?.authentication;
      if (googleUser == null || googleAuth == null) return null;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      await FirebaseService().saveFcmTokenToFirestore();
      return userCredential.user;
    } catch (error) {
      debugPrint('Google sign-in failed: $error');
      return null;
    }
  }

  static Future<bool> signInWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirebaseService().saveFcmTokenToFirestore();
      return true;
    } catch (error) {
      debugPrint('Email sign-in failed: $error');
      return false;
    }
  }

  static Future<void> signOut() async {
    if (!kIsWeb) {
      await GoogleSignIn().signOut();
    }
    await FirebaseAuth.instance.signOut();
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;
}
