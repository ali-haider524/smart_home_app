import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';

class LinkEmailScreen extends StatefulWidget {
  const LinkEmailScreen({super.key});

  @override
  State<LinkEmailScreen> createState() => _LinkEmailScreenState();
}

class _LinkEmailScreenState extends State<LinkEmailScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSaving = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _linkEmail() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Complete all fields to add your recovery email.', type: AppNoticeType.warning);
      return;
    }

    if (password.length < 6) {
      _showMessage('Choose a password with at least 6 characters.', type: AppNoticeType.warning);
      return;
    }

    if (password != confirmPassword) {
      _showMessage('The passwords do not match.', type: AppNoticeType.warning);
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _authService.linkEmailPassword(email: email, password: password);

      // Linking succeeds before verification. Do not undo or re-link if an
      // email send later fails; Settings provides a safe resend option.
      try {
        await _authService.sendEmailVerification();
      } catch (_) {
        // The provider remains linked. The user can resend from Settings.
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showMessage(
          _authService.friendlyAuthError(error, scope: AuthErrorScope.email),
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Add Recovery Email'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 58,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Add a recovery email',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Use an email address as a second sign-in and recovery option. You will choose a password for email sign-in. Your devices stay on the same account.',
                style: TextStyle(color: AppTheme.lightText, height: 1.45),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  hintText: 'Choose password for email sign-in',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _hidePassword,
                decoration: const InputDecoration(
                  hintText: 'Confirm password',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isSaving ? null : _linkEmail,
                  child: _isSaving
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Add Recovery Email',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
