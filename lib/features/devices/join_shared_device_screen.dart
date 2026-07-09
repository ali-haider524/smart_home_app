import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_language.dart';
import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_access.dart';
import '../../services/device_service.dart';

/// Adds an already-configured household switch to a second account. This flow
/// never sends Wi-Fi credentials and never changes the device firmware tree.
class JoinSharedDeviceScreen extends StatefulWidget {
  const JoinSharedDeviceScreen({super.key});

  @override
  State<JoinSharedDeviceScreen> createState() => _JoinSharedDeviceScreenState();
}

class _JoinSharedDeviceScreenState extends State<JoinSharedDeviceScreen> {
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _shareCodeController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController(
    text: 'Smart Switch',
  );

  bool _joining = false;

  @override
  void dispose() {
    _deviceIdController.dispose();
    _shareCodeController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> _join() async {
    FocusScope.of(context).unfocus();

    if (_joining) return;

    setState(() => _joining = true);

    try {
      final result = await _deviceService.joinSharedDeviceForCurrentUser(
        deviceId: _deviceIdController.text,
        inviteCode: _shareCodeController.text,
        nickname: _nicknameController.text,
      );

      if (!mounted) return;
      await _showResult(result);
    } on DeviceClaimException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage(
        context.tr('Could not join this device. Check your internet connection and try again.'),
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _showResult(SharedDeviceJoinResult result) async {
    final transferWaiting = result.outcome == SharedDeviceJoinOutcome.transferWaiting;
    final restored = result.outcome == SharedDeviceJoinOutcome.restored;
    final alreadyAdded = result.outcome == SharedDeviceJoinOutcome.alreadyAdded;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: Icon(
            transferWaiting
                ? Icons.swap_horiz_rounded
                : restored
                ? Icons.unarchive_rounded
                : Icons.verified_rounded,
            color: transferWaiting ? Colors.orange : AppTheme.success,
            size: 34,
          ),
          title: Text(
            context.tr(transferWaiting
                ? 'Transfer request accepted'
                : restored
                ? 'Device restored'
                : alreadyAdded
                ? 'Already in your devices'
                : 'Device added'),
          ),
          content: Text(
            context.languageController.isUrdu
                ? (transferWaiting
                    ? 'موجودہ مالک سے ٹرانسفر مکمل کرنے کو کہیں۔ تصدیق کے بعد سوئچ آپ کی ایپ میں نظر آئے گا۔ وائی فائی سیٹنگز تبدیل نہیں ہوں گی۔'
                    : restored
                    ? '${result.nickname} آپ کے ہوم میں واپس آ گئی ہے۔ وائی فائی سیٹ اپ کی ضرورت نہیں۔'
                    : alreadyAdded
                    ? '${result.nickname} پہلے ہی آپ کے ہوم میں موجود ہے۔'
                    : '${result.nickname} کنٹرول کے لیے تیار ہے۔ شیئرڈ ڈیوائس کے لیے وائی فائی سیٹ اپ کی ضرورت نہیں۔')
                : (transferWaiting
                    ? 'Ask the current owner to complete the transfer. The switch will appear in your app after they confirm it. Wi-Fi settings stay unchanged.'
                    : restored
                    ? '${result.nickname} was restored to your Home. Wi-Fi setup is not needed.'
                    : alreadyAdded
                    ? '${result.nickname} is already available in your Home.'
                    : '${result.nickname} is ready to control. Wi-Fi setup is not needed for a shared device.'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('Done')),
            ),
          ],
        );
      },
    );

    if (mounted) Navigator.pop(context);
  }

  void _openCodeHelp() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.outline,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  context.tr('How shared access works'),
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 9),
                const _HelpRow(
                  icon: Icons.person_add_alt_1_outlined,
                  text: 'Ask the switch owner to open Device settings and choose Manage access.',
                ),
                const SizedBox(height: 12),
                const _HelpRow(
                  icon: Icons.key_outlined,
                  text: 'They create a one-time 20-character share code for you.',
                ),
                const SizedBox(height: 12),
                const _HelpRow(
                  icon: Icons.wifi_off_outlined,
                  text: 'You do not need the printed claim code or the home Wi-Fi password.',
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: Text(context.tr('Got it')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text(context.tr('Join shared device')),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _JoinHeaderCard(),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('Enter shared device details'),
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr('Use the Device ID and temporary code sent by the owner.'),
                    style: TextStyle(
                      color: AppTheme.lightText,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 13),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: _cardDecoration(),
                    child: Column(
                      children: [
                        TextField(
                          controller: _deviceIdController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: context.tr('Device ID'),
                            hintText: context.tr('Example: EHC001A7F92'),
                            prefixIcon: const Icon(Icons.memory_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _shareCodeController,
                          textCapitalization: TextCapitalization.characters,
                          autocorrect: false,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-\s]')),
                          ],
                          decoration: InputDecoration(
                            labelText: context.tr('One-time share code'),
                            hintText: 'ABCD-EFGH-JKLM-NPQR-STUV',
                            prefixIcon: const Icon(Icons.key_rounded),
                            suffixIcon: IconButton(
                              tooltip: context.tr('How to get a code'),
                              onPressed: _openCodeHelp,
                              icon: const Icon(Icons.help_outline_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nicknameController,
                          textCapitalization: TextCapitalization.words,
                          maxLength: 40,
                          decoration: InputDecoration(
                            labelText: context.tr('Name in your app'),
                            hintText: context.tr('Example: Living Room'),
                            prefixIcon: const Icon(Icons.edit_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _joining ? null : _join,
                      icon: _joining
                          ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.link_rounded),
                      label: Text(_joining ? context.tr('Joining device…') : context.tr('Join device')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _JoinSafetyNote(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinHeaderCard extends StatelessWidget {
  const _JoinHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HeaderIcon(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Control a home switch together'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  context.tr('Joining a shared switch does not change its Wi-Fi, timers, or existing schedules.'),
                  style: TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 13,
                    height: 1.38,
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

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(17),
      ),
      child: const Icon(
        Icons.groups_rounded,
        color: Colors.white,
        size: 27,
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryDark, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            context.tr(text),
            style: TextStyle(
              color: AppTheme.lightText,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _JoinSafetyNote extends StatelessWidget {
  const _JoinSafetyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.17)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              context.tr('The owner can remove shared access at any time. A share code works once and expires after 10 minutes.'),
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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(22),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.035),
        blurRadius: 14,
        offset: const Offset(0, 7),
      ),
    ],
  );
}
