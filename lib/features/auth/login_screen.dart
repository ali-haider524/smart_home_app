import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
import 'forgot_password_screen.dart';
import 'phone_auth_mode.dart';
import 'phone_auth_screen.dart';
import 'register_screen.dart';
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

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height - 52,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(
                  title: 'Welcome back',
                  subtitle: 'Sign in to control your home from anywhere.',
                ),
                const SizedBox(height: 30),
                _AuthSurface(
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Sign in with email',
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
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
                            if (!isLoading) loginUser();
                          },
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: isLoading
                                ? null
                                : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: isLoading ? null : loginUser,
                            icon: isLoading
                                ? const SizedBox(
                              height: 19,
                              width: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                                : const Icon(Icons.login_rounded),
                            label: Text(isLoading ? 'Signing in...' : 'Sign in'),
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
                  label: const Text('Use mobile verification'),
                ),
                const SizedBox(height: 9),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'We will send a one-time code to your mobile number.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.lightText,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
                // This page scrolls on smaller screens, so it must not use
                // Spacer/Expanded here. Flex children need a bounded height and
                // can otherwise leave the login route blank.
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'New to Easy Home Control?',
                      style: TextStyle(color: AppTheme.lightText),
                    ),
                    TextButton(
                      onPressed: isLoading ? null : _openRegister,
                      child: const Text('Create account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthSurface extends StatelessWidget {
  final Widget child;

  const _AuthSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return TechPatternCard(
      padding: const EdgeInsets.all(18),
      radius: 24,
      child: child,
    );
  }
}
