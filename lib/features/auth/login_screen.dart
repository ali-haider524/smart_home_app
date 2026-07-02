import 'package:flutter/material.dart';
import 'package:smart_home_automation/features/auth/register_screen.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
import 'forgot_password_screen.dart';
import 'phone_auth_mode.dart';
import 'phone_auth_screen.dart';
import 'widgets/auth_header.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage(
        'Enter your email and password.',
        type: AppNoticeType.warning,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.login(email: email, password: password);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    } catch (error) {
      showMessage(
        _authService.friendlyAuthError(
          error,
          scope: AuthErrorScope.email,
        ),
        type: AppNoticeType.error,
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
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
          padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthHeader(
                title: 'Welcome Back',
                subtitle: 'Login to control your smart home from anywhere.',
              ),
              const SizedBox(height: 36),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  hintText: 'Email address',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                onSubmitted: (_) {
                  if (!isLoading) loginUser();
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: hidePassword,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  hintText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        hidePassword = !hidePassword;
                      });
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                onSubmitted: (_) {
                  if (!isLoading) loginUser();
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: isLoading ? null : loginUser,
                  child: isLoading
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                        'Use mobile verification instead',
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
                  'We will send a one-time verification code to your mobile number.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'New here?',
                    style: TextStyle(color: AppTheme.lightText),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Create account'),
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
