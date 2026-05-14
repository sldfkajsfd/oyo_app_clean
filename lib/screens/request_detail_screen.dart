import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mvp_shared.dart';
import '../services/substitution_service.dart';

class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          title: '로그인이 필요해요',
          message: '요청 상세를 보려면 로그인해 주세요.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnapshot.data?.data();
        final storeId = userData?['storeId']?.toString();
        if (storeId == null || storeId.isEmpty) {
          return const Scaffold(
            body: EmptyState(
              title: '매장 정보가 없어요',
              message: '같은 매장의 요청만 확인할 수 있어요.',
              icon: Icons.store_outlined,
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection('sub_requests')
                  .doc(requestId)
                  .snapshots(),
          builder: (context, requestSnapshot) {
            if (requestSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final requestData = requestSnapshot.data?.data();
            if (requestData == null) {
              return const Scaffold(
                body: EmptyState(
                  title: '요청을 찾을 수 없어요',
                  message: '삭제되었거나 접근할 수 없는 요청이에요.',
                  icon: Icons.search_off_outlined,
                ),
              );
            }

            if (requestData['storeId'] != storeId) {
              return const Scaffold(
                body: EmptyState(
                  title: '다른 매장의 요청이에요',
                  message: '매장별로 요청과 지원을 분리해서 보여줘요.',
                  icon: Icons.shield_outlined,
                ),
              );
            }

            return _RequestDetailBody(
              requestId: requestId,
              requestData: requestData,
              userId: user.uid,
              userData: userData ?? {},
              storeId: storeId,
            );
          },
        );
      },
    );
  }
}

class _RequestDetailBody extends StatelessWidget {
  const _RequestDetailBody({
    required this.requestId,
    required this.requestData,
    required this.userId,
    required this.userData,
    required this.storeId,
  });

  final String requestId;
  final Map<String, dynamic> requestData;
  final String userId;
  final Map<String, dynamic> userData;
  final String storeId;

  @override
  Widget build(BuildContext context) {
    final status = MvpStatus.request(requestData['status']);
    final isRequester = requestOwnerId(requestData) == userId;
    final isManager = isManagerRole(userData['role']?.toString());

    return Scaffold(
      appBar: AppBar(title: const Text('요청 상세')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('applications')
                .where('storeId', isEqualTo: storeId)
                .snapshots(),
        builder: (context, appSnapshot) {
          final applications =
              [
                  ...?appSnapshot.data?.docs,
                ].where((doc) => doc.data()['requestId'] == requestId).toList()
                ..sort((a, b) {
                  final aTime =
                      asDateTime(a.data()['appliedAt']) ?? DateTime(1970);
                  final bTime =
                      asDateTime(b.data()['appliedAt']) ?? DateTime(1970);
                  return aTime.compareTo(bTime);
                });

          QueryDocumentSnapshot<Map<String, dynamic>>? myApplication;
          for (final application in applications) {
            if (application.data()['applicantId'] == userId) {
              myApplication = application;
              break;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _InfoCard(requestData: requestData, status: status),
              const SizedBox(height: 12),
              if (status == MvpStatus.approved)
                _ApprovedBox(requestData: requestData)
              else if (isManager)
                _ManagerHint(applicantCount: applications.length)
              else if (isRequester)
                _RequesterHint(applicantCount: applications.length)
              else
                _WorkerApplyBox(
                  requestId: requestId,
                  status: status,
                  userId: userId,
                  myApplication: myApplication,
                ),
              const SizedBox(height: 20),
              Text(
                '지원자',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (applications.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('아직 지원자가 없어요.'),
                  ),
                )
              else
                ...applications.map(
                  (application) => _ApplicationTile(
                    requestId: requestId,
                    application: application,
                    canApprove: isManager && status == MvpStatus.open,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.requestData, required this.status});

  final Map<String, dynamic> requestData;
  final String status;

  @override
  Widget build(BuildContext context) {
    final memo = (requestData['memo'] ?? '').toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatTimeRange(requestData),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                StatusChip(status),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.person_outline,
              label: '요청자',
              value: requestOwnerName(requestData),
            ),
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.chat_bubble_outline,
              label: '사유',
              value: (requestData['reason'] ?? '사유 없음').toString(),
            ),
            if (memo.isNotEmpty) ...[
              const SizedBox(height: 10),
              _InfoRow(icon: Icons.notes_outlined, label: '메모', value: memo),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        SizedBox(
          width: 54,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _WorkerApplyBox extends StatefulWidget {
  const _WorkerApplyBox({
    required this.requestId,
    required this.status,
    required this.userId,
    required this.myApplication,
  });

  final String requestId;
  final String status;
  final String userId;
  final QueryDocumentSnapshot<Map<String, dynamic>>? myApplication;

  @override
  State<_WorkerApplyBox> createState() => _WorkerApplyBoxState();
}

class _WorkerApplyBoxState extends State<_WorkerApplyBox> {
  bool _isApplying = false;

  Future<void> _apply() async {
    setState(() => _isApplying = true);
    try {
      await SubstitutionService().applyToRequest(
        requestId: widget.requestId,
        userId: widget.userId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지원했어요. 매니저 승인까지 기다려 주세요.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appStatus =
        widget.myApplication == null
            ? null
            : MvpStatus.application(widget.myApplication!.data()['status']);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (appStatus != null) ...[
              Row(
                children: [
                  const Expanded(child: Text('내 지원 상태')),
                  StatusChip(appStatus),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                appStatus == MvpStatus.applied
                    ? '지원 완료. 매니저가 한 명을 확정하면 결과가 표시돼요.'
                    : '결과가 확정됐어요.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ] else if (widget.status == MvpStatus.open) ...[
              const Text('이 시간에 가능하다면 조용히 지원해 보세요.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isApplying ? null : _apply,
                child: Text(_isApplying ? '지원 중...' : '지원하기'),
              ),
            ] else
              const Text('이미 마감된 요청이에요.'),
          ],
        ),
      ),
    );
  }
}

class _RequesterHint extends StatelessWidget {
  const _RequesterHint({required this.applicantCount});

  final int applicantCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          applicantCount == 0
              ? '내 요청이에요. 지원자가 생기면 여기에서 확인할 수 있어요.'
              : '지원자 $applicantCount명이 있어요. 매니저가 한 명을 확정합니다.',
        ),
      ),
    );
  }
}

class _ManagerHint extends StatelessWidget {
  const _ManagerHint({required this.applicantCount});

  final int applicantCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          applicantCount == 0
              ? '아직 지원자가 없어요.'
              : '지원자 중 한 명을 승인하면 나머지는 자동으로 미선정 처리돼요.',
        ),
      ),
    );
  }
}

class _ApprovedBox extends StatelessWidget {
  const _ApprovedBox({required this.requestData});

  final Map<String, dynamic> requestData;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF2F855A)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${requestData['approvedApplicantName'] ?? '대타'}님으로 확정됐어요.',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationTile extends StatefulWidget {
  const _ApplicationTile({
    required this.requestId,
    required this.application,
    required this.canApprove,
  });

  final String requestId;
  final QueryDocumentSnapshot<Map<String, dynamic>> application;
  final bool canApprove;

  @override
  State<_ApplicationTile> createState() => _ApplicationTileState();
}

class _ApplicationTileState extends State<_ApplicationTile> {
  bool _isApproving = false;

  Future<void> _approve() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('이 지원자를 승인할까요?'),
            content: const Text('승인하면 다른 지원자는 자동으로 미선정 처리됩니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('승인'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;

    setState(() => _isApproving = true);
    try {
      await SubstitutionService().approveApplication(
        requestId: widget.requestId,
        applicationId: widget.application.id,
        managerId: user.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('대타가 확정됐어요.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(cleanError(error))));
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.application.data();
    final status = MvpStatus.application(data['status']);

    return Card(
      child: ListTile(
        title: Text((data['applicantName'] ?? '알바생').toString()),
        subtitle: Text(
          asDateTime(data['appliedAt']) == null
              ? '지원 시간 확인 중'
              : '${formatDateTime(data['appliedAt'])} 지원',
        ),
        trailing:
            widget.canApprove && status == MvpStatus.applied
                ? FilledButton(
                  onPressed: _isApproving ? null : _approve,
                  child: Text(_isApproving ? '처리 중' : '승인'),
                )
                : StatusChip(status),
      ),
    );
  }
}
