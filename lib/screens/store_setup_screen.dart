import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mvp_shared.dart';
import '../services/store_onboarding_service.dart';

class StoreSetupScreen extends StatefulWidget {
  const StoreSetupScreen({super.key, this.existingData});

  final Map<String, dynamic>? existingData;

  @override
  State<StoreSetupScreen> createState() => _StoreSetupScreenState();
}

class _StoreSetupScreenState extends State<StoreSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _inviteCodeController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _storeService = StoreOnboardingService();

  String _role = 'worker';
  String _error = '';
  bool _isSaving = false;

  bool get _isManager => _role == 'admin';

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final data = widget.existingData ?? {};
    _nameController = TextEditingController(
      text: (data['userName'] ?? user?.displayName ?? '').toString(),
    );
    final existingRole = data['role']?.toString();
    _role = isManagerRole(existingRole) ? 'admin' : 'worker';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _inviteCodeController.dispose();
    _storeNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isSaving = true;
      _error = '';
    });

    try {
      final userName = _nameController.text.trim();
      CreatedStore? createdStore;
      DocumentSnapshot<Map<String, dynamic>>? joinedStore;

      if (_isManager) {
        createdStore = await _storeService.createStore(
          storeName: _storeNameController.text.trim(),
          createdBy: user.uid,
        );
      } else {
        joinedStore = await _storeService.findStoreByInviteCode(
          _inviteCodeController.text,
        );
        if (joinedStore == null) {
          throw Exception('초대 코드를 다시 확인해 주세요.');
        }
      }

      final storeId =
          createdStore?.storeId ??
          (joinedStore!.data()?['storeId'] ?? joinedStore.id).toString();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userName': userName,
        'displayName': userName,
        'email': user.email,
        'role': _role,
        'storeId': storeId,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt':
            widget.existingData == null
                ? FieldValue.serverTimestamp()
                : widget.existingData!['createdAt'],
      }, SetOptions(merge: true));

      if (!mounted) return;
      if (createdStore != null) {
        await _showInviteCodeDialog(createdStore);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('매장에 참여했어요.')));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = cleanError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showInviteCodeDialog(CreatedStore store) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('초대 코드가 준비됐어요'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${store.storeName} 직원에게 이 코드를 보내주세요.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    store.inviteCode,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: store.inviteCode),
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('초대 코드를 복사했어요.')),
                  );
                },
                child: const Text('복사'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('매장 연결')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                _isManager ? '매장을 만들어 주세요' : '초대 코드로 참여해 주세요',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isManager
                    ? '매장 이름만 입력하면 직원용 초대 코드가 만들어져요.'
                    : '매니저에게 받은 코드만 입력하면 매장에 연결돼요.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: '이름'),
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '이름을 입력해 주세요.'
                            : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'worker',
                    label: Text('알바생'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                  ButtonSegment(
                    value: 'admin',
                    label: Text('매니저'),
                    icon: Icon(Icons.storefront_outlined),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (selected) {
                  setState(() => _role = selected.first);
                },
              ),
              const SizedBox(height: 16),
              if (_isManager)
                TextFormField(
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: '매장 이름',
                    hintText: '예: 루프 베이커리 카페',
                  ),
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '매장 이름을 입력해 주세요.'
                              : null,
                )
              else
                TextFormField(
                  controller: _inviteCodeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '초대 코드',
                    hintText: '예: 7KQ2MA',
                    helperText: '매니저가 공유한 6자리 코드를 입력해요.',
                  ),
                  onChanged: (value) {
                    final normalized = _storeService.normalizeInviteCode(value);
                    if (value != normalized) {
                      _inviteCodeController.value = TextEditingValue(
                        text: normalized,
                        selection: TextSelection.collapsed(
                          offset: normalized.length,
                        ),
                      );
                    }
                  },
                  validator:
                      (value) =>
                          value == null || value.trim().isEmpty
                              ? '초대 코드를 입력해 주세요.'
                              : null,
                ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Text(_isSaving ? '저장 중...' : '시작하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
