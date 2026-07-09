import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../../core/tech_surface.dart';
import 'add_device_screen.dart';
import 'join_shared_device_screen.dart';
import 'reconnect_device_screen.dart';

/// Entry point for the existing device-claim flow.
///
/// This screen intentionally contains no Firebase reads or writes. It only
/// presents the already-tested [AddDeviceScreen] flow in a simpler format.
class AddDeviceHubScreen extends StatelessWidget {
  const AddDeviceHubScreen({super.key});

  Future<void> _openNewDeviceSetup(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddDeviceScreen()),
    );
  }

  Future<void> _openSharedJoin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const JoinSharedDeviceScreen()),
    );
  }

  Future<void> _openReconnectDevice(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ReconnectDeviceScreen()),
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
        title: Text(context.tr('Add device')),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('Set up your home'),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('Set up a new switch, join shared access, or reconnect a registered switch after Wi-Fi changes.'),
                    style: TextStyle(
                      color: AppTheme.lightText,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SetupOverviewCard(),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('Choose an option'),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _AddChoiceCard(
                    icon: Icons.add_link_rounded,
                    title: 'Set up my new switch',
                    subtitle: 'Use the Device ID and printed claim code. You will connect Wi-Fi next.',
                    buttonLabel: 'Start new setup',
                    filled: true,
                    onTap: () => _openNewDeviceSetup(context),
                  ),
                  const SizedBox(height: 12),
                  _AddChoiceCard(
                    icon: Icons.groups_rounded,
                    title: 'Join a shared switch',
                    subtitle: 'Use a temporary code from the owner. No Wi-Fi setup is needed.',
                    buttonLabel: 'Join shared device',
                    filled: false,
                    onTap: () => _openSharedJoin(context),
                  ),
                  const SizedBox(height: 12),
                  _AddChoiceCard(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'Reconnect an existing switch',
                    subtitle: 'Use this after a router, network, or Wi-Fi password change. Pairing is not repeated.',
                    buttonLabel: 'Reconnect switch',
                    filled: false,
                    onTap: () => _openReconnectDevice(context),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.tr('Before new setup'),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _ReadyChecklist(),
                  const SizedBox(height: 14),
                  const _AccountOwnershipNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _AddChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final bool filled;
  final VoidCallback onTap;

  const _AddChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.outline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(icon, color: AppTheme.primaryDark, size: 23),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(title),
                          style: TextStyle(
                            color: AppTheme.darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.tr(subtitle),
                          style: TextStyle(
                            color: AppTheme.lightText,
                            fontSize: 12,
                            height: 1.32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 46,
                child: filled
                    ? FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(context.tr(buttonLabel)),
                )
                    : OutlinedButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(context.tr(buttonLabel)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupOverviewCard extends StatelessWidget {
  const _SetupOverviewCard();

  @override
  Widget build(BuildContext context) {
    return TechHeroSurface(
      padding: const EdgeInsets.all(20),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
                ),
                child: const Icon(
                  Icons.electric_bolt_rounded,
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
                      context.tr('Add a smart switch'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('New setup or shared access'),
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
          const SizedBox(height: 20),
          const Row(
            children: [
              _SetupStep(number: '1', label: 'Pair'),
              _StepLine(),
              _SetupStep(number: '2', label: 'Wi-Fi'),
              _StepLine(),
              _SetupStep(number: '3', label: 'Ready'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            context.tr('Set up a new switch with its printed code, or join a device shared by its owner.'),
            style: TextStyle(
              color: Color(0xFFE6EEFF),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String label;

  const _SetupStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 30,
            width: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(label),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 1,
      margin: const EdgeInsets.only(bottom: 20),
      color: Colors.white.withValues(alpha: 0.45),
    );
  }
}

class _ReadyChecklist extends StatelessWidget {
  const _ReadyChecklist();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Column(
        children: const [
          _ChecklistRow(
            icon: Icons.power_rounded,
            title: 'Switch has power',
            subtitle: 'Turn it on before starting setup.',
          ),
          Divider(height: 26),
          _ChecklistRow(
            icon: Icons.qr_code_2_rounded,
            title: 'Product label is nearby',
            subtitle: 'You need the Device ID and claim code.',
          ),
          Divider(height: 26),
          _ChecklistRow(
            icon: Icons.wifi_rounded,
            title: 'Home Wi-Fi details are ready',
            subtitle: 'You will enter them after pairing.',
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ChecklistRow({
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
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: AppTheme.primaryDark, size: 19),
        ),
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
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountOwnershipNote extends StatelessWidget {
  const _AccountOwnershipNote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: AppTheme.lightText, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('Use the printed claim code only for first ownership. For family access, ask the owner for a temporary share code.'),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
