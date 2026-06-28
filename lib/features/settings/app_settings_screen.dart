import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../auth/link_email_screen.dart';
import '../auth/login_screen.dart';
import '../auth/phone_auth_mode.dart';
import '../auth/phone_auth_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final _authService = AuthService();

  bool _isSigningOut = false;
  bool _isSendingVerification = false;
  bool _isRefreshingVerification = false;

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'You can sign in again using email sign-in or your verified mobile number. Your devices, schedules, and WiFi settings will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (shouldSignOut != true || !mounted) return;

    setState(() => _isSigningOut = true);

    try {
      await _authService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    } catch (_) {
      if (mounted) {
        _showMessage('Could not sign out. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _addPhoneNumber() async {
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

  Future<void> _sendEmailVerification() async {
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

  Future<void> _refreshEmailVerification() async {
    if (_isRefreshingVerification) return;

    setState(() => _isRefreshingVerification = true);

    try {
      final user = await _authService.reloadCurrentUser();
      if (!mounted) return;

      setState(() {});

      if (user?.emailVerified == true) {
        _showMessage('Email verified successfully.', type: AppNoticeType.success);
      } else {
        _showMessage(
          'Email is still pending verification. Open the link in your email, then try again.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.email));
    } finally {
      if (mounted) {
        setState(() => _isRefreshingVerification = false);
      }
    }
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final phone = (user?.phoneNumber ?? '').trim();

    final hasEmail = _authService.hasEmailPasswordProvider(user);
    final hasPhone = _authService.hasPhoneProvider(user);
    final emailVerified = hasEmail && (user?.emailVerified ?? false);

    final accountIdentity = hasEmail
        ? email
        : (hasPhone ? phone : 'No verified sign-in method');

    final initialSource = displayName.isNotEmpty
        ? displayName
        : (hasEmail ? email : (hasPhone ? phone : 'U'));

    final initial = initialSource.isNotEmpty
        ? initialSource.substring(0, 1).toUpperCase()
        : 'U';

    final accountProtected = hasPhone && hasEmail && emailVerified;
    final protectionTitle = accountProtected
        ? 'Account protection is complete'
        : (!hasPhone
        ? 'Add a mobile number'
        : (!hasEmail ? 'Add a recovery email' : 'Verify your recovery email'));
    final protectionSubtitle = accountProtected
        ? 'You can sign in with both verified mobile and email methods.'
        : (!hasPhone
        ? 'Use mobile OTP for quick sign-in and account recovery.'
        : (!hasEmail
        ? 'Add a recovery email so you can still sign in if you lose access to your mobile number.'
        : 'Confirm the verification link sent to $email.'));

    final protectionAction = !hasPhone
        ? _addPhoneNumber
        : (!hasEmail ? _addRecoveryEmail : _sendEmailVerification);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'App Settings',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage your Easy Home Control account.',
              style: TextStyle(color: AppTheme.lightText),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryDark, AppTheme.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName.isEmpty ? 'Easy Home User' : displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          accountIdentity,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Account protection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: accountProtected
                    ? Colors.green.withValues(alpha: 0.08)
                    : AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accountProtected
                      ? Colors.green.withValues(alpha: 0.22)
                      : AppTheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    accountProtected
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    color: accountProtected ? Colors.green : AppTheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          protectionTitle,
                          style: const TextStyle(
                            color: AppTheme.darkText,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          protectionSubtitle,
                          style: const TextStyle(
                            color: AppTheme.lightText,
                            height: 1.35,
                            fontSize: 13,
                          ),
                        ),
                        if (!accountProtected) ...[
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _isSendingVerification
                                ? null
                                : protectionAction,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppTheme.primaryDark,
                            ),
                            child: Text(
                              _isSendingVerification && hasEmail && !emailVerified
                                  ? 'Sending verification...'
                                  : 'Protect account now',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Account access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: hasPhone
                  ? Icons.verified_user_rounded
                  : Icons.phone_android_rounded,
              title: hasPhone ? 'Mobile number verified' : 'Add mobile number',
              subtitle: hasPhone
                  ? phone
                  : 'Use mobile OTP to sign in without relying only on email.',
              color: hasPhone ? Colors.green : AppTheme.primary,
              onTap: hasPhone ? null : _addPhoneNumber,
              trailing: hasPhone
                  ? const Icon(Icons.verified_rounded, color: Colors.green)
                  : null,
            ),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: emailVerified
                  ? Icons.mark_email_read_outlined
                  : Icons.email_outlined,
              title: !hasEmail
                  ? 'Add recovery email'
                  : (emailVerified
                  ? 'Recovery email verified'
                  : 'Verify recovery email'),
              subtitle: !hasEmail
                  ? 'Add a recovery email for sign-in and account recovery.'
                  : (emailVerified
                  ? email
                  : '$email • Verification pending'),
              color: emailVerified ? Colors.green : AppTheme.primary,
              onTap: !hasEmail
                  ? _addRecoveryEmail
                  : (emailVerified ? null : _sendEmailVerification),
              trailing: emailVerified
                  ? const Icon(Icons.verified_rounded, color: Colors.green)
                  : (hasEmail
                  ? TextButton(
                onPressed: _isSendingVerification
                    ? null
                    : _sendEmailVerification,
                child: Text(
                  _isSendingVerification ? 'Sending...' : 'Resend',
                ),
              )
                  : null),
            ),
            if (hasEmail && !emailVerified) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isRefreshingVerification
                    ? null
                    : _refreshEmailVerification,
                icon: _isRefreshingVerification
                    ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.refresh_rounded),
                label: Text(
                  _isRefreshingVerification
                      ? 'Checking verification...'
                      : 'I have verified my email',
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.primaryDark,
                  side: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.lock_reset_rounded,
              title: 'Email account recovery',
              subtitle: hasEmail
                  ? 'Use “Forgot password?” on the login screen to reset your email sign-in password.'
                  : 'Add a recovery email first to use password recovery.',
              color: AppTheme.primary,
            ),
            const SizedBox(height: 12),
            const _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Your devices stay safe',
              subtitle: 'Signing out does not remove, reset, archive, or unpair any device.',
              color: Colors.green,
            ),
            const SizedBox(height: 28),
            const Text(
              'Session',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppTheme.darkText,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed: _isSigningOut ? null : _confirmSignOut,
                icon: _isSigningOut
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.logout_rounded),
                label: Text(
                  _isSigningOut ? 'Signing out...' : 'Sign Out',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final content = Row(
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
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ] else if (onTap != null) ...[
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.lightText),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: content,
        ),
      ),
    );
  }
}
