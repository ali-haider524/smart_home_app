import 'package:flutter/material.dart';

import '../../../core/tech_surface.dart';

/// Shared visual header for email sign-in and account creation.
///
/// This widget is presentation-only. It does not contain authentication state
/// or navigation logic.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool compact;

  const AuthHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return TechHeroSurface(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 18,
        compact ? 15 : 18,
        compact ? 16 : 18,
        compact ? 16 : 19,
      ),
      radius: compact ? 22 : 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: compact ? 44 : 50,
                width: compact ? 44 : 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(compact ? 14 : 16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.white,
                  size: compact ? 23 : 27,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Easy Home Control',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Smart power, simply connected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFDCE8FF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 22 : 27),
          Text(
            title,
            style: TextStyle(
              fontSize: compact ? 26 : 29,
              height: 1.10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.42,
              color: Color(0xFFDCE8FF),
            ),
          ),
        ],
      ),
    );
  }
}
