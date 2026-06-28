import 'package:firebase_auth/firebase_auth.dart';

enum AuthErrorScope { general, email, phone }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> login({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Please enter your email address.');
    }

    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in again before verifying your email.');
    }

    if (!hasEmailPasswordProvider(user) || (user.email?.trim().isEmpty ?? true)) {
      throw StateError('Add a recovery email before requesting verification.');
    }

    if (user.emailVerified) return;

    await user.sendEmailVerification();
  }

  Future<User?> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    await user.reload();
    return _auth.currentUser;
  }

  String normalizePakistanPhoneNumber(String value) {
    var digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.startsWith('0092')) {
      digits = digits.substring(2);
    }

    String result;
    if (digits.startsWith('92')) {
      result = '+$digits';
    } else if (digits.startsWith('0')) {
      result = '+92${digits.substring(1)}';
    } else {
      result = '+92$digits';
    }

    final pakistanMobile = RegExp(r'^\+923\d{9}$');
    if (!pakistanMobile.hasMatch(result)) {
      throw ArgumentError(
        'Enter a valid Pakistani mobile number, for example 0300 1234567.',
      );
    }

    return result;
  }

  Future<void> requestPhoneVerification({
    required String phoneNumber,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      forceResendingToken: forceResendingToken,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  Future<UserCredential> signInWithPhoneCredential(
      PhoneAuthCredential credential,
      ) {
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> linkPhoneCredential(
      PhoneAuthCredential credential,
      ) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again before linking a mobile number.');
    }

    return user.linkWithCredential(credential);
  }

  Future<UserCredential> linkEmailPassword({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again before adding a recovery email.');
    }

    final credential = EmailAuthProvider.credential(
      email: email.trim(),
      password: password,
    );

    return user.linkWithCredential(credential);
  }

  bool userHasProvider(User? user, String providerId) {
    if (user == null) return false;
    return user.providerData.any((provider) => provider.providerId == providerId);
  }

  bool hasEmailPasswordProvider(User? user) => userHasProvider(user, 'password');

  bool hasPhoneProvider(User? user) => userHasProvider(user, 'phone');

  String friendlyAuthError(
      Object error, {
        AuthErrorScope scope = AuthErrorScope.general,
      }) {
    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Please check the information and try again.';
    }

    if (error is StateError) {
      return error.message;
    }

    if (error is! FirebaseAuthException) {
      return 'Something went wrong. Please try again.';
    }

    switch (error.code) {
      case 'invalid-phone-number':
        return 'Enter a valid Pakistani mobile number.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a while before requesting another OTP.';
      case 'quota-exceeded':
        return 'SMS verification is temporarily unavailable. Please try again later.';
      case 'session-expired':
        return 'This OTP has expired. Request a new code.';
      case 'invalid-verification-code':
        return 'The OTP is incorrect. Please check the code and try again.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return _alreadyRegisteredMessage(scope);
      case 'provider-already-linked':
        return _alreadyLinkedMessage(scope);
      case 'email-already-in-use':
        return 'This email is already registered with another account. Please sign in with that email or use a different email.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return scope == AuthErrorScope.phone
            ? 'This mobile verification could not be completed. Request a new OTP and try again.'
            : 'Email or password is incorrect.';
      case 'requires-recent-login':
        return 'Please sign in again before changing account security settings.';
      case 'network-request-failed':
        return 'Internet connection failed. Please try again.';
      case 'operation-not-allowed':
        return 'This sign-in option is not enabled yet. Please contact support.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  String _alreadyRegisteredMessage(AuthErrorScope scope) {
    if (scope == AuthErrorScope.phone) {
      return 'This mobile number is already registered with another account. Sign in with that number or use a different mobile number.';
    }

    if (scope == AuthErrorScope.email) {
      return 'This email is already registered with another account. Sign in with that email or use a different email.';
    }

    return 'This sign-in option is already registered with another account.';
  }

  String _alreadyLinkedMessage(AuthErrorScope scope) {
    if (scope == AuthErrorScope.phone) {
      return 'This mobile number is already linked to your account.';
    }

    if (scope == AuthErrorScope.email) {
      return 'This email is already linked to your account.';
    }

    return 'This sign-in option is already linked to your account.';
  }

  Future<void> logout() => _auth.signOut();
}
