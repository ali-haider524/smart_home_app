import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
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

  void _openLogin() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  onPressed: isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 8),
              const AuthHeader(
                title: 'Create your account',
                subtitle:
                'Keep your devices, schedules and settings in one secure place.',
                compact: true,
              ),
              const SizedBox(height: 24),
              _RegisterSurface(
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: passwordController,
                        obscureText: hidePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'Create password',
                          hintText: 'At least 6 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: hidePassword
                                ? 'Show password'
                                : 'Hide password',
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
                      const SizedBox(height: 12),
                      const _AccountNote(),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 54,
                        child: FilledButton.icon(
                          onPressed: isLoading ? null : createAccount,
                          icon: isLoading
                              ? const SizedBox(
                            height: 19,
                            width: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            isLoading ? 'Creating account...' : 'Create account',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: isLoading ? null : _openMobileVerification,
                icon: const Icon(Icons.phone_android_rounded),
                label: const Text('Use mobile verification instead'),
              ),
              const SizedBox(height: 9),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
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
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(color: AppTheme.lightText),
                  ),
                  TextButton(
                    onPressed: isLoading ? null : _openLogin,
                    child: const Text('Sign in'),
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

class _RegisterSurface extends StatelessWidget {
  final Widget child;

  const _RegisterSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return TechPatternCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: child,
    );
  }
}

class _AccountNote extends StatelessWidget {
  const _AccountNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primary,
            size: 19,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'You can verify your email and add mobile sign-in after creating your account.',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
