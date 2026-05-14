import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../mvp_shared.dart';
import 'register_request_page.dart';
import 'request_detail_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: EmptyState(
          title: '로그인이 필요해요',
          message: '대타 요청을 보려면 먼저 로그인해 주세요.',
          icon: Icons.lock_outline,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future:
          FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = snapshot.data?.data();
        final storeId = userData?['storeId']?.toString();
        if (storeId == null || storeId.isEmpty) {
          return const Scaffold(
            body: EmptyState(
              title: '매장 연결이 필요해요',
              message: '매니저는 매장을 만들고, 알바생은 초대 코드로 참여해 주세요.',
              icon: Icons.store_mall_directory_outlined,
            ),
          );
        }

        return DefaultTabController(
          length: 3,
          initialIndex: initialTab,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('대타 요청'),
              actions: [
                IconButton(
                  tooltip: '요청 만들기',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterRequestPage(),
                      ),
                    );
                  },
                ),
              ],
              bottom: const TabBar(
                tabs: [
                  Tab(text: '대타 찾기'),
                  Tab(text: '내 요청'),
                  Tab(text: '내 지원'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _OpenRequestsTab(storeId: storeId, userId: user.uid),
                _MyRequestsTab(storeId: storeId, userId: user.uid),
                _MyApplicationsTab(storeId: storeId, userId: user.uid),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterRequestPage(),
                  ),
                );
              },
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('요청하기'),
            ),
          ),
        );
      },
    );
  }
}

class _OpenRequestsTab extends StatelessWidget {
  const _OpenRequestsTab({required this.storeId, required this.userId});

  final String storeId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('sub_requests')
              .where('storeId', isEqualTo: storeId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests =
            [...?snapshot.data?.docs].where((doc) {
                final data = doc.data();
                return MvpStatus.request(data['status']) == MvpStatus.open &&
                    requestOwnerId(data) != userId;
              }).toList()
              ..sort(_sortByStartTime);

        if (requests.isEmpty) {
          return const EmptyState(
            title: '지금은 열린 요청이 없어요',
            message: '필요한 요청이 올라오면 여기에서 바로 지원할 수 있어요.',
            icon: Icons.volunteer_activism_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            return _RequestCard(
              requestId: requests[index].id,
              data: requests[index].data(),
              primaryChip: const StatusChip(MvpStatus.open),
              actionText: '자세히 보기',
            );
          },
        );
      },
    );
  }
}

class _MyRequestsTab extends StatelessWidget {
  const _MyRequestsTab({required this.storeId, required this.userId});

  final String storeId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('sub_requests')
              .where('storeId', isEqualTo: storeId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests =
            [...?snapshot.data?.docs].where((doc) {
                return requestOwnerId(doc.data()) == userId;
              }).toList()
              ..sort(_sortByStartTime);

        if (requests.isEmpty) {
          return const EmptyState(
            title: '아직 올린 요청이 없어요',
            message: '부담되는 부탁은 앱에 맡기고, 필요한 일정만 차분히 적어보세요.',
            icon: Icons.edit_calendar_outlined,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _ApplicationCountCard(
              requestId: request.id,
              storeId: storeId,
              data: request.data(),
            );
          },
        );
      },
    );
  }
}

class _MyApplicationsTab extends StatelessWidget {
  const _MyApplicationsTab({required this.storeId, required this.userId});

  final String storeId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('applications')
              .where('storeId', isEqualTo: storeId)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final applications =
            [
                ...?snapshot.data?.docs,
              ].where((doc) => doc.data()['applicantId'] == userId).toList()
              ..sort((a, b) {
                final aTime =
                    asDateTime(a.data()['appliedAt']) ?? DateTime(1970);
                final bTime =
                    asDateTime(b.data()['appliedAt']) ?? DateTime(1970);
                return bTime.compareTo(aTime);
              });

        if (applications.isEmpty) {
          return const EmptyState(
            title: '지원한 요청이 없어요',
            message: '가능한 일정이 보이면 지원해 보세요. 매니저가 한 명을 확정합니다.',
            icon: Icons.handshake_outlined,
          );
        }

        return FutureBuilder<List<_ApplicationBundle>>(
          future: _loadApplicationBundles(applications, storeId),
          builder: (context, bundleSnapshot) {
            if (bundleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final bundles = bundleSnapshot.data ?? [];
            if (bundles.isEmpty) {
              return const EmptyState(
                title: '요청 정보를 불러오지 못했어요',
                message: '삭제되었거나 매장 정보가 다른 요청일 수 있어요.',
                icon: Icons.info_outline,
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 96),
              itemCount: bundles.length,
              itemBuilder: (context, index) {
                final bundle = bundles[index];
                final appStatus = MvpStatus.application(
                  bundle.application.data()['status'],
                );
                return _RequestCard(
                  requestId: bundle.request.id,
                  data: bundle.request.data()!,
                  primaryChip: StatusChip(appStatus),
                  actionText: '상세',
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ApplicationCountCard extends StatelessWidget {
  const _ApplicationCountCard({
    required this.requestId,
    required this.storeId,
    required this.data,
  });

  final String requestId;
  final String storeId;
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('applications')
              .where('storeId', isEqualTo: storeId)
              .snapshots(),
      builder: (context, snapshot) {
        final applications =
            (snapshot.data?.docs ?? [])
                .where((doc) => doc.data()['requestId'] == requestId)
                .toList();
        final requestStatus = MvpStatus.request(data['status']);
        final chip =
            requestStatus == MvpStatus.open && applications.isNotEmpty
                ? StatusChip(
                  MvpStatus.applied,
                  label: '지원 ${applications.length}명',
                )
                : StatusChip(requestStatus);

        final actionText =
            requestStatus == MvpStatus.approved
                ? '${data['approvedApplicantName'] ?? '대타'}님 확정'
                : applications.isEmpty
                ? '지원 기다리는 중'
                : '지원자 확인';

        return _RequestCard(
          requestId: requestId,
          data: data,
          primaryChip: chip,
          actionText: actionText,
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.requestId,
    required this.data,
    required this.primaryChip,
    required this.actionText,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final Widget primaryChip;
  final String actionText;

  @override
  Widget build(BuildContext context) {
    final reason = (data['reason'] ?? '사유 없음').toString();
    final memo = (data['memo'] ?? '').toString();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RequestDetailScreen(requestId: requestId),
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
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  primaryChip,
                ],
              ),
              const SizedBox(height: 10),
              Text(reason, style: Theme.of(context).textTheme.bodyLarge),
              if (memo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  memo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      requestOwnerName(data),
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  Text(
                    actionText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<List<_ApplicationBundle>> _loadApplicationBundles(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> applications,
  String storeId,
) async {
  final result = <_ApplicationBundle>[];

  for (final application in applications) {
    final requestId = application.data()['requestId']?.toString();
    if (requestId == null || requestId.isEmpty) continue;

    final request =
        await FirebaseFirestore.instance
            .collection('sub_requests')
            .doc(requestId)
            .get();
    final requestData = request.data();
    if (requestData == null || requestData['storeId'] != storeId) continue;

    result.add(_ApplicationBundle(application: application, request: request));
  }

  return result;
}

int _sortByStartTime(
  QueryDocumentSnapshot<Map<String, dynamic>> a,
  QueryDocumentSnapshot<Map<String, dynamic>> b,
) {
  final aTime = asDateTime(a.data()['startTime']) ?? DateTime(2100);
  final bTime = asDateTime(b.data()['startTime']) ?? DateTime(2100);
  return aTime.compareTo(bTime);
}

class _ApplicationBundle {
  const _ApplicationBundle({required this.application, required this.request});

  final QueryDocumentSnapshot<Map<String, dynamic>> application;
  final DocumentSnapshot<Map<String, dynamic>> request;
}
