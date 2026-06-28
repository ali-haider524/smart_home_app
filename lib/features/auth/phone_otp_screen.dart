import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/app_notice.dart';
import '../../core/app_theme.dart';
import '../../services/auth_service.dart';
import '../home/home_shell.dart';
import 'account_protection_screen.dart';
import 'phone_auth_mode.dart';

class PhoneOtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;
  final int? resendToken;
  final PhoneAuthMode mode;

  const PhoneOtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
    required this.resendToken,
    required this.mode,
  });

  @override
  State<PhoneOtpScreen> createState() => _PhoneOtpScreenState();
}

class _PhoneOtpScreenState extends State<PhoneOtpScreen> {
  final _authService = AuthService();
  final _codeController = TextEditingController();

  late String _verificationId;
  int? _resendToken;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _resendToken = widget.resendToken;
  }

  @override
  void dispose() {
    _codeController.dispose();
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
      setState(() => _isVerifying = true);
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
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _showMessage('Enter the 6-digit OTP code.');
      return;
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: code,
    );

    await _completeWithCredential(credential);
  }

  Future<void> _resendCode() async {
    if (_isResending || _isVerifying) return;

    setState(() => _isResending = true);

    try {
      await _authService.requestPhoneVerification(
        phoneNumber: widget.phoneNumber,
        forceResendingToken: _resendToken,
        verificationCompleted: _completeWithCredential,
        verificationFailed: (error) {
          if (mounted) {
            _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _showMessage('A new OTP has been sent.', type: AppNoticeType.success);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (error) {
      if (mounted) {
        _showMessage(_authService.friendlyAuthError(error, scope: AuthErrorScope.phone));
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
        title: Text(isLinking ? 'Verify Mobile Number' : 'Verify OTP'),
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
                  Icons.sms_outlined,
                  color: AppTheme.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isLinking
                    ? 'Confirm your mobile number'
                    : 'Enter verification code',
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'We sent a 6-digit code to ${widget.phoneNumber}.',
                style: const TextStyle(
                  color: AppTheme.lightText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 8,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
                onSubmitted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyCode,
                  child: _isVerifying
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(
                    isLinking
                        ? 'Verify & Link Number'
                        : 'Verify & Continue',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isResending || _isVerifying ? null : _resendCode,
                child: Text(_isResending ? 'Sending new code...' : 'Resend OTP'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Never share your OTP code with anyone. Easy Home Control support will never ask for your code.',
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
