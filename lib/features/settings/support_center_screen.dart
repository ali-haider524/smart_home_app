import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';

/// Self-service customer support screen.
///
/// It does not transmit support tickets or modify Firebase data. Customers can
/// read practical guidance and copy a useful support reference/message to send
/// through official support channels once those channels are configured.
class SupportCenterScreen extends StatelessWidget {
  const SupportCenterScreen({super.key});

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

  Future<void> _copyReference(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _supportReference()));
    if (!context.mounted) return;
    AppNotice.show(
      context,
      'Support reference copied. Share it only with official support.',
      type: AppNoticeType.success,
    );
  }

  Future<void> _prepareMessage(BuildContext context) async {
    final controller = TextEditingController();

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: _SupportMessageSheet(controller: controller),
        );
      },
    );

    controller.dispose();

    final issue = message?.trim() ?? '';
    if (issue.isEmpty) return;

    final fullMessage = 'Easy Home Control support request\n\n'
        'Issue:\n$issue\n\n${_supportReference()}';

    await Clipboard.setData(ClipboardData(text: fullMessage));
    if (!context.mounted) return;

    AppNotice.show(
      context,
      'Support message copied. Send it through an official support channel.',
      type: AppNoticeType.success,
    );
  }

  void _openTopic(BuildContext context, _HelpTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _HelpTopicSheet(topic: topic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = <_HelpTopic>[
      _HelpTopic(
        icon: Icons.wifi_tethering_error_rounded,
        color: Color(0xFF0F766E),
        title: context.tr('Device is offline'),
        subtitle: context.tr('Check power, WiFi and the last-seen time.'),
        body: 'Make sure the switch has power and your home WiFi is working. Open the device from Home and check its last-seen time. If the switch was moved to another router or the WiFi password changed, use Device Settings to reset WiFi and connect it again.',
      ),
      _HelpTopic(
        icon: Icons.router_outlined,
        color: AppTheme.primary,
        title: context.tr('Connect or change WiFi'),
        subtitle: context.tr('Use the tested setup hotspot flow.'),
        body: 'Open the device, then Device Settings, and choose Change WiFi. The switch will restart in setup mode. Join its Easy Home Control setup hotspot, provide your home WiFi details, and wait for the device to reconnect.',
      ),
      _HelpTopic(
        icon: Icons.timer_outlined,
        color: Color(0xFF7C3AED),
        title: context.tr('Timer or schedule help'),
        subtitle: context.tr('Timers run once; schedules repeat weekly.'),
        body: 'Use a timer when a switch should turn off after one duration. Use a weekly schedule when it should turn on and off at repeated times. The device keeps its latest timer and schedule data locally, but after a power outage it needs valid time again before it can follow clock-based schedules.',
      ),
      _HelpTopic(
        icon: Icons.manage_accounts_outlined,
        color: Color(0xFFB45309),
        title: context.tr('Account access help'),
        subtitle: context.tr('Use linked email or verified mobile.'),
        body: 'Email accounts can use Forgot Password on the login screen. Phone users can sign in again with mobile verification. In Settings, add both a verified mobile number and recovery email to protect access to your devices.',
      ),
    ];

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
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SupportHero(),
                        const SizedBox(height: 24),
                        _SectionTitle(
                          title: context.tr('Quick help'),
                          detail: context.tr('Open a topic for simple steps before contacting support.'),
                        ),
                        const SizedBox(height: 12),
                        ...topics.expand(
                              (topic) => [
                            _HelpTopicCard(
                              topic: topic,
                              onTap: () => _openTopic(context, topic),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _SectionTitle(
                          title: context.tr('Contact preparation'),
                          detail: context.tr('Create a clear reference for official customer support.'),
                        ),
                        const SizedBox(height: 12),
                        _SupportActionCard(
                          icon: Icons.content_copy_rounded,
                          color: AppTheme.primary,
                          title: context.tr('Copy support reference'),
                          subtitle: context.tr('Copies your account reference for faster support verification.'),
                          onTap: () => _copyReference(context),
                        ),
                        const SizedBox(height: 10),
                        _SupportActionCard(
                          icon: Icons.edit_note_rounded,
                          color: const Color(0xFF0F766E),
                          title: context.tr('Prepare a support message'),
                          subtitle: context.tr('Describe the issue and copy a ready-to-send support message.'),
                          onTap: () => _prepareMessage(context),
                        ),
                        const SizedBox(height: 18),
                        const _OfficialChannelNotice(),
                      ],
                    ),
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

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroIcon(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('We are here to help'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  context.tr('Find practical setup guidance, then prepare a clear message for official Easy Home Control support.'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.4,
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

class _HeroIcon extends StatelessWidget {
  const _HeroIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 27),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String detail;

  const _SectionTitle({required this.title, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: const TextStyle(
            color: AppTheme.lightText,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _HelpTopicCard extends StatelessWidget {
  final _HelpTopic topic;
  final VoidCallback onTap;

  const _HelpTopicCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CardButton(
      onTap: onTap,
      child: Row(
        children: [
          _CardIcon(icon: topic.icon, color: topic.color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic.title,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topic.subtitle,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.lightText),
        ],
      ),
    );
  }
}

class _SupportActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardButton(
      onTap: onTap,
      child: Row(
        children: [
          _CardIcon(icon: icon, color: color),
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
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_outward_rounded, color: color),
        ],
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _CardButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(15),
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
          child: child,
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CardIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _OfficialChannelNotice extends StatelessWidget {
  const _OfficialChannelNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_outlined, color: AppTheme.primary),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'For your privacy, share account references and device details only through official Easy Home Control support channels. Direct WhatsApp and email buttons will be configured before public launch.',
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportMessageSheet extends StatelessWidget {
  final TextEditingController controller;

  const _SupportMessageSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(28),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Prepare support message',
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Briefly describe what happened, what you expected, and which device is affected.',
                style: TextStyle(color: AppTheme.lightText, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Example: Bedroom switch is offline after I changed my WiFi password.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, controller.text),
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('Copy support message'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTopicSheet extends StatelessWidget {
  final _HelpTopic topic;

  const _HelpTopicSheet({required this.topic});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(28),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _CardIcon(icon: topic.icon, color: topic.color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      topic.title,
                      style: const TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                topic.body,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTopic {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String body;

  const _HelpTopic({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}
