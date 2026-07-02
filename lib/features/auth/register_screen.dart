import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'account_protection_screen.dart';
import 'login_screen.dart';
import 'phone_auth_mode.dart';
import 'phone_auth_screen.dart';
import 'widgets/auth_header.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _authService = AuthService();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> createAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage(
        'Complete all fields to create your account.',
        type: AppNoticeType.warning,
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Choose a password with at least 6 characters.',
        type: AppNoticeType.warning,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final credential = await _authService.register(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      // Email verification is optional for entering the app, but we send it
      // immediately so the user can confirm the recovery method later.
      try {
        await _authService.sendEmailVerification();
      } catch (_) {
        // The Account Protection screen provides a safe resend option.
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const AccountProtectionScreen(
            source: AccountProtectionSource.emailSignUp,
          ),
        ),
            (route) => false,
      );
    } catch (error) {
      showMessage(
        _authService.friendlyAuthError(
          error,
          scope: AuthErrorScope.email,
        ),
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(
      String message, {
        AppNoticeType type = AppNoticeType.info,
      }) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> _openMobileVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PhoneAuthScreen(mode: PhoneAuthMode.signIn),
      ),
    );
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
                title: 'Create Account',
                subtitle: 'Securely connect and manage your smart home devices.',
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  hintText: 'Create password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => hidePassword = !hidePassword);
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (!isLoading) createAccount();
                },
              ),
              const SizedBox(height: 26),
              SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: isLoading ? null : createAccount,
                  child: isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppTheme.lightText),
                  ),
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                            (route) => false,
                      );
                    },
                    child: const Text('Sign in'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : _openMobileVerification,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryDark,
                    minimumSize: const Size(48, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Prefer mobile? Use mobile verification',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 17),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Verify your number with a one-time code, then add a recovery email later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
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
