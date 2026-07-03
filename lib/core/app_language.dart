import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

enum AppLanguage { english, urdu }

extension AppLanguageValue on AppLanguage {
  Locale get locale => switch (this) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.urdu => const Locale('ur'),
  };

  TextDirection get textDirection => switch (this) {
    AppLanguage.english => TextDirection.ltr,
    AppLanguage.urdu => TextDirection.rtl,
  };

  String get databaseValue => switch (this) {
    AppLanguage.english => 'en',
    AppLanguage.urdu => 'ur',
  };

  static AppLanguage fromDatabaseValue(Object? value) {
    return value?.toString().toLowerCase() == 'ur'
        ? AppLanguage.urdu
        : AppLanguage.english;
  }
}

/// Lightweight in-app language controller.
///
/// The selected language is stored only under the signed-in user's own
/// `/users/{uid}/preferences/appLanguage` node. It does not affect device
/// data, pairing, relay control, timers, schedules, or ESP firmware.
class AppLanguageController extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DatabaseEvent>? _preferenceSubscription;
  bool _started = false;

  AppLanguage get language => _language;
  Locale get locale => _language.locale;
  TextDirection get textDirection => _language.textDirection;
  bool get isUrdu => _language == AppLanguage.urdu;

  void start() {
    if (_started) return;
    _started = true;

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      _handleAuthChanged,
      onError: (_) {},
    );
  }

  void _handleAuthChanged(User? user) {
    _preferenceSubscription?.cancel();
    _preferenceSubscription = null;

    if (user == null) {
      _setLanguage(AppLanguage.english);
      return;
    }

    final ref = FirebaseDatabase.instance
        .ref('users/${user.uid}/preferences/appLanguage');

    _preferenceSubscription = ref.onValue.listen(
          (event) {
        _setLanguage(AppLanguageValue.fromDatabaseValue(event.snapshot.value));
      },
      onError: (_) {
        // Keep the last chosen language if the preference cannot be read.
      },
    );
  }

  Future<bool> setLanguage(AppLanguage language) async {
    _setLanguage(language);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    try {
      await FirebaseDatabase.instance
          .ref('users/${user.uid}/preferences/appLanguage')
          .set(language.databaseValue);
      return true;
    } catch (_) {
      // The language is still applied for the open app session. Returning false
      // lets Settings give the user a non-blocking persistence warning.
      return false;
    }
  }

  void _setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _preferenceSubscription?.cancel();
    super.dispose();
  }
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope =
    context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope != null, 'AppLanguageScope is missing above this context.');
    return scope!.notifier!;
  }
}

class EhcLocalizations {
  final AppLanguage language;

  const EhcLocalizations(this.language);

  bool get isUrdu => language == AppLanguage.urdu;

  static EhcLocalizations of(BuildContext context) {
    return EhcLocalizations(AppLanguageScope.controllerOf(context).language);
  }

  String text(String english) {
    if (!isUrdu) return english;
    return _urdu[english] ?? _extraUrdu[english] ?? english;
  }

  String devices(int count) {
    if (isUrdu) return '$count ڈیوائس${count == 1 ? '' : 'ز'}';
    return '$count device${count == 1 ? '' : 's'}';
  }

  String activeNow(int count) {
    if (isUrdu) return '$count ڈیوائس${count == 1 ? '' : 'ز'} ابھی فعال ہیں۔';
    return '$count device${count == 1 ? '' : 's'} active right now.';
  }

  String readyToControl(int count) {
    if (isUrdu) return '$count ڈیوائس${count == 1 ? '' : 'ز'} کنٹرول کے لیے تیار ہیں۔';
    return '$count device${count == 1 ? '' : 's'} ready to control.';
  }

  String automations(int count) {
    if (isUrdu) return '$count آٹومیشن${count == 1 ? '' : 'ز'}';
    return '$count automation${count == 1 ? '' : 's'}';
  }

  String scheduleCount(int count) {
    if (isUrdu) return '$count فعال شیڈول';
    return '$count schedule${count == 1 ? '' : 's'}';
  }

  static const Map<String, String> _urdu = {
    // Navigation and general.
    'Home': 'ہوم',
    'Add': 'شامل کریں',
    'Auto': 'آٹومیشن',
    'Settings': 'ترتیبات',
    'Language': 'زبان',
    'App language': 'ایپ کی زبان',
    'Choose the language used across your Easy Home Control app.':
    'اپنی ایزی ہوم کنٹرول ایپ کے لیے زبان منتخب کریں۔',
    'English': 'English',
    'Urdu': 'اردو',
    'Selected': 'منتخب',
    'Save': 'محفوظ کریں',
    'Cancel': 'منسوخ کریں',
    'Done': 'مکمل',
    'Close': 'بند کریں',
    'Retry': 'دوبارہ کوشش کریں',
    'Loading...': 'لوڈ ہو رہا ہے...',

    // Dashboard.
    'Good to see you': 'خوش آمدید',
    'Your smart home, at a glance.': 'آپ کا سمارٹ ہوم، ایک نظر میں۔',
    'Set up your first smart switch to get started.':
    'شروع کرنے کے لیے اپنا پہلا سمارٹ سوئچ سیٹ اپ کریں۔',
    'Your devices are offline. Check their power and Wi-Fi.':
    'آپ کی ڈیوائسز آف لائن ہیں۔ پاور اور وائی فائی چیک کریں۔',
    'Could not load devices': 'ڈیوائسز لوڈ نہیں ہو سکیں',
    'Check your internet connection, then return to this screen.':
    'انٹرنیٹ کنکشن چیک کریں، پھر اس اسکرین پر واپس آئیں۔',
    'Home status': 'ہوم اسٹیٹس',
    'Everything is ready': 'سب کچھ تیار ہے',
    'Add your first device': 'اپنی پہلی ڈیوائس شامل کریں',
    'Online': 'آن لائن',
    'Active now': 'ابھی فعال',
    'Timers': 'ٹائمرز',
    'Automations': 'آٹومیشنز',
    'Your devices': 'آپ کی ڈیوائسز',
    'Add device': 'ڈیوائس شامل کریں',
    'No device linked yet': 'ابھی کوئی ڈیوائس لنک نہیں ہے',
    'Add your Easy Home Control device using its Device ID and claim code.':
    'ڈیوائس آئی ڈی اور کلیم کوڈ کے ذریعے اپنی ایزی ہوم کنٹرول ڈیوائس شامل کریں۔',
    'Add another device': 'ایک اور ڈیوائس شامل کریں',
    'Timer active': 'ٹائمر فعال ہے',
    'ON': 'آن',
    'OFF': 'آف',
    'Offline': 'آف لائن',

    // Device control.
    'Quick timer': 'فوری ٹائمر',
    'Last seen': 'آخری بار دیکھا گیا',
    'Model': 'ماڈل',
    'Start timer': 'ٹائمر شروع کریں',
    'Cancel timer': 'ٹائمر منسوخ کریں',
    'Manage schedules': 'شیڈولز مینیج کریں',
    'Device details': 'ڈیوائس کی تفصیلات',
    'Device ID': 'ڈیوائس آئی ڈی',
    'Firmware': 'فرم ویئر',
    'Channels': 'چینلز',
    'Add Schedule': 'شیڈول شامل کریں',
    'Save Schedules': 'شیڈولز محفوظ کریں',
    'Add First Schedule': 'پہلا شیڈول شامل کریں',
    'Sending ON command...': 'آن کمانڈ بھیجی جا رہی ہے...',
    'Sending OFF command...': 'آف کمانڈ بھیجی جا رہی ہے...',
    'Switch turned ON.': 'سوئچ آن ہو گیا۔',
    'Switch turned OFF.': 'سوئچ آف ہو گیا۔',
    'Device did not confirm the command. Check its connection and try again.':
    'ڈیوائس نے کمانڈ کی تصدیق نہیں کی۔ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',

    // Automation hub.
    'Automation': 'آٹومیشن',
    'Keep your home running on time.': 'اپنے گھر کو وقت کے مطابق چلائیں۔',
    'Running timers': 'چلتے ہوئے ٹائمرز',
    'No timer is running': 'کوئی ٹائمر نہیں چل رہا',
    'Weekly schedules': 'ہفتہ وار شیڈولز',
    'No weekly schedule yet': 'ابھی کوئی ہفتہ وار شیڈول نہیں ہے',
    'No devices linked yet': 'ابھی کوئی ڈیوائس لنک نہیں ہے',
    'Could not load automations': 'آٹومیشنز لوڈ نہیں ہو سکیں',
    'Schedules': 'شیڈولز',

    // Add Device hub.
    'Set up a new Easy Home Control smart switch.':
    'نیا ایزی ہوم کنٹرول سمارٹ سوئچ سیٹ اپ کریں۔',
    'Before you begin': 'شروع کرنے سے پہلے',
    'Keep these three things ready for a smooth setup.':
    'آسان سیٹ اپ کے لیے یہ تین چیزیں تیار رکھیں۔',
    'How setup works': 'سیٹ اپ کیسے کام کرتا ہے',
    'Pair first, then connect the switch to your home WiFi.':
    'پہلے پیئر کریں، پھر سوئچ کو اپنے ہوم وائی فائی سے جوڑیں۔',
    'Pair a new device': 'نئی ڈیوائس پیئر کریں',
    'Your device remains fully under your account after pairing.':
    'پیئرنگ کے بعد ڈیوائس مکمل طور پر آپ کے اکاؤنٹ میں رہے گی۔',
    'Ready to connect a switch?': 'سوئچ کنیکٹ کرنے کے لیے تیار ہیں؟',
    'It only takes a few guided steps.': 'اس میں صرف چند آسان مراحل لگیں گے۔',
    'Start pairing': 'پیئرنگ شروع کریں',
    'Device powered on': 'ڈیوائس آن ہے',
    'Plug in or power the smart switch before setup.':
    'سیٹ اپ سے پہلے سمارٹ سوئچ کو پاور دیں۔',
    'Product label nearby': 'پروڈکٹ لیبل پاس رکھیں',
    'You will need its Device ID and claim code.':
    'آپ کو اس کی ڈیوائس آئی ڈی اور کلیم کوڈ کی ضرورت ہوگی۔',
    'Home WiFi details': 'ہوم وائی فائی کی تفصیلات',
    'Keep your WiFi name and password ready for the next step.':
    'اگلے مرحلے کے لیے وائی فائی نام اور پاس ورڈ تیار رکھیں۔',
    'Pair the device': 'ڈیوائس پیئر کریں',
    'Join the setup hotspot': 'سیٹ اپ ہاٹ اسپاٹ سے جڑیں',
    'Connect home WiFi': 'ہوم وائی فائی سے جڑیں',
    'Already added this device? Open it from Home, then use Device Settings to rename it or change WiFi.':
    'کیا یہ ڈیوائس پہلے شامل ہے؟ ہوم سے کھولیں، پھر ڈیوائس سیٹنگز سے نام یا وائی فائی تبدیل کریں۔',

    // Settings.
    'Account security': 'اکاؤنٹ سیکیورٹی',
    'My home': 'میرا گھر',
    'Add a smart switch': 'سمارٹ سوئچ شامل کریں',
    'Pair another Easy Home Control device to this account.':
    'اس اکاؤنٹ کے ساتھ ایک اور ایزی ہوم کنٹرول ڈیوائس پیئر کریں۔',
    'Archived devices': 'آرکائیو ڈیوائسز',
    'Restore devices you removed from your dashboard.':
    'ڈیش بورڈ سے ہٹائی گئی ڈیوائسز بحال کریں۔',
    'Help & support': 'مدد اور سپورٹ',
    'Support centre': 'سپورٹ سینٹر',
    'Setup help, WiFi troubleshooting, account help and support reference.':
    'سیٹ اپ مدد، وائی فائی مسئلے کا حل، اکاؤنٹ مدد اور سپورٹ ریفرنس۔',
    'About Easy Home Control': 'ایزی ہوم کنٹرول کے بارے میں',
    'Learn what this app manages for your connected home.':
    'جانیں کہ یہ ایپ آپ کے کنیکٹڈ ہوم کے لیے کیا مینیج کرتی ہے۔',
    'Session': 'سیشن',
    'Sign out': 'سائن آؤٹ',
    'Sign out?': 'سائن آؤٹ کریں؟',
    'Sign Out': 'سائن آؤٹ',
    'Add a mobile number': 'موبائل نمبر شامل کریں',
    'Add a recovery email': 'ریکوری ای میل شامل کریں',
    'Verify your recovery email': 'اپنی ریکوری ای میل کی تصدیق کریں',

    // Support.
    'Help & Support': 'مدد اور سپورٹ',
    'Quick help': 'فوری مدد',
    'Contact preparation': 'رابطے کی تیاری',
    'Copy support reference': 'سپورٹ ریفرنس کاپی کریں',
    'Prepare a support message': 'سپورٹ میسج تیار کریں',
    'Device is offline': 'ڈیوائس آف لائن ہے',
    'Connect or change WiFi': 'وائی فائی کنیکٹ یا تبدیل کریں',
    'Timer or schedule help': 'ٹائمر یا شیڈول مدد',
    'Account access help': 'اکاؤنٹ رسائی مدد',
    'Copy support message': 'سپورٹ میسج کاپی کریں',
    'Got it': 'سمجھ گیا',
    'We are here to help': 'ہم مدد کے لیے موجود ہیں',
  };

  static const Map<String, String> _extraUrdu = {
    // Phase 7A simplified Home screen.
    'My devices': 'میری ڈیوائسز',
    'Your home': 'آپ کا گھر',
    'Check power and Wi-Fi': 'پاور اور وائی فائی چیک کریں',
    'online now': 'ابھی آن لائن',
    'Power is on': 'پاور آن ہے',
    'Ready to control': 'کنٹرول کے لیے تیار',
    'No devices yet': 'ابھی کوئی ڈیوائس نہیں ہے',
    'Add a device': 'ڈیوائس شامل کریں',
    'Add your first smart switch to get started.':
    'شروع کرنے کے لیے اپنا پہلا سمارٹ سوئچ شامل کریں۔',
    'Good morning': 'صبح بخیر',
    'Good afternoon': 'دوپہر بخیر',
    'Good evening': 'شام بخیر',
    'Start with your first device': 'اپنی پہلی ڈیوائس سے شروع کریں',
    'Your home is connected': 'آپ کا گھر کنیکٹ ہے',
    'Waiting for your devices': 'آپ کی ڈیوائسز کا انتظار ہے',
    'Add an Easy Home Control switch and connect it to Wi-Fi.':
    'ایزی ہوم کنٹرول سوئچ شامل کریں اور اسے وائی فائی سے جوڑیں۔',
    'devices online now': 'ڈیوائسز ابھی آن لائن ہیں',
    'Restore power or Wi-Fi, then the device will check in again.':
    'پاور یا وائی فائی بحال کریں، پھر ڈیوائس دوبارہ کنیکٹ ہو جائے گی۔',
    'linked to your account': 'آپ کے اکاؤنٹ سے لنک ہیں',
    'Connected · Power is on': 'کنیکٹڈ · پاور آن ہے',
    'Connected · Ready to control': 'کنیکٹڈ · کنٹرول کے لیے تیار ہے',
    'Start setup': 'سیٹ اپ شروع کریں',
    'Start by entering the Device ID and claim code printed on your product label. You will connect to the EHC setup hotspot only after pairing succeeds.':
    'اپنے پروڈکٹ لیبل پر موجود ڈیوائس آئی ڈی اور کلیم کوڈ درج کریں۔ پیئرنگ مکمل ہونے کے بعد ہی ای ایچ سی سیٹ اپ ہاٹ اسپاٹ سے کنیکٹ کریں۔',
    'Enter the Device ID, claim code, and a name for your switch.':
    'ڈیوائس آئی ڈی، کلیم کوڈ اور اپنے سوئچ کا نام درج کریں۔',
    'Connect your phone to EHC_SETUP_A7F92 when the app asks.':
    'جب ایپ کہے تو اپنے فون کو EHC_SETUP_A7F92 سے کنیکٹ کریں۔',
    'The switch tests your WiFi details, then appears online in Home.':
    'سوئچ آپ کی وائی فائی تفصیلات چیک کرے گا، پھر ہوم میں آن لائن ظاہر ہوگا۔',
    'Set up your routine': 'اپنا روٹین سیٹ اپ کریں',
    'Your home is on schedule': 'آپ کے گھر کا شیڈول تیار ہے',
    'Timer running now': 'ٹائمر ابھی چل رہا ہے',
    'Weekly routine ready': 'ہفتہ وار روٹین تیار ہے',
    'Timers and schedules will appear here after you add a device.':
    'ڈیوائس شامل کرنے کے بعد ٹائمرز اور شیڈولز یہاں نظر آئیں گے۔',
    'Use a device control screen to create your first timer or schedule.':
    'اپنا پہلا ٹائمر یا شیڈول بنانے کے لیے ڈیوائس کنٹرول اسکرین استعمال کریں۔',
    'timer': 'ٹائمر',
    'schedule': 'شیڈول',
    'across your linked devices': 'آپ کی لنک ڈیوائسز پر',
    'No routine is active yet': 'ابھی کوئی روٹین فعال نہیں ہے',
    'Your timer is keeping watch': 'آپ کا ٹائمر فعال ہے',
    'Your weekly schedule is ready': 'آپ کا ہفتہ وار شیڈول تیار ہے',
    'Timers switch a device off once. Schedules repeat each week.':
    'ٹائمر ڈیوائس کو ایک بار آف کرتا ہے۔ شیڈول ہر ہفتے دہرائے جاتے ہیں۔',
    'online devices synced': 'آن لائن ڈیوائسز کے ساتھ سنک ہیں',
    'Your automations are saved. Devices will use them when they reconnect.':
    'آپ کی آٹومیشنز محفوظ ہیں۔ ڈیوائسز دوبارہ کنیکٹ ہونے پر انہیں استعمال کریں گی۔',
    'None running': 'کوئی نہیں چل رہا',
    'Running now': 'ابھی چل رہا ہے',
    'None enabled': 'کوئی فعال نہیں',
    'Enabled': 'فعال',
    'Add a smart switch from the Home tab, then its timers and schedules will appear here.':
    'ہوم ٹیب سے سمارٹ سوئچ شامل کریں، پھر اس کے ٹائمرز اور شیڈولز یہاں ظاہر ہوں گے۔',
    'No switch-off timers are running': 'کوئی سوئچ آف ٹائمر نہیں چل رہا',
    'active now': 'ابھی فعال',
    'Start a timer from a device control screen whenever you need one.':
    'جب ضرورت ہو ڈیوائس کنٹرول اسکرین سے ٹائمر شروع کریں۔',
    'No schedules are enabled': 'کوئی شیڈول فعال نہیں ہے',
    'Open a device to set when its switch should turn on and off.':
    'سوئچ کے آن اور آف ہونے کا وقت سیٹ کرنے کے لیے ڈیوائس کھولیں۔',
    'Device did not confirm the command. Check its connection and try again.':
    'ڈیوائس نے کمانڈ کی تصدیق نہیں کی۔ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'Could not send the command. Check your internet connection and try again.':
    'کمانڈ نہیں بھیجی جا سکی۔ انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'Please select or enter timer duration': 'ٹائمر کی مدت منتخب یا درج کریں',
    'Maximum timer allowed is 24 hours': 'زیادہ سے زیادہ ٹائمر 24 گھنٹے کا ہو سکتا ہے',
    'Timer started': 'ٹائمر شروع ہو گیا',
    'Timer cancelled': 'ٹائمر منسوخ ہو گیا',
    'All schedules removed': 'تمام شیڈولز ہٹا دیے گئے',
    'saved': 'محفوظ ہو گئے',
    'Could not save schedules. Please try again.':
    'شیڈولز محفوظ نہیں ہو سکے۔ دوبارہ کوشش کریں۔',
    'Smart switch control': 'سمارٹ سوئچ کنٹرول',
    'Device settings': 'ڈیوائس سیٹنگز',
    'Timer currently running': 'ٹائمر اس وقت چل رہا ہے',
    'Set a one-time switch-off timer': 'ایک بار سوئچ آف کرنے کا ٹائمر سیٹ کریں',
    'Weekly schedules run on the device': 'ہفتہ وار شیڈولز ڈیوائس پر چلتے ہیں',
    'Manage': 'مینیج کریں',
    'Device is offline': 'ڈیوائس آف لائن ہے',
    'Sending': 'بھیجا جا رہا ہے',
    'command': 'کمانڈ',
    'Power is ON': 'پاور آن ہے',
    'Power is OFF': 'پاور آف ہے',
    'Waiting for the switch to confirm the relay state.':
    'سوئچ کے ریلے اسٹیٹ کی تصدیق کا انتظار ہے۔',
    'Tap the power button to switch it off.': 'سوئچ آف کرنے کے لیے پاور بٹن دبائیں۔',
    'Tap the power button to switch it on.': 'سوئچ آن کرنے کے لیے پاور بٹن دبائیں۔',
    'ONLINE': 'آن لائن',
    'OFFLINE': 'آف لائن',
    'Channel': 'چینل',
    'Turn switch off': 'سوئچ آف کریں',
    'Turn switch on': 'سوئچ آن کریں',
    'Choose a duration': 'مدت منتخب کریں',
    'Or enter custom minutes': 'یا اپنی مرضی کے منٹ درج کریں',
    'Example: 15, 45, 120': 'مثال: 15، 45، 120',
    'No schedules yet': 'ابھی کوئی شیڈول نہیں ہے',
    'Automate power for selected days and times.':
    'منتخب دنوں اور اوقات کے لیے پاور آٹومیٹ کریں۔',
    'Language changed for this session. It will be saved when your connection is available.':
    'زبان اس سیشن کے لیے تبدیل کر دی گئی ہے۔ کنکشن دستیاب ہونے پر یہ محفوظ ہو جائے گی۔',
    'Account, devices and support in one place.':
    'اکاؤنٹ، ڈیوائسز اور سپورٹ ایک ہی جگہ۔',
    'Check power, WiFi and the last-seen time.': 'پاور، وائی فائی اور آخری بار دیکھا گیا وقت چیک کریں۔',
    'Use the tested setup hotspot flow.': 'آزمودہ سیٹ اپ ہاٹ اسپاٹ طریقہ استعمال کریں۔',
    'Timers run once; schedules repeat weekly.': 'ٹائمر ایک بار چلتے ہیں؛ شیڈول ہر ہفتے دہرائے جاتے ہیں۔',
    'Use linked email or verified mobile.': 'لنک شدہ ای میل یا تصدیق شدہ موبائل استعمال کریں۔',
    'Open a topic for simple steps before contacting support.':
    'سپورٹ سے رابطے سے پہلے آسان مراحل کے لیے ایک موضوع کھولیں۔',
    'Create a clear reference for official customer support.':
    'آفیشل کسٹمر سپورٹ کے لیے واضح ریفرنس تیار کریں۔',
    'Copies your account reference for faster support verification.':
    'تیز سپورٹ تصدیق کے لیے آپ کا اکاؤنٹ ریفرنس کاپی کرتا ہے۔',
    'Describe the issue and copy a ready-to-send support message.':
    'مسئلہ بیان کریں اور بھیجنے کے لیے تیار سپورٹ میسج کاپی کریں۔',
    'Find practical setup guidance, then prepare a clear message for official Easy Home Control support.':
    'سیٹ اپ کی عملی رہنمائی حاصل کریں، پھر آفیشل ایزی ہوم کنٹرول سپورٹ کے لیے واضح میسج تیار کریں۔',
  };

}

extension EhcLocalizationContext on BuildContext {
  AppLanguageController get languageController =>
      AppLanguageScope.controllerOf(this);

  EhcLocalizations get l10n => EhcLocalizations.of(this);

  String tr(String english) => l10n.text(english);
}
