  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:firebase_messaging/firebase_messaging.dart';

  class FirebaseService {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final User? _currentUser = FirebaseAuth.instance.currentUser;

    /// FCM 토큰을 Firestore에 저장
    Future<void> saveFcmTokenToFirestore() async {
      try {
        if (_currentUser == null) {
          print('⚠️ 로그인된 유저가 없습니다.');
          return;
        }

        final token = await FirebaseMessaging.instance.getToken();
        if (token == null) {
          print('⚠️ FCM 토큰을 받아오지 못했습니다.');
          return;
        }

        await _firestore.collection('users').doc(_currentUser!.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));

        print('✅ FCM 토큰을 Firestore에 저장 완료');
      } catch (e) {
        print('❌ FCM 토큰 저장 중 오류: $e');
      }
    }
  }
