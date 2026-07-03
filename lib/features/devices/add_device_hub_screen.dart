import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import 'add_device_screen.dart';

/// Landing experience for the Add tab.
///
/// This screen deliberately contains no Firebase reads or writes. It only
/// guides the customer into the existing, tested AddDeviceScreen pairing flow.
class AddDeviceHubScreen extends StatelessWidget {
  const AddDeviceHubScreen({super.key});

  Future<void> _openPairing(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 132),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Header(),
                            const SizedBox(height: 22),
                            _SetupHero(onPair: () => _openPairing(context)),
                            const SizedBox(height: 24),
                            _SectionTitle(
                              title: context.tr('Before you begin'),
                              subtitle: context.tr('Keep these three things ready for a smooth setup.'),
                            ),
                            const SizedBox(height: 12),
                            const _ReadinessCard(),
                            const SizedBox(height: 24),
                            _SectionTitle(
                              title: context.tr('How setup works'),
                              subtitle: context.tr('Pair first, then connect the switch to your home WiFi.'),
                            ),
                            const SizedBox(height: 12),
                            const _StepTimeline(),
                            const SizedBox(height: 20),
                            const _ExistingDeviceHint(),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: FilledButton.icon(
                                onPressed: () => _openPairing(context),
                                icon: const Icon(Icons.add_link_rounded),
                                label: Text(
                                  context.tr('Pair a new device'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Text(
                                context.tr('Your device remains fully under your account after pairing.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.lightText,
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('Add device'),
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 6),
        Text(
          context.tr('Set up a new Easy Home Control smart switch.'),
          style: TextStyle(
            color: AppTheme.lightText,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _SetupHero extends StatelessWidget {
  final VoidCallback onPair;

  const _SetupHero({required this.onPair});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Ready to connect a switch?'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      context.tr('It only takes a few guided steps.'),
                      style: TextStyle(
                        color: Color(0xFFDCE8FF),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('Start by entering the Device ID and claim code printed on your product label. You will connect to the EHC setup hotspot only after pairing succeeds.'),
            style: TextStyle(
              color: Color(0xFFE6EEFF),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onPair,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: AppTheme.primaryDark,
                        size: 19,
                      ),
                      SizedBox(width: 8),
                      Text(
                        context.tr('Start setup'),
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
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
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          _ReadinessRow(
            icon: Icons.power_rounded,
            title: context.tr('Device powered on'),
            subtitle: context.tr('Plug in or power the smart switch before setup.'),
          ),
          _Divider(),
          _ReadinessRow(
            icon: Icons.qr_code_2_rounded,
            title: context.tr('Product label nearby'),
            subtitle: context.tr('You will need its Device ID and claim code.'),
          ),
          _Divider(),
          _ReadinessRow(
            icon: Icons.wifi_rounded,
            title: context.tr('Home WiFi details'),
            subtitle: context.tr('Keep your WiFi name and password ready for the next step.'),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReadinessRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
          child: Icon(icon, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.38,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepTimeline extends StatelessWidget {
  const _StepTimeline();

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        children: [
          _TimelineRow(
            number: '1',
            title: context.tr('Pair the device'),
            subtitle: context.tr('Enter the Device ID, claim code, and a name for your switch.'),
          ),
          _TimelineConnector(),
          _TimelineRow(
            number: '2',
            title: context.tr('Join the setup hotspot'),
            subtitle: context.tr('Connect your phone to EHC_SETUP_A7F92 when the app asks.'),
          ),
          _TimelineConnector(),
          _TimelineRow(
            number: '3',
            title: context.tr('Connect home WiFi'),
            subtitle: context.tr('The switch tests your WiFi details, then appears online in Home.'),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _TimelineRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 29,
          width: 29,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.lightText,
                    fontSize: 12,
                    height: 1.38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineConnector extends StatelessWidget {
  const _TimelineConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 14, top: 5, bottom: 5),
      child: SizedBox(
        height: 14,
        child: VerticalDivider(
          width: 1,
          thickness: 1.4,
          color: Color(0xFFBFDBFE),
        ),
      ),
    );
  }
}

class _ExistingDeviceHint extends StatelessWidget {
  const _ExistingDeviceHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppTheme.primaryDark,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('Already added this device? Open it from Home, then use Device Settings to rename it or change WiFi.'),
              style: TextStyle(
                color: AppTheme.darkText,
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

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFE7EDF6),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;

  const _SurfaceCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
