import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import 'link_email_screen.dart';
import 'phone_auth_mode.dart';
import 'phone_auth_screen.dart';
import 'welcome_onboarding_screen.dart';

enum AccountProtectionSource {
  emailSignUp,
  phoneSignUp,
}

class AccountProtectionScreen extends StatefulWidget {
  final AccountProtectionSource source;

  const AccountProtectionScreen({
    super.key,
    required this.source,
  });

  @override
  State<AccountProtectionScreen> createState() =>
      _AccountProtectionScreenState();
}

class _AccountProtectionScreenState extends State<AccountProtectionScreen> {
  final _authService = AuthService();

  bool _isSendingVerification = false;
  bool _isRefreshing = false;

  Future<void> _addMobileNumber() async {
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const PhoneAuthScreen(
          mode: PhoneAuthMode.linkToCurrentAccount,
        ),
      ),
    );

    if (!mounted || linked != true) return;

    setState(() {});
    _showMessage('Mobile number verified and added to your account.');
  }

  Future<void> _addRecoveryEmail() async {
    final linked = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LinkEmailScreen()),
    );

    if (!mounted || linked != true) return;

    setState(() {});
    _showMessage('Recovery email added. Verify it from your inbox.');
  }

  Future<void> _sendVerificationEmail() async {
    if (_isSendingVerification) return;

    setState(() => _isSendingVerification = true);

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      _showMessage('Verification email sent. Check inbox and spam folder.', type: AppNoticeType.success);
    } catch (error) {
      if (!mounted) return;
      _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.email));
    } finally {
      if (mounted) {
        setState(() => _isSendingVerification = false);
      }
    }
  }

  Future<void> _refreshVerificationStatus() async {
    if (_isRefreshing) return;

    setState(() => _isRefreshing = true);

    try {
      final user = await _authService.reloadCurrentUser();
      if (!mounted) return;

      setState(() {});

      if (user?.emailVerified == true) {
        _showMessage('Email verified successfully.', type: AppNoticeType.success);
      } else {
        _showMessage('Email is still pending verification. Open the link in your email, then try again.');
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.email));
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _continueToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeOnboardingScreen()),
          (route) => false,
    );
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final hasPhone = _authService.hasPhoneProvider(user);
    final hasEmail = _authService.hasEmailPasswordProvider(user);
    final emailVerified = hasEmail && (user?.emailVerified ?? false);

    final sourceIsEmail = widget.source == AccountProtectionSource.emailSignUp;
    final title = sourceIsEmail
        ? 'Your email account is ready'
        : 'Your mobile account is ready';
    final subtitle = sourceIsEmail
        ? 'Protect your account by verifying your email and adding a mobile number for quick login.'
        : 'Your mobile number is verified. Add a recovery email so you are not dependent on one sign-in method.';

    final securityReady = hasPhone && hasEmail && emailVerified;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 82,
                width: 82,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: securityReady
                      ? Colors.green.withValues(alpha: 0.12)
                      : AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  securityReady
                      ? Icons.verified_user_rounded
                      : Icons.shield_outlined,
                  color: securityReady ? Colors.green : AppTheme.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.lightText,
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.card,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _ProtectionMethodRow(
                      icon: Icons.phone_android_rounded,
                      title: hasPhone
                          ? 'Mobile number verified'
                          : 'Add mobile number',
                      subtitle: hasPhone
                          ? (user?.phoneNumber ?? 'Verified mobile number')
                          : 'Use a one-time code to sign in quickly.',
                      color: hasPhone ? Colors.green : AppTheme.primary,
                      trailing: hasPhone
                          ? const Icon(Icons.verified_rounded, color: Colors.green)
                          : TextButton(
                        onPressed: _addMobileNumber,
                        child: const Text('Add now'),
                      ),
                    ),
                    const Divider(height: 28),
                    _ProtectionMethodRow(
                      icon: Icons.email_outlined,
                      title: !hasEmail
                          ? 'Add recovery email'
                          : (emailVerified
                          ? 'Recovery email verified'
                          : 'Verify recovery email'),
                      subtitle: !hasEmail
                          ? 'Add a recovery email for sign-in and account recovery.'
                          : (user?.email ?? 'Recovery email'),
                      color: emailVerified ? Colors.green : AppTheme.primary,
                      trailing: !hasEmail
                          ? TextButton(
                        onPressed: _addRecoveryEmail,
                        child: const Text('Add now'),
                      )
                          : (emailVerified
                          ? const Icon(Icons.verified_rounded, color: Colors.green)
                          : TextButton(
                        onPressed: _isSendingVerification
                            ? null
                            : _sendVerificationEmail,
                        child: Text(
                          _isSendingVerification ? 'Sending...' : 'Resend',
                        ),
                      )),
                    ),
                  ],
                ),
              ),
              if (hasEmail && !emailVerified) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _isRefreshing ? null : _refreshVerificationStatus,
                  icon: _isRefreshing
                      ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.refresh_rounded),
                  label: Text(
                    _isRefreshing
                        ? 'Checking email verification...'
                        : 'I have verified my email',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: AppTheme.primaryDark,
                    side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.35)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _continueToHome,
                  child: const Text(
                    'Continue to welcome guide',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You can always manage account protection later in App Settings. Adding another method never creates a new device account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProtectionMethodRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget trailing;

  const _ProtectionMethodRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.lightText,
                  height: 1.3,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    );
  }
}
