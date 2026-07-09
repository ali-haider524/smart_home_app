import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../home/home_shell.dart';

/// One-time welcome after a newly-created account.
///
/// The screen is opened only from the existing new-account flow. It stores no
/// account data and changes no Firebase, device or automation behaviour.
class WelcomeOnboardingScreen extends StatefulWidget {
  const WelcomeOnboardingScreen({super.key});

  @override
  State<WelcomeOnboardingScreen> createState() =>
      _WelcomeOnboardingScreenState();
}

class _WelcomeOnboardingScreenState extends State<WelcomeOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static final List<_WelcomeStep> _steps = [
    _WelcomeStep(
      icon: Icons.power_settings_new_rounded,
      title: 'Control with one tap',
      description:
      'Turn connected switches on or off from your phone, wherever you are.',
      color: AppTheme.primary,
    ),
    _WelcomeStep(
      icon: Icons.add_link_rounded,
      title: 'Add your first switch',
      description:
      'Use the Device ID and Claim Code from your Easy Home Control device, then connect it to Wi-Fi.',
      color: AppTheme.automation,
    ),
    _WelcomeStep(
      icon: Icons.schedule_rounded,
      title: 'Make your home automatic',
      description:
      'Set timers and weekly schedules. You can also see a clear energy estimate for your appliance.',
      color: AppTheme.success,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _finish();
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastStep = _currentPage == _steps.length - 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _finish,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _WelcomeStepView(step: _steps[index]);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                      (index) {
                    final selected = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 8,
                      width: selected ? 26 : 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.primary
                            : AppTheme.outline,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _continue,
                  icon: Icon(
                    lastStep
                        ? Icons.home_rounded
                        : Icons.arrow_forward_rounded,
                  ),
                  label: Text(lastStep ? 'Go to Home' : 'Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeStep {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _WelcomeStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _WelcomeStepView extends StatelessWidget {
  final _WelcomeStep step;

  const _WelcomeStepView({required this.step});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: step.color.withValues(alpha: 0.18),
                width: 10,
              ),
            ),
            child: Icon(step.icon, color: step.color, size: 54),
          ),
          const SizedBox(height: 36),
          Text(
            step.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 28,
              height: 1.12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Text(
              step.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.lightText,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
