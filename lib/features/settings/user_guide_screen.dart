import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';

/// Simple customer guide for first-time installation and Wi-Fi setup.
///
/// This screen is informational only. It does not read or write Firebase,
/// device ownership, relay state, timers, schedules, Wi-Fi credentials, or
/// firmware settings.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  static const String _youtubeGuideUrl = 'https://www.youtube.com/@EasyHomeControl';

  Future<void> _openYoutube(BuildContext context) async {
    final uri = Uri.parse(_youtubeGuideUrl);

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // Copy fallback below keeps the guide useful without a browser app.
    }

    await Clipboard.setData(const ClipboardData(text: _youtubeGuideUrl));
    if (!context.mounted) return;
    AppNotice.show(
      context,
      context.tr('YouTube link copied. Open it in your browser.'),
      type: AppNoticeType.success,
    );
  }

  Future<void> _copyYoutube(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _youtubeGuideUrl));
    if (!context.mounted) return;
    AppNotice.show(
      context,
      context.tr('YouTube link copied.'),
      type: AppNoticeType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(context.tr('User guide')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
          children: [
            _GuideHeroCard(
              title: context.tr('Install and connect your switch'),
              subtitle: context.tr(
                'Follow these simple steps to connect your Easy Home Control switch to home Wi-Fi.',
              ),
            ),
            const SizedBox(height: 12),
            _YoutubeGuideCard(
              url: _youtubeGuideUrl,
              onOpen: () => _openYoutube(context),
              onCopy: () => _copyYoutube(context),
            ),
            const SizedBox(height: 16),
            _GuideSectionTitle(
              title: context.tr('Wi-Fi setup steps'),
              subtitle: context.tr('Use these steps for a new switch or after changing your router password.'),
            ),
            const SizedBox(height: 10),
            _GuideStepCard(
              number: '1',
              icon: Icons.electric_bolt_rounded,
              title: context.tr('Power the switch safely'),
              body: context.tr(
                'Power the switch only after safe installation. Do not touch live wiring. For wall installation, use a qualified electrician.',
              ),
            ),
            _GuideStepCard(
              number: '2',
              icon: Icons.qr_code_rounded,
              title: context.tr('Keep the label or box nearby'),
              body: context.tr(
                'You may need the Device ID, claim code, setup hotspot name, and setup password printed on the device label or product box.',
              ),
            ),
            _GuideStepCard(
              number: '3',
              icon: Icons.wifi_tethering_rounded,
              title: context.tr('Open the switch hotspot'),
              body: context.tr(
                'For a new switch, turn it on and wait for the setup hotspot. For reconnect, hold the Wi-Fi button for 3 seconds or wait about 1 minute after Wi-Fi fails.',
              ),
            ),
            _GuideStepCard(
              number: '4',
              icon: Icons.phone_android_rounded,
              title: context.tr('Connect your phone to switch Wi-Fi'),
              body: context.tr(
                'Open phone Wi-Fi settings and join EHC_SETUP_XXXXX using the setup password printed on the label or box.',
              ),
            ),
            _GuideStepCard(
              number: '5',
              icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
              title: context.tr('Stay connected if Android says no internet'),
              body: context.tr(
                'Some phones show “No internet” because the switch hotspot is only for setup. Choose Stay connected, then return to the app.',
              ),
            ),
            _GuideStepCard(
              number: '6',
              icon: Icons.router_rounded,
              title: context.tr('Enter home Wi-Fi details'),
              body: context.tr(
                'Enter your home Wi-Fi name and password in the app. Keep the page open until the switch confirms that Wi-Fi was accepted.',
              ),
            ),
            _GuideStepCard(
              number: '7',
              icon: Icons.check_circle_rounded,
              title: context.tr('Reconnect your phone normally'),
              body: context.tr(
                'After the switch accepts Wi-Fi, connect your phone back to normal Wi-Fi or mobile data and let the app confirm the switch is online.',
              ),
            ),
            const SizedBox(height: 16),
            _GuideSectionTitle(
              title: context.tr('If something does not work'),
              subtitle: context.tr('Try these checks before contacting support.'),
            ),
            const SizedBox(height: 10),
            _GuideTipCard(
              icon: Icons.password_rounded,
              title: context.tr('Wrong Wi-Fi password'),
              body: context.tr(
                'The switch will not save wrong details. Reconnect to the switch hotspot and enter the correct home Wi-Fi password again.',
              ),
            ),
            _GuideTipCard(
              icon: Icons.wifi_off_rounded,
              title: context.tr('Router password changed'),
              body: context.tr(
                'Keep the switch powered. Its recovery hotspot opens automatically after about 1 minute, then you can enter the new home Wi-Fi details.',
              ),
            ),
            _GuideTipCard(
              icon: Icons.refresh_rounded,
              title: context.tr('Hotspot not visible'),
              body: context.tr(
                'Wait a few seconds, refresh phone Wi-Fi, and keep the switch powered. If needed, power cycle the switch once and try again.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideHeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GuideHeroCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            height: 54,
            width: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12.5,
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

class _GuideSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _GuideSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          subtitle,
          style: TextStyle(
            color: colorScheme.onSurface.withValues(alpha: 0.65),
            fontSize: 12,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _GuideStepCard extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String body;

  const _GuideStepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, color: AppTheme.primary, size: 23),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      number,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.36,
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

class _GuideTipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _GuideTipCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppTheme.warning, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.68),
                    fontSize: 12,
                    height: 1.36,
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

class _YoutubeGuideCard extends StatelessWidget {
  final String url;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const _YoutubeGuideCard({
    required this.url,
    required this.onOpen,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Watch video guide'),
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('If setup is confusing, open our YouTube guide.'),
                      style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              url,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.70),
                fontSize: 11.5,
              ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(context.tr('Open YouTube')),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                onPressed: onCopy,
                icon: const Icon(Icons.copy_rounded),
                tooltip: context.tr('Copy link'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
