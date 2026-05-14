import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mvp_shared.dart';
import '../services/substitution_service.dart';
import 'request_detail_screen.dart';

class AdminRequestListPage extends StatelessWidget {
  const AdminRequestListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          title: '로그인이 필요해요',
          message: '매니저 대시보드를 보려면 로그인해 주세요.',
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
        final role = userData?['role']?.toString();

        if (storeId == null || storeId.isEmpty || !isManagerRole(role)) {
          return const Scaffold(
            body: EmptyState(
              title: '매니저 권한이 필요해요',
              message: '매장 관리자 계정으로 로그인해 주세요.',
              icon: Icons.admin_panel_settings_outlined,
            ),
          );
        }

        return _ManagerDashboard(storeId: storeId, managerId: user.uid);
      },
    );
  }
}

class _ManagerDashboard extends StatelessWidget {
  const _ManagerDashboard({required this.storeId, required this.managerId});

  final String storeId;
  final String managerId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('매니저 대시보드')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('sub_requests')
                .where('storeId', isEqualTo: storeId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final requestDocs = [...?snapshot.data?.docs]..sort(_sortByStartTime);
          if (requestDocs.isEmpty) {
            return const EmptyState(
              title: '아직 대타 요청이 없어요',
              message: '알바생이 요청을 올리면 이곳에서 한 번에 확인할 수 있어요.',
              icon: Icons.dashboard_outlined,
            );
          }

          return FutureBuilder<List<_RequestBundle>>(
            future: _loadBundles(requestDocs, storeId),
            builder: (context, bundleSnapshot) {
              if (bundleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final bundles = bundleSnapshot.data ?? [];
              final pending =
                  bundles.where((bundle) {
                    return bundle.status == MvpStatus.open &&
                        bundle.applications.isEmpty;
                  }).toList();
              final withApplicants =
                  bundles.where((bundle) {
                    return bundle.status == MvpStatus.open &&
                        bundle.applications.isNotEmpty;
                  }).toList();
              final approved =
                  bundles.where((bundle) {
                    return bundle.status == MvpStatus.approved;
                  }).toList();

              if (pending.isEmpty &&
                  withApplicants.isEmpty &&
                  approved.isEmpty) {
                return const EmptyState(
                  title: '확인할 요청이 없어요',
                  message: '취소되거나 완료된 요청만 있는 상태예요.',
                  icon: Icons.task_alt_outlined,
                );
              }

              return ListView(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                children: [
                  _DashboardSection(
                    title: '지원 기다리는 요청',
                    subtitle: '아직 지원자가 없는 요청입니다.',
                    bundles: pending,
                    managerId: managerId,
                  ),
                  _DashboardSection(
                    title: '지원자 있는 요청',
                    subtitle: '한 명을 승인하면 나머지는 자동으로 미선정 처리됩니다.',
                    bundles: withApplicants,
                    managerId: managerId,
                  ),
                  _DashboardSection(
                    title: '승인된 대타',
                    subtitle: '최종 대타 일정입니다.',
                    bundles: approved,
                    managerId: managerId,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({
    required this.title,
    required this.subtitle,
    required this.bundles,
    required this.managerId,
  });

  final String title;
  final String subtitle;
  final List<_RequestBundle> bundles;
  final String managerId;

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${bundles.length}건',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
        ),
        const SizedBox(height: 6),
        ...bundles.map(
          (bundle) => _ManagerRequestCard(bundle: bundle, managerId: managerId),
        ),
      ],
    );
  }
}

class _ManagerRequestCard extends StatelessWidget {
  const _ManagerRequestCard({required this.bundle, required this.managerId});

  final _RequestBundle bundle;
  final String managerId;

  @override
  Widget build(BuildContext context) {
    final data = bundle.data;
    final status = bundle.status;
    final memo = (data['memo'] ?? '').toString();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(requestId: bundle.request.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formatTimeRange(data),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  status == MvpStatus.open && bundle.applications.isNotEmpty
                      ? StatusChip(
                        MvpStatus.applied,
                        label: '지원 ${bundle.applications.length}명',
                      )
                      : StatusChip(status),
                ],
              ),
              const SizedBox(height: 10),
              Text('${requestOwnerName(data)}님의 요청'),
              const SizedBox(height: 4),
              Text(
                (data['reason'] ?? '사유 없음').toString(),
                style: TextStyle(color: Colors.grey.shade800),
              ),
              if (memo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  memo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              if (status == MvpStatus.approved) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF2F855A)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${data['approvedApplicantName'] ?? '대타'}님으로 확정',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
              if (bundle.applications.isNotEmpty) ...[
                const Divider(height: 24),
                ...bundle.applications.map(
                  (application) => _ApplicantRow(
                    requestId: bundle.request.id,
                    application: application,
                    managerId: managerId,
                    canApprove: status == MvpStatus.open,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicantRow extends StatefulWidget {
  const _ApplicantRow({
    required this.requestId,
    required this.application,
    required this.managerId,
    required this.canApprove,
  });

  final String requestId;
  final QueryDocumentSnapshot<Map<String, dynamic>> application;
  final String managerId;
  final bool canApprove;

  @override
  State<_ApplicantRow> createState() => _ApplicantRowState();
}

class _ApplicantRowState extends State<_ApplicantRow> {
  bool _isApproving = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('이 지원자를 승인할까요?'),
            content: const Text('승인 후에는 다른 지원자가 자동으로 미선정 처리됩니다.'),
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
        managerId: widget.managerId,
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
    final canApprove = widget.canApprove && status == MvpStatus.applied;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              _initialForName((data['applicantName'] ?? '알바생').toString()),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['applicantName'] ?? '알바생').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  asDateTime(data['appliedAt']) == null
                      ? '지원 시간 확인 중'
                      : '${formatDateTime(data['appliedAt'])} 지원',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          canApprove
              ? FilledButton(
                onPressed: _isApproving ? null : _approve,
                child: Text(_isApproving ? '처리 중' : '승인'),
              )
              : StatusChip(status),
        ],
      ),
    );
  }
}

Future<List<_RequestBundle>> _loadBundles(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> requests,
  String storeId,
) async {
  final bundles = <_RequestBundle>[];
  final applicationsSnapshot =
      await FirebaseFirestore.instance
          .collection('applications')
          .where('storeId', isEqualTo: storeId)
          .get();
  final allApplications = applicationsSnapshot.docs;

  for (final request in requests) {
    final applicationDocs =
        allApplications
            .where(
              (application) => application.data()['requestId'] == request.id,
            )
            .toList()
          ..sort((a, b) {
            final aTime = asDateTime(a.data()['appliedAt']) ?? DateTime(1970);
            final bTime = asDateTime(b.data()['appliedAt']) ?? DateTime(1970);
            return aTime.compareTo(bTime);
          });

    bundles.add(
      _RequestBundle(request: request, applications: applicationDocs),
    );
  }

  return bundles;
}

int _sortByStartTime(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final aTime = asDateTime(a.data()['startTime']) ?? DateTime(2100);
  final bTime = asDateTime(b.data()['startTime']) ?? DateTime(2100);
  return aTime.compareTo(bTime);
}

class _RequestBundle {
  const _RequestBundle({required this.request, required this.applications});

  final QueryDocumentSnapshot<Map<String, dynamic>> request;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> applications;

  Map<String, dynamic> get data => request.data();
  String get status => MvpStatus.request(data['status']);
}

String _initialForName(String name) {
  if (name.trim().isEmpty) return '알';
  return name.trim().substring(0, 1);
}
