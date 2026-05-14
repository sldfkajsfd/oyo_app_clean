import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../mvp_shared.dart';

class SubstitutionService {
  SubstitutionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> applyToRequest({
    required String requestId,
    required String userId,
  }) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      throw Exception('사용자 정보를 찾을 수 없어요.');
    }

    final userData = userDoc.data() ?? {};
    final userStoreId = userData['storeId']?.toString();
    final applicantName =
        (userData['userName'] ?? userData['displayName'] ?? '알바생').toString();

    if (userStoreId == null || userStoreId.isEmpty) {
      throw Exception('먼저 매장에 참여해 주세요.');
    }

    final requestRef = _firestore.collection('sub_requests').doc(requestId);
    final applicationRef = _firestore
        .collection('applications')
        .doc('${requestId}_$userId');

    Map<String, dynamic>? requestData;

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      if (!requestSnapshot.exists) {
        throw Exception('요청을 찾을 수 없어요.');
      }

      final data = requestSnapshot.data() ?? {};
      requestData = data;
      final requestStoreId = data['storeId']?.toString();
      final requesterId = requestOwnerId(data);
      final status = MvpStatus.request(data['status']);

      if (requestStoreId != userStoreId) {
        throw Exception('같은 매장의 요청만 지원할 수 있어요.');
      }
      if (requesterId == userId) {
        throw Exception('내가 올린 요청에는 지원할 수 없어요.');
      }
      if (status != MvpStatus.open) {
        throw Exception('이미 마감된 요청이에요.');
      }

      final existingApplication = await transaction.get(applicationRef);
      if (existingApplication.exists) {
        throw Exception('이미 지원한 요청이에요.');
      }

      transaction.set(applicationRef, {
        'requestId': requestId,
        'storeId': userStoreId,
        'applicantId': userId,
        'applicantName': applicantName,
        'status': MvpStatus.applied,
        'appliedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    final data = requestData;
    if (data != null) {
      await _notifyManagers(
        storeId: userStoreId,
        requestId: requestId,
        message: '$applicantName님이 ${requestOwnerName(data)}님의 대타 요청에 지원했어요.',
      );
    }
  }

  Future<void> approveApplication({
    required String requestId,
    required String applicationId,
    required String managerId,
  }) async {
    final managerDoc =
        await _firestore.collection('users').doc(managerId).get();
    if (!managerDoc.exists) {
      throw Exception('매니저 정보를 찾을 수 없어요.');
    }

    final managerData = managerDoc.data() ?? {};
    final managerStoreId = managerData['storeId']?.toString();
    final managerRole = managerData['role']?.toString();

    if (!isManagerRole(managerRole)) {
      throw Exception('매니저만 승인할 수 있어요.');
    }
    if (managerStoreId == null || managerStoreId.isEmpty) {
      throw Exception('매장 정보가 없는 계정이에요.');
    }

    final applicationsSnapshot =
        await _firestore
            .collection('applications')
            .where('storeId', isEqualTo: managerStoreId)
            .get();
    final applicationDocs =
        applicationsSnapshot.docs
            .where((doc) => doc.data()['requestId'] == requestId)
            .toList();

    if (applicationDocs.isEmpty) {
      throw Exception('지원자가 없어요.');
    }

    final requestRef = _firestore.collection('sub_requests').doc(requestId);
    final selectedApplicationRef = _firestore
        .collection('applications')
        .doc(applicationId);
    final scheduleRef = _firestore
        .collection('substitution_schedule')
        .doc(requestId);

    late Map<String, dynamic> requestData;
    late Map<String, dynamic> selectedApplicationData;

    await _firestore.runTransaction((transaction) async {
      final requestSnapshot = await transaction.get(requestRef);
      final selectedApplicationSnapshot = await transaction.get(
        selectedApplicationRef,
      );

      if (!requestSnapshot.exists) {
        throw Exception('요청을 찾을 수 없어요.');
      }
      if (!selectedApplicationSnapshot.exists) {
        throw Exception('선택한 지원자를 찾을 수 없어요.');
      }

      requestData = requestSnapshot.data() ?? {};
      selectedApplicationData = selectedApplicationSnapshot.data() ?? {};

      final requestStoreId = requestData['storeId']?.toString();
      final selectedRequestId =
          selectedApplicationData['requestId']?.toString();
      final status = MvpStatus.request(requestData['status']);

      if (requestStoreId != managerStoreId || selectedRequestId != requestId) {
        throw Exception('내 매장의 요청만 승인할 수 있어요.');
      }
      if (status != MvpStatus.open) {
        throw Exception('이미 처리된 요청이에요.');
      }

      final selectedApplicantId =
          selectedApplicationData['applicantId']?.toString() ?? '';
      final selectedApplicantName =
          (selectedApplicationData['applicantName'] ?? '알바생').toString();

      for (final appDoc in applicationDocs) {
        final isSelected = appDoc.id == applicationId;
        transaction.update(appDoc.reference, {
          'status': isSelected ? MvpStatus.approved : MvpStatus.rejected,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final start = asDateTime(requestData['startTime'])!;
      final end = asDateTime(requestData['endTime'])!;

      transaction.update(requestRef, {
        'status': MvpStatus.approved,
        'approvedApplicationId': applicationId,
        'approvedApplicantId': selectedApplicantId,
        'approvedApplicantName': selectedApplicantName,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(scheduleRef, {
        'requestId': requestId,
        'applicationId': applicationId,
        'storeId': managerStoreId,
        'date': DateFormat('yyyy-MM-dd').format(start),
        'startTime': DateFormat('a h:mm', 'ko').format(start),
        'endTime': DateFormat('a h:mm', 'ko').format(end),
        'startTimestamp': Timestamp.fromDate(start),
        'endTimestamp': Timestamp.fromDate(end),
        'fromUser': requestOwnerName(requestData),
        'fromUserId': requestOwnerId(requestData),
        'toUser': selectedApplicantName,
        'toUserId': selectedApplicantId,
        'reason': requestData['reason'] ?? '',
        'memo': requestData['memo'] ?? '',
        'status': MvpStatus.approved,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _writeApprovalNotifications(
      requestId: requestId,
      requestData: requestData,
      applications: applicationDocs,
      selectedApplicationId: applicationId,
      selectedApplicationData: selectedApplicationData,
    );
  }

  Future<void> _notifyManagers({
    required String storeId,
    required String requestId,
    required String message,
  }) async {
    final managersSnapshot =
        await _firestore
            .collection('users')
            .where('storeId', isEqualTo: storeId)
            .get();

    final batch = _firestore.batch();
    for (final managerDoc in managersSnapshot.docs) {
      if (!isManagerRole(managerDoc.data()['role']?.toString())) continue;
      final notificationRef =
          managerDoc.reference.collection('notifications').doc();
      batch.set(notificationRef, {
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'type': 'application',
        'read': false,
      });
    }
    await batch.commit();
  }

  Future<void> _writeApprovalNotifications({
    required String requestId,
    required Map<String, dynamic> requestData,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
    required String selectedApplicationId,
    required Map<String, dynamic> selectedApplicationData,
  }) async {
    final batch = _firestore.batch();
    final requesterId = requestOwnerId(requestData);
    final selectedApplicantId =
        selectedApplicationData['applicantId']?.toString() ?? '';
    final selectedApplicantName =
        (selectedApplicationData['applicantName'] ?? '알바생').toString();
    final periodText = formatTimeRange(requestData);

    if (requesterId.isNotEmpty) {
      final requesterNotification =
          _firestore
              .collection('users')
              .doc(requesterId)
              .collection('notifications')
              .doc();
      batch.set(requesterNotification, {
        'message': '$periodText 대타가 $selectedApplicantName님으로 확정됐어요.',
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'type': 'approval',
        'read': false,
      });
    }

    if (selectedApplicantId.isNotEmpty) {
      final selectedNotification =
          _firestore
              .collection('users')
              .doc(selectedApplicantId)
              .collection('notifications')
              .doc();
      batch.set(selectedNotification, {
        'message': '$periodText 대타 지원이 승인됐어요.',
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'type': 'approval',
        'read': false,
      });
    }

    for (final appDoc in applications) {
      if (appDoc.id == selectedApplicationId) continue;
      final applicantId = appDoc.data()['applicantId']?.toString();
      if (applicantId == null || applicantId.isEmpty) continue;
      final notificationRef =
          _firestore
              .collection('users')
              .doc(applicantId)
              .collection('notifications')
              .doc();
      batch.set(notificationRef, {
        'message': '$periodText 대타 지원은 다른 분으로 확정됐어요.',
        'createdAt': FieldValue.serverTimestamp(),
        'requestId': requestId,
        'type': 'approval',
        'read': false,
      });
    }

    await batch.commit();
  }
}
