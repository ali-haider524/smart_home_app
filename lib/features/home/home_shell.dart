import 'package:flutter/material.dart';

import '../../core/app_appearance.dart';
import '../../core/app_language.dart';
import '../../core/app_theme.dart';
import '../automation/automation_hub_screen.dart';
import '../devices/dashboard_screen.dart';
import '../settings/app_settings_screen.dart';
import '../settings/user_guide_screen.dart';
import '../settings/floating_support_button.dart';

/// Main app shell.
///
/// System back is handled as a tab-navigation action first: pressing back from
/// Auto or Settings returns the customer to Home instead of closing the app.
/// Android keeps its normal exit behavior only when Home is already selected.
///
/// Appearance changes are observed here so the visible tab, bottom navigation,
/// and floating support button rebuild immediately. This is presentation-only:
/// it does not change Firebase, device, timer, schedule, Wi-Fi, or relay logic.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  /// Return a fresh widget configuration on each shell rebuild. Flutter retains
  /// the existing State for the same tab type, while every visible widget gets
  /// a chance to resolve the current light/dark presentation tokens at once.
  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
      // ignore: prefer_const_constructors
        return AutomationHubScreen();
      case 2:
      // ignore: prefer_const_constructors
        return UserGuideScreen();
      case 3:
      // ignore: prefer_const_constructors
        return AppSettingsScreen();
      case 0:
      default:
      // ignore: prefer_const_constructors
        return DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearanceController = context.appearanceController;

    return AnimatedBuilder(
      animation: appearanceController,
      builder: (context, _) {
        return PopScope<void>(
          canPop: _selectedIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || _selectedIndex == 0) return;
            setState(() => _selectedIndex = 0);
          },
          child: Scaffold(
            backgroundColor: AppTheme.background,
            body: _buildSelectedPage(),
            // Intentionally non-const so this visual-only widget receives the
            // same immediate appearance rebuild as the active tab.
            // ignore: prefer_const_constructors
            floatingActionButton: FloatingSupportButton(),
            floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.card,
                    AppTheme.electricSoft.withValues(alpha: 0.55),
                  ],
                ),
                border: Border(
                  top: BorderSide(
                    color: AppTheme.primary.withValues(alpha: 0.09),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.035),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 74,
                  child: Row(
                    children: [
                      Expanded(
                        child: _SimpleNavItem(
                          icon: Icons.home_rounded,
                          activeIcon: Icons.home_rounded,
                          label: context.tr('Home'),
                          selected: _selectedIndex == 0,
                          onTap: () => _selectTab(0),
                        ),
                      ),
                      Expanded(
                        child: _SimpleNavItem(
                          icon: Icons.schedule_outlined,
                          activeIcon: Icons.schedule_rounded,
                          label: context.tr('Auto'),
                          selected: _selectedIndex == 1,
                          onTap: () => _selectTab(1),
                        ),
                      ),
                      Expanded(
                        child: _SimpleNavItem(
                          icon: Icons.menu_book_outlined,
                          activeIcon: Icons.menu_book_rounded,
                          label: context.tr('Guide'),
                          selected: _selectedIndex == 2,
                          onTap: () => _selectTab(2),
                        ),
                      ),
                      Expanded(
                        child: _SimpleNavItem(
                          icon: Icons.settings_outlined,
                          activeIcon: Icons.settings_rounded,
                          label: context.tr('Settings'),
                          selected: _selectedIndex == 3,
                          onTap: () => _selectTab(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SimpleNavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SimpleNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primary : AppTheme.lightText;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: selected ? 22 : 0,
                  margin: const EdgeInsets.only(bottom: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.electric,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  height: 31,
                  width: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: selected
                        ? Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.10),
                    )
                        : null,
                  ),
                  child: Icon(
                    selected ? activeIcon : icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
