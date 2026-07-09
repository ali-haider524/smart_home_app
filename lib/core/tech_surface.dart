import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Reusable presentation-only surfaces for the Easy Home Control visual system.
///
/// These widgets draw a low-contrast circuit pattern and soft electric glow.
/// They do not read data, handle navigation, or change any Firebase/device logic.
class TechHeroSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? colors;

  const TechHeroSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    final resolvedColors = colors ?? const <Color>[
      AppTheme.primaryDark,
      AppTheme.primary,
      AppTheme.electric,
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: resolvedColors,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
        boxShadow: [
          BoxShadow(
            color: resolvedColors.first.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CircuitPatternPainter(
                    color: Colors.white.withValues(alpha: 0.14),
                    dense: false,
                  ),
                ),
              ),
            ),
            Positioned(
              top: -68,
              right: -46,
              child: _GlowOrb(
                size: 178,
                color: Colors.white.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              left: -48,
              bottom: -74,
              child: _GlowOrb(
                size: 144,
                color: AppTheme.electric.withValues(alpha: 0.18),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// A white card with a very light electrical pattern for information-dense
/// screens. It preserves the existing light and readable app layout.
class TechPatternCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color accent;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const TechPatternCard({
    super.key,
    required this.child,
    required this.padding,
    this.radius = 22,
    this.accent = AppTheme.primary,
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.card,
            accent.withValues(alpha: 0.055),
            AppTheme.card,
          ],
        ),
        borderRadius: borderRadius,
        border: border ?? Border.all(color: accent.withValues(alpha: 0.15)),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: accent.withValues(alpha: 0.055),
            blurRadius: 17,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.018),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CircuitPatternPainter(
                    color: accent.withValues(alpha: 0.055),
                    dense: true,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -42,
              top: -54,
              child: _GlowOrb(
                size: 130,
                color: accent.withValues(alpha: 0.075),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class TechIconOrb extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final BorderRadius? borderRadius;

  const TechIconOrb({
    super.key,
    required this.icon,
    required this.color,
    this.size = 44,
    this.iconSize = 22,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.34);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.45, -0.5),
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.09),
          ],
        ),
        borderRadius: radius,
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}

class _CircuitPatternPainter extends CustomPainter {
  final Color color;
  final bool dense;

  const _CircuitPatternPainter({required this.color, required this.dense});

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = dense ? 0.8 : 1.0;
    final nodePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final step = dense ? 44.0 : 56.0;
    final horizontalRows = dense ? 3 : 2;

    for (var row = 0; row < horizontalRows; row++) {
      final y = 24 + row * (size.height / (horizontalRows + 1));
      final path = Path()
        ..moveTo(-12, y)
        ..lineTo(size.width * 0.25, y)
        ..lineTo(size.width * 0.25 + 16, y + 16)
        ..lineTo(size.width * 0.54, y + 16)
        ..lineTo(size.width * 0.54 + 15, y)
        ..lineTo(size.width + 16, y);
      canvas.drawPath(path, linePaint);

      canvas.drawCircle(Offset(size.width * 0.25, y), dense ? 2.0 : 2.5, nodePaint);
      canvas.drawCircle(
        Offset(size.width * 0.54 + 15, y),
        dense ? 2.0 : 2.5,
        nodePaint,
      );
    }

    for (var x = step * 0.55; x < size.width; x += step) {
      final startY = dense ? size.height * 0.55 : size.height * 0.63;
      final path = Path()
        ..moveTo(x, size.height + 12)
        ..lineTo(x, startY + 18)
        ..lineTo(x + 18, startY)
        ..lineTo(x + 18, -12);
      canvas.drawPath(path, linePaint);
      canvas.drawCircle(Offset(x + 18, startY), dense ? 1.8 : 2.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircuitPatternPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.dense != dense;
  }
}
