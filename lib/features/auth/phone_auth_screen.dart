import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
import 'account_protection_screen.dart';
import 'phone_auth_mode.dart';
import 'phone_otp_screen.dart';

class PhoneAuthScreen extends StatefulWidget {
  final PhoneAuthMode mode;

  const PhoneAuthScreen({
    super.key,
    this.mode = PhoneAuthMode.signIn,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();

  bool _isSending = false;
  bool _completed = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _goAfterPhoneSignIn(UserCredential credential) {
    final isNewPhoneAccount = credential.additionalUserInfo?.isNewUser ?? false;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => isNewPhoneAccount
            ? const AccountProtectionScreen(
          source: AccountProtectionSource.phoneSignUp,
        )
            : const HomeShell(),
      ),
          (route) => false,
    );
  }

  Future<void> _completeWithCredential(PhoneAuthCredential credential) async {
    if (_completed) return;
    _completed = true;

    if (mounted) {
      setState(() => _isSending = true);
    }

    try {
      if (widget.mode == PhoneAuthMode.signIn) {
        final userCredential =
        await _authService.signInWithPhoneCredential(credential);

        if (!mounted) return;
        _goAfterPhoneSignIn(userCredential);
      } else {
        await _authService.linkPhoneCredential(credential);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      _completed = false;
      if (mounted) {
        _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendOtp() async {
    String phoneNumber;

    try {
      phoneNumber = _authService.normalizePakistanPhoneNumber(
        _phoneController.text,
      );
    } catch (error) {
      _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
      return;
    }

    setState(() => _isSending = true);

    try {
      await _authService.requestPhoneVerification(
        phoneNumber: phoneNumber,
        verificationCompleted: _completeWithCredential,
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => _isSending = false);
          _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
        },
        codeSent: (verificationId, resendToken) async {
          if (!mounted) return;
          setState(() => _isSending = false);

          final linked = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => PhoneOtpScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
                resendToken: resendToken,
                mode: widget.mode,
              ),
            ),
          );

          if (!mounted) return;
          if (widget.mode == PhoneAuthMode.linkToCurrentAccount && linked == true) {
            Navigator.of(context).pop(true);
          }
        },
        codeAutoRetrievalTimeout: (_) {
          if (mounted) {
            setState(() => _isSending = false);
          }
        },
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isSending = false);
        _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
      }
    }
  }

  void _showMessage(String message, {AppNoticeType type = AppNoticeType.info}) {
    if (!mounted) return;
    AppNotice.show(context, message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final isLinking = widget.mode == PhoneAuthMode.linkToCurrentAccount;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(isLinking ? 'Add Mobile Number' : 'Continue with Mobile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 76,
                width: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isLinking
                    ? 'Verify your mobile number'
                    : 'Login with mobile number',
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                isLinking
                    ? 'After OTP verification, this number will be linked to your current Easy Home Control account.'
                    : 'Use your Pakistani mobile number. We will send a one-time verification code.',
                style: const TextStyle(
                  color: AppTheme.lightText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.phone_outlined),
                  prefixText: '+92  ',
                  hintText: '300 1234567',
                ),
                onSubmitted: (_) => _sendOtp(),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter 0300 1234567, 3001234567, or +923001234567.',
                style: TextStyle(color: AppTheme.lightText, fontSize: 12),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isSending ? null : _sendOtp,
                  child: _isSending
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    isLinking ? 'Send OTP to Verify' : 'Send OTP',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'We will send an SMS code to verify this mobile number. Standard SMS charges may apply for real numbers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.lightText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
