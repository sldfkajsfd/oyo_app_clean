import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class CreatedStore {
  const CreatedStore({
    required this.storeId,
    required this.storeName,
    required this.inviteCode,
  });

  final String storeId;
  final String storeName;
  final String inviteCode;
}

class StoreOnboardingService {
  StoreOnboardingService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  Future<CreatedStore> createStore({
    required String storeName,
    required String createdBy,
  }) async {
    final storeRef = _firestore.collection('stores').doc();
    final inviteCode = await _generateUniqueInviteCode();
    final cleanedStoreName = storeName.trim();

    final data = {
      'storeId': storeRef.id,
      'storeName': cleanedStoreName,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await storeRef.set(data);

    return CreatedStore(
      storeId: storeRef.id,
      storeName: cleanedStoreName,
      inviteCode: inviteCode,
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findStoreByInviteCode(
    String inviteCode,
  ) async {
    final normalizedCode = normalizeInviteCode(inviteCode);
    if (normalizedCode.isEmpty) return null;

    final snapshot =
        await _firestore
            .collection('stores')
            .where('inviteCode', isEqualTo: normalizedCode)
            .limit(1)
            .get();

    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> ensureInviteCodeForStore({
    required String storeId,
    required String createdBy,
  }) async {
    final storeRef = _firestore.collection('stores').doc(storeId);
    final storeDoc = await storeRef.get();
    if (!storeDoc.exists) return null;

    final data = storeDoc.data() ?? {};
    final existingInviteCode = data['inviteCode']?.toString();
    if (existingInviteCode != null && existingInviteCode.isNotEmpty) {
      return storeDoc;
    }

    final inviteCode = await _generateUniqueInviteCode();
    await storeRef.set({
      'storeId': storeId,
      'inviteCode': inviteCode,
      'createdBy': data['createdBy'] ?? createdBy,
      'createdAt': data['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return storeRef.get();
  }

  String normalizeInviteCode(String inviteCode) {
    return inviteCode.trim().replaceAll(RegExp(r'\s+|-'), '').toUpperCase();
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = _generateInviteCode();
      final existing =
          await _firestore
              .collection('stores')
              .where('inviteCode', isEqualTo: code)
              .limit(1)
              .get();
      if (existing.docs.isEmpty) return code;
    }

    throw Exception('초대 코드를 만들지 못했어요. 잠시 후 다시 시도해 주세요.');
  }

  String _generateInviteCode() {
    const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    return List.generate(
      6,
      (_) => alphabet[_random.nextInt(alphabet.length)],
    ).join();
  }
}
