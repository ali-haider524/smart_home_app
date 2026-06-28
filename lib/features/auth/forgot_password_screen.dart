import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'widgets/auth_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isSending = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _looksLikeEmail(String value) {
    return RegExp(r'^\S+@\S+\.\S+$').hasMatch(value);
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();

    if (!_looksLikeEmail(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    setState(() => _isSending = true);

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (!mounted) return;

      setState(() => _emailSent = true);
      _showMessage('Reset link sent. Check your inbox and spam folder.', type: AppNoticeType.success);
    } on FirebaseAuthException catch (error) {
      _showMessage(_friendlyError(error));
    } on ArgumentError catch (error) {
      _showMessage(error.message?.toString() ?? 'Enter your email address.');
    } catch (_) {
      _showMessage('Could not send the reset email. Check your internet and try again.');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a little and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please try again.';
      default:
        return error.message ?? 'Could not send the reset email.';
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 12),
              const AuthHeader(
                title: 'Reset Password',
                subtitle:
                'Enter your account email and we will send a secure reset link.',
              ),
              const SizedBox(height: 36),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.mark_email_read_outlined,
                        color: AppTheme.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The reset link is sent securely. It may take a minute to arrive. Check the spam folder too.',
                        style: TextStyle(
                          color: AppTheme.lightText,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onSubmitted: (_) {
                  if (!_isSending) {
                    _sendResetEmail();
                  }
                },
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isSending ? null : _sendResetEmail,
                  icon: _isSending
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSending ? 'Sending...' : 'Send Reset Link',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (_emailSent) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          color: Colors.green),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Email sent. Once your password is changed, return here and log in.',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
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
