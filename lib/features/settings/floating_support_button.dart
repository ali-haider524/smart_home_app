import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import 'support_center_screen.dart';

/// Compact, icon-first support access for the main HomeShell tabs.
///
/// It only opens WhatsApp, email, or the existing Help & Support screen.
/// It does not read or write device, timer, schedule, sharing, Wi-Fi, or
/// account data.
class FloatingSupportButton extends StatelessWidget {
  const FloatingSupportButton({super.key});

  static const String _supportWhatsAppDigits = '923218724280';
  static const String _supportWhatsAppDisplay = '0321 8724280';
  static const String _supportEmail = 'aleesalar@gmail.com';

  String _supportReference() {
    final user = FirebaseAuth.instance.currentUser;
    final identity = (user?.email?.trim().isNotEmpty ?? false)
        ? user!.email!.trim()
        : (user?.phoneNumber?.trim().isNotEmpty ?? false)
        ? user!.phoneNumber!.trim()
        : 'Not available';
    final uid = user?.uid ?? 'Not available';

    return 'Easy Home Control support reference\n'
        'Account: $identity\n'
        'Account ID: $uid\n'
        'Please share this only with official Easy Home Control support.';
  }

  String _defaultSupportMessage() {
    return 'Hello Easy Home Control support,\n\n'
        'I need help with my account or device.\n\n'
        '${_supportReference()}';
  }

  String _encodeQuery(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
      '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
    )
        .join('&');
  }

  Future<void> _copyFallback(
      BuildContext context,
      String message, {
        required String confirmation,
      }) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    AppNotice.show(context, confirmation, type: AppNoticeType.success);
  }

  Future<void> _openWhatsApp(BuildContext context, String message) async {
    final uri = Uri.parse(
      'https://wa.me/$_supportWhatsAppDigits?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // The copy fallback below keeps support available without WhatsApp.
    }

    await _copyFallback(
      context,
      message,
      confirmation:
      'WhatsApp could not open. Your message was copied; send it to $_supportWhatsAppDisplay.',
    );
  }

  Future<void> _openEmail(BuildContext context, String message) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: _encodeQuery({
        'subject': 'Easy Home Control support request',
        'body': message,
      }),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    } catch (_) {
      // The copy fallback below keeps support available without an email app.
    }

    await _copyFallback(
      context,
      message,
      confirmation:
      'Email could not open. Your message was copied; send it to $_supportEmail.',
    );
  }

  Future<void> _showSupportMenu(BuildContext context) async {
    final action = await showModalBottomSheet<_QuickSupportAction>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => const _QuickSupportSheet(),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _QuickSupportAction.whatsApp:
        await _openWhatsApp(context, _defaultSupportMessage());
        break;
      case _QuickSupportAction.email:
        await _openEmail(context, _defaultSupportMessage());
        break;
      case _QuickSupportAction.helpCenter:
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupportCenterScreen()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open support options',
      child: FloatingActionButton(
        heroTag: 'easy_home_control_support_fab',
        tooltip: 'Support',
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        onPressed: () => _showSupportMenu(context),
        child: const Icon(Icons.support_agent_rounded, size: 26),
      ),
    );
  }
}

enum _QuickSupportAction { whatsApp, email, helpCenter }

class _QuickSupportSheet extends StatelessWidget {
  const _QuickSupportSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 13, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 42,
                decoration: BoxDecoration(
                  color: AppTheme.outline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                'Need help?',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose how you would like to contact us.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _QuickSupportIconAction(
                      icon: Icons.chat_rounded,
                      iconColor: const Color(0xFF16A34A),
                      title: 'WhatsApp',
                      subtitle: 'Start chat',
                      onTap: () => Navigator.pop(
                        context,
                        _QuickSupportAction.whatsApp,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickSupportIconAction(
                      icon: Icons.email_rounded,
                      iconColor: AppTheme.primary,
                      title: 'Email',
                      subtitle: 'Send details',
                      onTap: () => Navigator.pop(
                        context,
                        _QuickSupportAction.email,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _QuickSupportAction.helpCenter,
                ),
                icon: const Icon(Icons.help_outline_rounded, size: 19),
                label: const Text('Open Help Center'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSupportIconAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickSupportIconAction({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Column(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 27),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
