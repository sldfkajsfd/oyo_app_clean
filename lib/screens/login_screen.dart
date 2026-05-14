import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _error = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = '';
    });

    final success = await AuthService.signInWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = success ? '' : '이메일 또는 비밀번호를 다시 확인해 주세요.';
    });
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    final user = await AuthService.signInWithGoogle();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _error = user == null ? '구글 로그인을 완료하지 못했어요.' : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'OYO',
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '대타 요청을 덜 부담스럽게',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: '이메일'),
                      validator:
                          (value) =>
                              value == null || value.trim().isEmpty
                                  ? '이메일을 입력해 주세요.'
                                  : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(labelText: '비밀번호'),
                      validator:
                          (value) =>
                              value == null || value.isEmpty
                                  ? '비밀번호를 입력해 주세요.'
                                  : null,
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(_error, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      child: Text(_isLoading ? '로그인 중...' : '로그인'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _loginWithGoogle,
                      child: const Text('구글로 계속하기'),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed:
                          _isLoading
                              ? null
                              : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                              },
                      child: const Text('처음이라면 계정 만들기'),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      '매장 안에서만 요청이 공유돼요. 직접 부탁하는 부담 없이 필요한 일정만 올려보세요.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
