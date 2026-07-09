import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_appearance.dart';
import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import '../../services/auth_service.dart';
import '../auth/link_email_screen.dart';
import '../auth/login_screen.dart';
import '../auth/phone_auth_mode.dart';
import '../auth/phone_auth_screen.dart';
import '../devices/add_device_hub_screen.dart';
import '../devices/archived_devices_screen.dart';
import '../devices/device_list_screen.dart';
import '../devices/reconnect_device_screen.dart';
import 'support_center_screen.dart';
import 'user_guide_screen.dart';

/// Account, device and support settings for the signed-in customer.
///
/// This screen intentionally does not change RTDB data paths or device-control
/// behavior. It only exposes existing account actions and navigation.
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
          title: Text(context.tr('Sign out?')),
          content: Text(
            context.tr('You can sign in again using email sign-in or your verified mobile number. Your devices, schedules and WiFi settings will not be changed.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(context.tr('Sign Out')),
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
        _showMessage(
          context.tr('Could not sign out. Please try again.'),
          type: AppNoticeType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
    }
  }

  Future<void> _addPhoneNumber() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const PhoneAuthScreen(
          mode: PhoneAuthMode.linkToCurrentAccount,
        ),
      ),
    );

    if (!mounted || linked != true) return;

    setState(() {});
    _showMessage(
      context.tr('Mobile number verified and added to your account.'),
      type: AppNoticeType.success,
    );
  }

  Future<void> _addRecoveryEmail() async {
    final linked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LinkEmailScreen()),
    );

    if (!mounted || linked != true) return;

    setState(() {});
    _showMessage(
      context.tr('Recovery email added. Verify it from your inbox.'),
      type: AppNoticeType.success,
    );
  }

  Future<void> _sendEmailVerification() async {
    if (_isSendingVerification) return;

    setState(() => _isSendingVerification = true);

    try {
      await _authService.sendEmailVerification();
      if (!mounted) return;
      _showMessage(
        context.tr('Verification email sent. Check inbox and spam folder.'),
        type: AppNoticeType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _authService.friendlyAuthError(error, scope: AuthErrorScope.email),
        type: AppNoticeType.error,
      );
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
        _showMessage(
          context.tr('Email verified successfully.'),
          type: AppNoticeType.success,
        );
      } else {
        _showMessage(
          context.tr('Email is still pending verification. Open the link in your email, then try again.'),
          type: AppNoticeType.warning,
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage(
        _authService.friendlyAuthError(error, scope: AuthErrorScope.email),
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isRefreshingVerification = false);
      }
    }
  }

  Future<void> _changeLanguage(AppLanguage language) async {
    final persisted = await context.languageController.setLanguage(language);
    if (!mounted || persisted) return;

    _showMessage(
      context.tr('Language changed for this session. It will be saved when your connection is available.'),
      type: AppNoticeType.warning,
    );
  }

  Future<void> _changeAppearance(AppAppearance appearance) async {
    final persisted = await context.appearanceController.setAppearance(appearance);
    if (!mounted || persisted) return;

    _showMessage(
      context.tr('Appearance changed for this session. It will be saved when your connection is available.'),
      type: AppNoticeType.warning,
    );
  }

  void _openArchivedDevices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ArchivedDevicesScreen()),
    );
  }

  void _openAddDevice() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceHubScreen()),
    );
  }

  void _openDeviceManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DeviceListScreen()),
    );
  }

  void _openDeviceWifi() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReconnectDeviceScreen()),
    );
  }

  void _openSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SupportCenterScreen()),
    );
  }

  void _openUserGuide() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserGuideScreen()),
    );
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.home_work_rounded,
            color: AppTheme.primary,
            size: 34,
          ),
          title: const Text('Easy Home Control'),
          content: Text(
            context.tr('Control your connected switches, timers and weekly schedules from one secure account.\n\nThis app is currently being refined for its commercial release.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Done')),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }


  @override
  Widget build(BuildContext context) {
    final selectedLanguage = context.languageController.language;
    final selectedAppearance = context.appearanceController.appearance;
    final user = FirebaseAuth.instance.currentUser;
    final displayName = (user?.displayName ?? '').trim();
    final email = (user?.email ?? '').trim();
    final phone = (user?.phoneNumber ?? '').trim();

    final hasEmail = _authService.hasEmailPasswordProvider(user);
    final hasPhone = _authService.hasPhoneProvider(user);
    final emailVerified = hasEmail && (user?.emailVerified ?? false);

    final accountIdentity = hasEmail
        ? email
        : (hasPhone ? phone : context.tr('No verified sign-in method'));

    final initialSource = displayName.isNotEmpty
        ? displayName
        : (hasEmail ? email : (hasPhone ? phone : 'U'));
    final initial = initialSource.isNotEmpty
        ? initialSource.substring(0, 1).toUpperCase()
        : 'U';

    final accountProtected = hasPhone && hasEmail && emailVerified;
    final protectionTitle = !hasPhone
        ? context.tr('Add a mobile number')
        : (!hasEmail
        ? context.tr('Add a recovery email')
        : context.tr('Verify your recovery email'));
    final protectionSubtitle = !hasPhone
        ? context.tr('Use mobile verification as an extra way to sign in.')
        : (!hasEmail
        ? context.tr('Keep an email ready for account recovery.')
        : '${context.tr('Open the verification link sent to')} $email.');

    final VoidCallback protectionAction = !hasPhone
        ? _addPhoneNumber
        : (!hasEmail ? _addRecoveryEmail : _sendEmailVerification);

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
        children: [
          _SettingsPageHeader(
            title: context.tr('Settings'),
            subtitle: context.tr('Account, devices and support in one place.'),
          ),
          const SizedBox(height: 18),
          _ProfileOverviewCard(
            initial: initial,
            displayName:
            displayName.isEmpty ? context.tr('Easy Home User') : displayName,
            identity: accountIdentity,
            protected: accountProtected,
          ),
          if (!accountProtected) ...[
            const SizedBox(height: 14),
            _AccountAttentionCard(
              title: protectionTitle,
              subtitle: protectionSubtitle,
              onAction: _isSendingVerification ? null : protectionAction,
              loading: _isSendingVerification && hasEmail && !emailVerified,
            ),
          ],
          const SizedBox(height: 26),
          _SettingsSectionHeader(
            title: context.tr('Account security'),
            detail: accountProtected
                ? context.tr('Your sign-in and recovery options are ready.')
                : context.tr('Complete the items below to protect your account.'),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: hasPhone
                    ? Icons.verified_user_rounded
                    : Icons.phone_android_rounded,
                iconColor: hasPhone ? AppTheme.success : AppTheme.primary,
                title: hasPhone
                    ? context.tr('Mobile number verified')
                    : context.tr('Add mobile number'),
                subtitle: hasPhone
                    ? phone
                    : context.tr('Add mobile verification for easier sign-in.'),
                onTap: hasPhone ? null : _addPhoneNumber,
                trailing: hasPhone
                    ? const _StatusCheck()
                    : Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.lightText,
                ),
              ),
              _SettingsRow(
                icon: emailVerified
                    ? Icons.mark_email_read_rounded
                    : Icons.email_outlined,
                iconColor: emailVerified ? AppTheme.success : AppTheme.primary,
                title: !hasEmail
                    ? context.tr('Add recovery email')
                    : (emailVerified
                    ? context.tr('Recovery email verified')
                    : context.tr('Verify recovery email')),
                subtitle: !hasEmail
                    ? context.tr('Add an email for sign-in and password recovery.')
                    : (emailVerified
                    ? email
                    : '$email • ${context.tr('Verification pending')}'),
                onTap: !hasEmail
                    ? _addRecoveryEmail
                    : (emailVerified ? null : _sendEmailVerification),
                trailing: emailVerified
                    ? const _StatusCheck()
                    : (hasEmail
                    ? TextButton(
                  onPressed: _isSendingVerification
                      ? null
                      : _sendEmailVerification,
                  child: Text(
                    _isSendingVerification ? context.tr('Sending...') : context.tr('Resend'),
                  ),
                )
                    : Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.lightText,
                )),
              ),
            ],
          ),
          if (hasEmail && !emailVerified) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
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
                      ? context.tr('Checking verification...')
                      : context.tr('I have verified my email'),
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          _SettingsSectionHeader(
            title: context.tr('Language'),
            detail: context.tr(
              'Choose the language used across your Easy Home Control app.',
            ),
          ),
          const SizedBox(height: 10),
          _LanguageSelector(
            selectedLanguage: selectedLanguage,
            onChanged: _changeLanguage,
          ),
          const SizedBox(height: 26),
          _SettingsSectionHeader(
            title: context.tr('Appearance'),
            detail: context.tr('Choose a comfortable light or dark visual theme.'),
          ),
          const SizedBox(height: 10),
          _AppearanceSelector(
            selectedAppearance: selectedAppearance,
            onChanged: _changeAppearance,
          ),
          const SizedBox(height: 26),
          _SettingsSectionHeader(
            title: context.tr('My home'),
            detail: context.tr(
              'Manage the devices already connected to your account.',
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.devices_other_rounded,
                iconColor: AppTheme.primaryDark,
                title: context.tr('Device management'),
                subtitle: context.tr(
                  'Open a device, manage shared access, Wi-Fi, names and device settings.',
                ),
                onTap: _openDeviceManagement,
              ),
              _SettingsRow(
                icon: Icons.wifi_tethering_rounded,
                iconColor: const Color(0xFF0F766E),
                title: context.tr('Device Wi-Fi & recovery'),
                subtitle: context.tr(
                  'Change home Wi-Fi or reconnect a switch after router changes.',
                ),
                onTap: _openDeviceWifi,
              ),
              _SettingsRow(
                icon: Icons.add_home_work_outlined,
                iconColor: AppTheme.primary,
                title: context.tr('Add or join a smart switch'),
                subtitle: context.tr(
                  'Set up a new switch or enter a share code from its owner.',
                ),
                onTap: _openAddDevice,
              ),
              _SettingsRow(
                icon: Icons.inventory_2_outlined,
                iconColor: AppTheme.automation,
                title: context.tr('Archived devices'),
                subtitle: context.tr(
                  'Restore devices you removed from your dashboard.',
                ),
                onTap: _openArchivedDevices,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _SettingsSectionHeader(
            title: context.tr('Help & support'),
            detail: context.tr(
              'Find setup guidance and prepare a clear support request.',
            ),
          ),
          const SizedBox(height: 10),
          _SettingsGroup(
            children: [
              _SettingsRow(
                icon: Icons.menu_book_rounded,
                iconColor: AppTheme.primary,
                title: context.tr('User guide'),
                subtitle: context.tr(
                  'Step-by-step Wi-Fi setup, installation tips, and video guide.',
                ),
                onTap: _openUserGuide,
              ),
              _SettingsRow(
                icon: Icons.support_agent_rounded,
                iconColor: const Color(0xFF0F766E),
                title: context.tr('Support centre'),
                subtitle: context.tr(
                  'Setup help, WiFi troubleshooting, account help and support reference.',
                ),
                onTap: _openSupport,
              ),
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                iconColor: AppTheme.lightText,
                title: context.tr('About Easy Home Control'),
                subtitle: context.tr(
                  'Learn what this app manages for your connected home.',
                ),
                onTap: _showAbout,
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isSigningOut ? null : _confirmSignOut,
              icon: _isSigningOut
                  ? const SizedBox(
                height: 19,
                width: 19,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.logout_rounded),
              label: Text(
                _isSigningOut
                    ? context.tr('Signing out...')
                    : context.tr('Sign out'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SettingsPageHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final helperColor = colorScheme.onSurface.withValues(alpha: 0.68);

    return TechPatternCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 15, 15),
      radius: 24,
      accent: AppTheme.primary,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'EASY HOME CONTROL',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: helperColor,
                    fontSize: 12.5,
                    height: 1.32,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 13),
          const TechIconOrb(
            icon: Icons.tune_rounded,
            color: AppTheme.primary,
            size: 48,
            iconSize: 23,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ],
      ),
    );
  }
}

class _ProfileOverviewCard extends StatelessWidget {
  final String initial;
  final String displayName;
  final String identity;
  final bool protected;

  const _ProfileOverviewCard({
    required this.initial,
    required this.displayName,
    required this.identity,
    required this.protected,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = protected
        ? context.tr('Account protected')
        : context.tr('Protection needs attention');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryDark, AppTheme.primary],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
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
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
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
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  identity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 11),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            protected
                ? Icons.verified_user_rounded
                : Icons.shield_outlined,
            color: Colors.white.withValues(alpha: 0.92),
            size: 24,
          ),
        ],
      ),
    );
  }
}

class _AccountAttentionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final bool loading;

  const _AccountAttentionCard({
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final helperColor = colorScheme.onSurface.withValues(alpha: 0.70);
    final shieldColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFBFD1FF)
        : AppTheme.primaryDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: shieldColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: helperColor,
                    fontSize: 12,
                    height: 1.28,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: loading
                ? const SizedBox(
              height: 17,
              width: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : Text(context.tr('Review')),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final String detail;

  const _SettingsSectionHeader({
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final detailColor = colorScheme.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.72 : 0.62,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: TextStyle(
            color: detailColor,
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.card,
            AppTheme.primary.withValues(alpha: 0.025),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              const Divider(height: 1, indent: 70, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final helperColor = colorScheme.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.70 : 0.60,
    );
    final resolvedTrailing = trailing ??
        (onTap == null
            ? const SizedBox(width: 8)
            : Icon(
          Icons.chevron_right_rounded,
          color: helperColor,
        ));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              TechIconOrb(
                icon: icon,
                color: iconColor,
                size: 42,
                iconSize: 21,
                borderRadius: BorderRadius.circular(14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              resolvedTrailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCheck extends StatelessWidget {
  const _StatusCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      width: 28,
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.11),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        color: AppTheme.success,
        size: 18,
      ),
    );
  }
}

class _AppearanceSelector extends StatelessWidget {
  final AppAppearance selectedAppearance;
  final ValueChanged<AppAppearance> onChanged;

  const _AppearanceSelector({
    required this.selectedAppearance,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _AppearanceOption(
              icon: Icons.light_mode_rounded,
              title: context.tr('Light'),
              subtitle: context.tr('Clean and bright'),
              selected: selectedAppearance == AppAppearance.light,
              onTap: () => onChanged(AppAppearance.light),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AppearanceOption(
              icon: Icons.dark_mode_rounded,
              title: context.tr('Dark'),
              subtitle: context.tr('Easy at night'),
              selected: selectedAppearance == AppAppearance.dark,
              onTap: () => onChanged(AppAppearance.dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _AppearanceOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final helperColor = colorScheme.onSurface.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.70 : 0.60,
    );
    final color = selected ? AppTheme.primary : helperColor;

    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: AppTheme.isDarkMode ? 0.24 : 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.36)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.15 : 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? AppTheme.primary : colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 10.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.primary,
                  size: 19,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  final AppLanguage selectedLanguage;
  final ValueChanged<AppLanguage> onChanged;

  const _LanguageSelector({
    required this.selectedLanguage,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline.withValues(alpha: 0.78)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _LanguageOption(
              title: context.tr('English'),
              subtitle: 'English',
              selected: selectedLanguage == AppLanguage.english,
              onTap: () => onChanged(AppLanguage.english),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _LanguageOption(
              title: context.tr('Urdu'),
              subtitle: 'اردو',
              selected: selectedLanguage == AppLanguage.urdu,
              onTap: () => onChanged(AppLanguage.urdu),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = isDark ? const Color(0xFFBFD1FF) : AppTheme.primaryDark;
    final helperColor = colorScheme.onSurface.withValues(
      alpha: isDark ? 0.70 : 0.60,
    );
    final iconColor = selected ? selectedColor : helperColor;

    return Material(
      color: selected
          ? AppTheme.primary.withValues(alpha: 0.10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.32)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.language_rounded,
                color: iconColor,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? selectedColor : colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: helperColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
