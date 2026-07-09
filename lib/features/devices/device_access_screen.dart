import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../models/device_access.dart';
import '../../services/device_service.dart';

/// Owner-only access management. It changes account access records only; the
/// ESP, relay commands, timers, schedules, and saved Wi-Fi are never touched.
class DeviceAccessScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const DeviceAccessScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<DeviceAccessScreen> createState() => _DeviceAccessScreenState();
}

class _DeviceAccessScreenState extends State<DeviceAccessScreen> {
  final DeviceService _deviceService = DeviceService();

  bool _preparing = true;
  bool _busy = false;
  DeviceAccessInvite? _shareInvite;
  DeviceAccessInvite? _transferInvite;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  Future<void> _prepare() async {
    try {
      await _deviceService.ensureCurrentOwnerAccessRecord(widget.deviceId);
      final activeInvites =
      await _deviceService.loadCurrentOwnerAccessInvites(widget.deviceId);

      if (!mounted) return;
      setState(() {
        _shareInvite = activeInvites[DeviceInviteType.share];
        _transferInvite = activeInvites[DeviceInviteType.transfer];
      });
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
      if (mounted) Navigator.pop(context);
      return;
    } catch (_) {
      _showMessage('Could not load device access. Please try again.');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _createInvite(DeviceInviteType type) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final invite = await _deviceService.createDeviceAccessInvite(
        deviceId: widget.deviceId,
        type: type,
      );

      if (!mounted) return;
      setState(() {
        if (type == DeviceInviteType.share) {
          _shareInvite = invite;
        } else {
          _transferInvite = invite;
        }
      });
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage(
        'Could not create a code. Check your internet connection and try again.',
        type: AppNoticeType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelInvite(DeviceInviteType type) async {
    final invite = type == DeviceInviteType.share ? _shareInvite : _transferInvite;
    if (invite == null || _busy) return;

    setState(() => _busy = true);

    try {
      await _deviceService.cancelDeviceAccessInvite(invite.code);
      if (!mounted) return;
      setState(() {
        if (type == DeviceInviteType.share) {
          _shareInvite = null;
        } else {
          _transferInvite = null;
        }
      });
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage('Could not cancel this code. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeMember(DeviceAccessMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove shared access?'),
          content: Text(
            '${member.displayLabel} will no longer be able to view or control ${widget.deviceName}. This does not reset Wi-Fi, timers, schedules, or the switch itself.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _deviceService.removeSharedDeviceMember(
        deviceId: widget.deviceId,
        memberUid: member.uid,
      );
      _showMessage('Shared access removed.', type: AppNoticeType.success);
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage('Could not remove shared access. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmTransferStart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.swap_horiz_rounded, color: Colors.orange),
          title: const Text('Transfer ownership?'),
          content: const Text(
            'Create a one-time transfer code for the new owner. They must accept it before you can finish the transfer. Wi-Fi settings stay unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create transfer code'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _createInvite(DeviceInviteType.transfer);
    }
  }

  Future<void> _completeTransfer(DeviceAccessInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          title: const Text('Complete ownership transfer?'),
          content: const Text(
            'This permanently removes your access and removes all current shared members. The new owner keeps the device Wi-Fi, timers, and schedules.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Transfer ownership'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await _deviceService.completeOwnershipTransfer(
        deviceId: widget.deviceId,
        inviteCode: invite.code,
      );

      if (!mounted) return;
      _showMessage('Ownership transferred.', type: AppNoticeType.success);
      Navigator.pop(context, true);
    } on DeviceMaintenanceException catch (error) {
      _showMessage(error.message, type: AppNoticeType.error);
    } catch (_) {
      _showMessage('Could not complete ownership transfer. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Manage access'),
      ),
      body: _preparing
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 34),
        children: [
          _AccessHeroCard(deviceName: widget.deviceName),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'Share this device',
            subtitle: 'Give a family member control without sharing your account.',
          ),
          const SizedBox(height: 11),
          _ShareCodeCard(
            invite: _shareInvite,
            deviceService: _deviceService,
            busy: _busy,
            onCreate: () => _createInvite(DeviceInviteType.share),
            onCancel: () => _cancelInvite(DeviceInviteType.share),
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'People with access',
            subtitle: 'Members can control power and timers. Only you can change schedules, Wi-Fi, or ownership.',
          ),
          const SizedBox(height: 11),
          StreamBuilder<List<DeviceAccessMember>>(
            stream: _deviceService.listenDeviceAccessMembers(widget.deviceId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _SimpleMessageCard(
                  icon: Icons.cloud_off_outlined,
                  title: 'Could not load access list',
                  subtitle: 'Check your internet connection and try again.',
                );
              }

              final members = snapshot.data ?? const <DeviceAccessMember>[];
              return _AccessMembersCard(
                members: members,
                busy: _busy,
                onRemove: _removeMember,
              );
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            title: 'Transfer ownership',
            subtitle: 'Use this when the device is sold or moved to another owner.',
          ),
          const SizedBox(height: 11),
          _TransferCard(
            initialInvite: _transferInvite,
            busy: _busy,
            deviceService: _deviceService,
            onCreate: _confirmTransferStart,
            onCancel: () => _cancelInvite(DeviceInviteType.transfer),
            onComplete: _completeTransfer,
          ),
          const SizedBox(height: 15),
          const _TransferNote(),
        ],
      ),
    );
  }
}

class _AccessHeroCard extends StatelessWidget {
  final String deviceName;

  const _AccessHeroCard({required this.deviceName});

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
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: const Icon(Icons.groups_rounded, color: Colors.white, size: 27),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'You are the owner. You decide who can use this smart switch.',
                  style: TextStyle(
                    color: Color(0xFFDCE8FF),
                    fontSize: 13,
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: AppTheme.lightText,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ShareCodeCard extends StatelessWidget {
  final DeviceAccessInvite? invite;
  final DeviceService deviceService;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onCancel;

  const _ShareCodeCard({
    required this.invite,
    required this.deviceService,
    required this.busy,
    required this.onCreate,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (invite == null) {
      return _ShareCodeStartCard(busy: busy, onCreate: onCreate);
    }

    return StreamBuilder<DeviceAccessInvite?>(
      stream: deviceService.listenDeviceAccessInvite(invite!.code),
      initialData: invite,
      builder: (context, snapshot) {
        final current = snapshot.data ?? invite!;

        if (current.isPending) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: _softCardDecoration(),
            child: _CodePanel(
              invite: current,
              description: 'Send this code only to someone you trust. It works once, expires in 10 minutes, and remains available if you leave this page.',
              busy: busy,
              onCancel: onCancel,
            ),
          );
        }

        return _ShareCodeStartCard(
          busy: busy,
          onCreate: onCreate,
          usedMessage: current.status == DeviceInviteStatus.accepted
              ? 'The previous share code was used. Create a new one for another member.'
              : null,
        );
      },
    );
  }
}

class _ShareCodeStartCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;
  final String? usedMessage;

  const _ShareCodeStartCard({
    required this.busy,
    required this.onCreate,
    this.usedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardIcon(
                icon: Icons.person_add_alt_1_rounded,
                color: AppTheme.primaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create one-time share code',
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Creating a code is your approval. It works once and the code stays available for 10 minutes.',
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
          if (usedMessage != null) ...[
            const SizedBox(height: 11),
            Text(
              usedMessage!,
              style: const TextStyle(
                color: AppTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.key_rounded),
              label: const Text('Create share code'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final DeviceAccessInvite? initialInvite;
  final bool busy;
  final DeviceService deviceService;
  final VoidCallback onCreate;
  final VoidCallback onCancel;
  final ValueChanged<DeviceAccessInvite> onComplete;

  const _TransferCard({
    required this.initialInvite,
    required this.busy,
    required this.deviceService,
    required this.onCreate,
    required this.onCancel,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    if (initialInvite == null) {
      return _TransferStartCard(busy: busy, onCreate: onCreate);
    }

    return StreamBuilder<DeviceAccessInvite?>(
      stream: deviceService.listenDeviceAccessInvite(initialInvite!.code),
      initialData: initialInvite,
      builder: (context, snapshot) {
        final invite = snapshot.data ?? initialInvite!;

        if (invite.status == DeviceInviteStatus.accepted) {
          return _TransferAcceptedCard(
            invite: invite,
            busy: busy,
            onComplete: () => onComplete(invite),
          );
        }

        if (invite.isPending) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: _softCardDecoration(),
            child: _CodePanel(
              invite: invite,
              description: 'Ask the new owner to open Join shared device and enter this code. The pending transfer remains here if you leave; you must confirm after they accept.',
              busy: busy,
              onCancel: onCancel,
            ),
          );
        }

        return _TransferStartCard(busy: busy, onCreate: onCreate);
      },
    );
  }
}

class _TransferStartCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onCreate;

  const _TransferStartCard({required this.busy, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _softCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardIcon(icon: Icons.swap_horiz_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Move this device to a new owner',
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'The new owner accepts first. Then you approve the final transfer.',
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
          const SizedBox(height: 15),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: busy ? null : onCreate,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Start ownership transfer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferAcceptedCard extends StatelessWidget {
  final DeviceAccessInvite invite;
  final bool busy;
  final VoidCallback onComplete;

  const _TransferAcceptedCard({
    required this.invite,
    required this.busy,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardIcon(icon: Icons.verified_user_rounded, color: Colors.orange),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New owner accepted',
                      style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      invite.recipientLabel.isEmpty
                          ? 'Review the warning, then complete the transfer.'
                          : '${invite.recipientLabel} accepted this transfer.',
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
          const SizedBox(height: 15),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: busy ? null : onComplete,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Complete transfer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodePanel extends StatelessWidget {
  final DeviceAccessInvite invite;
  final String description;
  final bool busy;
  final VoidCallback onCancel;

  const _CodePanel({
    required this.invite,
    required this.description,
    required this.busy,
    required this.onCancel,
  });

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: invite.displayCode));
    if (!context.mounted) return;
    AppNotice.show(context, 'Code copied.', type: AppNoticeType.success);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          invite.type == DeviceInviteType.transfer ? 'Transfer code' : 'Share code',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: AppTheme.lightText,
            fontSize: 12,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.outline),
          ),
          child: Row(
            children: [
              Expanded(
                child: SelectableText(
                  invite.displayCode,
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.15,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy_rounded, color: AppTheme.primaryDark),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: busy ? null : onCancel,
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Cancel code'),
          ),
        ),
      ],
    );
  }
}

class _AccessMembersCard extends StatelessWidget {
  final List<DeviceAccessMember> members;
  final bool busy;
  final ValueChanged<DeviceAccessMember> onRemove;

  const _AccessMembersCard({
    required this.members,
    required this.busy,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return const _SimpleMessageCard(
        icon: Icons.group_off_outlined,
        title: 'No access records yet',
        subtitle: 'Create a share code to invite someone.',
      );
    }

    return Container(
      decoration: _softCardDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        primary: false,
        itemCount: members.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final member = members[index];
          final owner = member.isOwner;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            leading: _CardIcon(
              icon: owner ? Icons.admin_panel_settings_outlined : Icons.person_outline_rounded,
              color: owner ? AppTheme.primaryDark : AppTheme.success,
            ),
            title: Text(
              owner ? 'You (owner)' : member.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            subtitle: Text(
              owner ? 'Full device management' : 'Can control power and timers',
              style: TextStyle(color: AppTheme.lightText, fontSize: 12),
            ),
            trailing: owner
                ? const _OwnerPill()
                : IconButton(
              tooltip: 'Remove access',
              onPressed: busy ? null : () => onRemove(member),
              icon: const Icon(Icons.person_remove_outlined, color: Colors.red),
            ),
          );
        },
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _OwnerPill extends StatelessWidget {
  const _OwnerPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        'OWNER',
        style: TextStyle(
          color: AppTheme.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _SimpleMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimpleMessageCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: _softCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardIcon(icon: icon, color: AppTheme.primaryDark),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
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
    );
  }
}

class _TransferNote extends StatelessWidget {
  const _TransferNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transfer removes your access and removes all current shared members. It does not reset the saved Wi-Fi. Reset Wi-Fi before handover when the device is moving to a different home.',
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

BoxDecoration _softCardDecoration() {
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
