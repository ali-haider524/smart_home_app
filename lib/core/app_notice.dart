import 'dart:async';

import 'package:flutter/material.dart';

enum AppNoticeType { success, error, info, warning }

/// Consistent in-app feedback shown near the top of the screen.
/// It avoids bottom SnackBars being hidden by navigation bars or keyboards.
class AppNotice {
  AppNotice._();

  static OverlayEntry? _entry;
  static Timer? _dismissTimer;

  static void show(
      BuildContext context,
      String message, {
        AppNoticeType type = AppNoticeType.info,
        Duration duration = const Duration(seconds: 4),
      }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final mediaQuery = MediaQuery.maybeOf(context);
    final topInset = (mediaQuery?.padding.top ?? 0) + 12;

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final style = _NoticeStyle.from(type);

        return Positioned(
          top: topInset,
          left: 16,
          right: 16,
          child: SafeArea(
            top: false,
            bottom: false,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              tween: Tween(begin: 0, end: 1),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, -18 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 620),
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: style.background,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: style.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(style.icon, color: style.foreground, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trimmed,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: style.foreground,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Dismiss',
                        onPressed: dismiss,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: style.foreground.withValues(alpha: 0.78),
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

    overlay.insert(_entry!);
    _dismissTimer = Timer(duration, dismiss);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _NoticeStyle {
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  const _NoticeStyle({
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  factory _NoticeStyle.from(AppNoticeType type) {
    switch (type) {
      case AppNoticeType.success:
        return const _NoticeStyle(
          background: Color(0xFFF0FDF4),
          border: Color(0xFF86EFAC),
          foreground: Color(0xFF166534),
          icon: Icons.check_circle_rounded,
        );
      case AppNoticeType.error:
        return const _NoticeStyle(
          background: Color(0xFFFFF1F2),
          border: Color(0xFFFDA4AF),
          foreground: Color(0xFF9F1239),
          icon: Icons.error_rounded,
        );
      case AppNoticeType.warning:
        return const _NoticeStyle(
          background: Color(0xFFFFFBEB),
          border: Color(0xFFFCD34D),
          foreground: Color(0xFF92400E),
          icon: Icons.warning_amber_rounded,
        );
      case AppNoticeType.info:
        return const _NoticeStyle(
          background: Color(0xFFEFF6FF),
          border: Color(0xFF93C5FD),
          foreground: Color(0xFF1D4ED8),
          icon: Icons.info_rounded,
        );
    }
  }
}
