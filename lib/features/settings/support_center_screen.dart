import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';

/// In-app help and direct customer support contact.
///
/// This screen only prepares support messages and opens external contact apps.
/// It does not change device, timer, schedule, sharing, Wi-Fi, or account data.
class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

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

  String _issueSupportMessage(String issue) {
    return 'Easy Home Control support request\n\n'
        'Issue:\n$issue\n\n'
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

  Future<void> _copyText(
      BuildContext context,
      String text, {
        required String confirmation,
      }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppNotice.show(context, confirmation, type: AppNoticeType.success);
  }

  Future<void> _launchWhatsApp(
      BuildContext context, {
        required String message,
      }) async {
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
      // The copy fallback below keeps support usable without WhatsApp/browser.
    }

    await _copyText(
      context,
      message,
      confirmation: '${context.tr('WhatsApp could not open. Your message was copied; send it to')} $_supportWhatsAppDisplay.',
    );
  }

  Future<void> _launchEmail(
      BuildContext context, {
        required String message,
      }) async {
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
      // The copy fallback below keeps support usable without an email app.
    }

    await _copyText(
      context,
      message,
      confirmation: '${context.tr('Email could not open. Your message was copied; send it to')} $_supportEmail.',
    );
  }

  Future<void> _copyReference(BuildContext context) {
    return _copyText(
      context,
      _supportReference(),
      confirmation: context.tr('Support reference copied.'),
    );
  }

  Future<void> _openContactSheet(
      BuildContext context, {
        required _SupportContact contact,
      }) async {
    final action = await showModalBottomSheet<_ContactAction>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
          ),
          child: _ContactSheet(contact: contact),
        );
      },
    );

    if (!context.mounted || action == null) return;

    final message = _defaultSupportMessage();
    switch (action) {
      case _ContactAction.open:
        if (contact.kind == _ContactKind.whatsApp) {
          await _launchWhatsApp(context, message: message);
        } else {
          await _launchEmail(context, message: message);
        }
        break;
      case _ContactAction.copy:
        await _copyText(
          context,
          message,
          confirmation: context.tr('Support message copied.'),
        );
        break;
    }
  }

  Future<void> _reportProblem(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showModalBottomSheet<_SupportMessageResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
          ),
          child: _SupportMessageSheet(controller: controller),
        );
      },
    );

    controller.dispose();

    final issue = result?.issue.trim() ?? '';
    if (issue.isEmpty || result == null || !context.mounted) return;

    final message = _issueSupportMessage(issue);
    switch (result.delivery) {
      case _SupportDelivery.whatsApp:
        await _launchWhatsApp(context, message: message);
        break;
      case _SupportDelivery.email:
        await _launchEmail(context, message: message);
        break;
      case _SupportDelivery.copy:
        await _copyText(
          context,
          message,
          confirmation: context.tr('Support message copied.'),
        );
        break;
    }
  }

  void _openTopic(BuildContext context, _HelpTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            0,
            12,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 12,
          ),
          child: _HelpTopicSheet(topic: topic),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = <_HelpTopic>[
      _HelpTopic(
        icon: Icons.wifi_off_rounded,
        color: const Color(0xFF0F766E),
        title: 'Device offline',
        body:
        'Confirm the switch has power and your home WiFi is working. Open the device from Home and check its last-seen time. If the switch is online, choose Change WiFi in Device Settings. If it is offline after a router or password change, choose Reconnect WiFi and join its recovery hotspot.',
      ),
      _HelpTopic(
        icon: Icons.timer_outlined,
        color: const Color(0xFF7C3AED),
        title: 'Timer & schedules',
        body:
        'Use a timer when the switch should turn off after one selected duration. Use a weekly schedule for repeated ON and OFF times. The device keeps its latest timer and schedule data locally, but after a long power outage it needs valid time again before clock-based schedules can run.',
      ),
      _HelpTopic(
        icon: Icons.energy_savings_leaf_outlined,
        color: const Color(0xFFB45309),
        title: 'Energy estimate',
        body:
        'Energy Estimate uses the appliance wattage and selected running time. It is not a live electricity meter. Enter the wattage printed on your appliance label and, optionally, your electricity price per unit to see an approximate cost.',
      ),
      _HelpTopic(
        icon: Icons.people_alt_outlined,
        color: AppTheme.primary,
        title: 'Shared device',
        body:
        'The owner opens Device Settings, selects Manage access, and creates a temporary share code. The member chooses Join a shared switch from Add Device. The member does not need the home WiFi password or factory claim code.',
      ),
      _HelpTopic(
        icon: Icons.manage_accounts_outlined,
        color: const Color(0xFF1D4ED8),
        title: 'Account access',
        body:
        'Email accounts can use Forgot Password on the login screen. Phone users can sign in again using mobile verification. In Settings, add both a verified mobile number and a recovery email to protect access to your devices.',
      ),
    ];

    const whatsApp = _SupportContact(
      kind: _ContactKind.whatsApp,
      icon: Icons.chat_rounded,
      color: Color(0xFF16A34A),
      title: 'WhatsApp support',
      value: _supportWhatsAppDisplay,
      description: 'Start a chat with our support team.',
    );
    const email = _SupportContact(
      kind: _ContactKind.email,
      icon: Icons.email_outlined,
      color: Color(0xFF2563EB),
      title: 'Email support',
      value: _supportEmail,
      description: 'Send details and screenshots by email.',
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.background,
        elevation: 0,
        title: Text(context.tr('Help & Support')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          children: [
            const _SupportHero(),
            const SizedBox(height: 20),
            const _SectionHeader(
              title: 'Contact us',
              detail: 'Choose how you would like to contact support.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ContactTile(
                    contact: whatsApp,
                    onTap: () => _openContactSheet(context, contact: whatsApp),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ContactTile(
                    contact: email,
                    onTap: () => _openContactSheet(context, contact: email),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.edit_note_rounded,
              color: AppTheme.primary,
              title: 'Report a problem',
              subtitle: 'Describe an issue and choose WhatsApp, email, or copy.',
              onTap: () => _reportProblem(context),
            ),
            const SizedBox(height: 10),
            _ActionRow(
              icon: Icons.content_copy_rounded,
              color: const Color(0xFF0F766E),
              title: 'Copy support reference',
              subtitle: 'Useful for account verification and troubleshooting.',
              onTap: () => _copyReference(context),
            ),
            const SizedBox(height: 22),
            const _SectionHeader(
              title: 'Quick help',
              detail: 'Tap a topic for simple, step-by-step guidance.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: topics
                  .map(
                    (topic) => _HelpTopicChip(
                  topic: topic,
                  onTap: () => _openTopic(context, topic),
                ),
              )
                  .toList(growable: false),
            ),
            const SizedBox(height: 20),
            const _PrivacyNotice(),
          ],
        ),
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
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
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('How can we help?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('Get help with setup, WiFi, sharing, timers, or your account.'),
                  style: const TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String detail;

  const _SectionHeader({
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(title),
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.tr(detail),
          style: TextStyle(
            color: AppTheme.lightText,
            fontSize: 12,
            height: 1.32,
          ),
        ),
      ],
    );
  }
}

enum _ContactKind { whatsApp, email }

enum _ContactAction { open, copy }

class _SupportContact {
  final _ContactKind kind;
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String description;

  const _SupportContact({
    required this.kind,
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.description,
  });
}

class _ContactTile extends StatelessWidget {
  final _SupportContact contact;
  final VoidCallback onTap;

  const _ContactTile({
    required this.contact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          height: 126,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: contact.color.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ActionIcon(icon: contact.icon, color: contact.color),
              const Spacer(),
              Text(
                context.tr(contact.title),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                contact.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: contact.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.color,
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
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.outline.withValues(alpha: 0.72)),
          ),
          child: Row(
            children: [
              _ActionIcon(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(title),
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr(subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.lightText,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTopicChip extends StatelessWidget {
  final _HelpTopic topic;
  final VoidCallback onTap;

  const _HelpTopicChip({
    required this.topic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: topic.color.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(topic.icon, color: topic.color, size: 17),
              const SizedBox(width: 7),
              Text(
                context.tr(topic.title),
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _ActionIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: AppTheme.primaryDark,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('For your privacy, share your account reference and device details only with official Easy Home Control support.'),
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSheet extends StatelessWidget {
  final _SupportContact contact;

  const _ContactSheet({required this.contact});

  @override
  Widget build(BuildContext context) {
    final actionLabel = contact.kind == _ContactKind.whatsApp
        ? context.tr('Start WhatsApp chat')
        : context.tr('Compose email');

    return _BottomSheetFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          const SizedBox(height: 18),
          _ActionIcon(icon: contact.icon, color: contact.color),
          const SizedBox(height: 13),
          Text(
            context.tr(contact.title),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            context.tr(contact.description),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              contact.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: contact.color,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, _ContactAction.open),
              icon: Icon(contact.icon),
              label: Text(actionLabel),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, _ContactAction.copy),
            icon: const Icon(Icons.content_copy_outlined, size: 18),
            label: Text(context.tr('Copy prepared support message')),
          ),
        ],
      ),
    );
  }
}

enum _SupportDelivery { whatsApp, email, copy }

class _SupportMessageResult {
  final String issue;
  final _SupportDelivery delivery;

  const _SupportMessageResult({
    required this.issue,
    required this.delivery,
  });
}

class _SupportMessageSheet extends StatelessWidget {
  final TextEditingController controller;

  const _SupportMessageSheet({required this.controller});

  void _submit(BuildContext context, _SupportDelivery delivery) {
    Navigator.pop(
      context,
      _SupportMessageResult(issue: controller.text, delivery: delivery),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _SheetHandle()),
          const SizedBox(height: 16),
          Row(
            children: [
              const _ActionIcon(
                icon: Icons.edit_note_rounded,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  context.tr('Report a problem'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('Close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('Describe what happened and which switch is affected. Your account reference is included automatically.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            minLines: 4,
            maxLines: 7,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: context.tr(
                'Example: Bedroom switch is offline after I changed my WiFi password.',
              ),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () => _submit(context, _SupportDelivery.whatsApp),
              icon: const Icon(Icons.chat_rounded),
              label: Text(context.tr('Send by WhatsApp')),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _submit(context, _SupportDelivery.email),
              icon: const Icon(Icons.email_outlined),
              label: Text(context.tr('Send by email')),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => _submit(context, _SupportDelivery.copy),
              icon: const Icon(Icons.content_copy_outlined, size: 18),
              label: Text(context.tr('Copy message instead')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTopicSheet extends StatelessWidget {
  final _HelpTopic topic;

  const _HelpTopicSheet({required this.topic});

  @override
  Widget build(BuildContext context) {
    return _BottomSheetFrame(
      scrollable: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: _SheetHandle()),
          const SizedBox(height: 16),
          Row(
            children: [
              _ActionIcon(icon: topic.icon, color: topic.color),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  context.tr(topic.title),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.tr('Close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            context.tr(topic.body),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.tr('Got it')),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomSheetFrame extends StatelessWidget {
  final Widget child;
  final bool scrollable;

  const _BottomSheetFrame({
    required this.child,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: child,
    );

    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: scrollable
              ? SingleChildScrollView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            child: body,
          )
              : body,
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 5,
      width: 44,
      decoration: BoxDecoration(
        color: AppTheme.outline.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _HelpTopic {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _HelpTopic({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}
