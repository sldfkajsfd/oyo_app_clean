import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:oyo_app_clean/services/firebase_service.dart'; // ✅ FCM 토큰 저장용 import 추가

class AuthService {
  // ✅ Google 로그인 (Popup 방식)
  static Future<User?> signInWithGoogle() async {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      final GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

      if (googleUser == null || googleAuth == null) {
        print("⚠️ Google 로그인 취소됨 또는 실패");
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      print("✅ Popup 로그인 성공: ${userCredential.user?.email}");

      // ✅ 로그인 성공 후 FCM 토큰 저장
      await FirebaseService().saveFcmTokenToFirestore();

      return userCredential.user;
    } catch (e) {
      print("❌ Google 로그인 오류: $e");
      return null;
    }
  }

  // ✅ 이메일 로그인
  static Future<bool> signInWithEmail(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ 로그인 성공 후 FCM 토큰 저장
      await FirebaseService().saveFcmTokenToFirestore();

      return true;
    } catch (e) {
      print("❌ 이메일 로그인 오류: $e");
      return false;
    }
  }

  static Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  static User? get currentUser => FirebaseAuth.instance.currentUser;
}
