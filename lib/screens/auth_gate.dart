import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mvp_shared.dart';
import '../services/firebase_service.dart';
import 'admin_main_navigation_page.dart';
import 'login_screen.dart';
import 'main_navigation_page.dart';
import 'store_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future:
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final userDoc = userSnapshot.data;
            final userData = userDoc?.data();
            final storeId = userData?['storeId']?.toString();
            final role = userData?['role']?.toString();

            if (userData == null || storeId == null || storeId.isEmpty) {
              return StoreSetupScreen(existingData: userData);
            }

            FirebaseService().saveFcmTokenToFirestore();

            if (isManagerRole(role)) {
              return const AdminMainNavigationPage();
            }
            return const MainNavigationPage();
          },
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
