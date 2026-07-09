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

    // Stage 4 translation cleanup for already-localized app text.
    'Set up more automation': 'مزید آٹومیشن سیٹ اپ کریں',
    'Choose a device to add another timer or weekly schedule.': 'ایک اور ٹائمر یا ہفتہ وار شیڈول شامل کرنے کے لیے ڈیوائس منتخب کریں۔',
    'Choose device': 'ڈیوائس منتخب کریں',
    'Set up your home': 'اپنا گھر سیٹ اپ کریں',
    'Set up a new switch, join shared access, or reconnect a registered switch after Wi-Fi changes.': 'نیا سوئچ سیٹ اپ کریں، شیئرڈ ایکسس جوائن کریں، یا وائی فائی تبدیلی کے بعد رجسٹرڈ سوئچ دوبارہ کنیکٹ کریں۔',
    'Choose an option': 'ایک آپشن منتخب کریں',
    'Before new setup': 'نئے سیٹ اپ سے پہلے',
    'The switch did not confirm this command. Check its connection and current state before trying again.': 'سوئچ نے اس کمانڈ کی تصدیق نہیں کی۔ دوبارہ کوشش سے پہلے اس کا کنکشن اور موجودہ حالت چیک کریں۔',
    'Power': 'پاور',
    'Could not start timer. Please try again.': 'ٹائمر شروع نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'Could not cancel timer. Please try again.': 'ٹائمر منسوخ نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'Waiting for device confirmation': 'ڈیوائس کی تصدیق کا انتظار ہے',
    'Tap the button to turn it off': 'اسے آف کرنے کے لیے بٹن دبائیں',
    'Tap the button to turn it on': 'اسے آن کرنے کے لیے بٹن دبائیں',
    'Ready': 'تیار',
    'Manage the devices already connected to your account.': 'اپنے اکاؤنٹ سے پہلے سے منسلک ڈیوائسز مینیج کریں۔',
    'Device management': 'ڈیوائس مینجمنٹ',
    'Open a device, manage shared access, Wi-Fi, names and device settings.': 'ڈیوائس کھولیں، شیئرڈ ایکسس، وائی فائی، نام اور ڈیوائس سیٹنگز مینیج کریں۔',
    'Device Wi-Fi & recovery': 'ڈیوائس وائی فائی اور ریکوری',
    'Change home Wi-Fi or reconnect a switch after router changes.': 'ہوم وائی فائی تبدیل کریں یا راؤٹر تبدیلی کے بعد سوئچ دوبارہ کنیکٹ کریں۔',
    'Add or join a smart switch': 'سمارٹ سوئچ شامل کریں یا جوائن کریں',
    'Set up a new switch or enter a share code from its owner.': 'نیا سوئچ سیٹ اپ کریں یا مالک کی طرف سے شیئر کوڈ درج کریں۔',
    'Find setup guidance and prepare a clear support request.': 'سیٹ اپ رہنمائی دیکھیں اور واضح سپورٹ درخواست تیار کریں۔',
    'Signing out...': 'سائن آؤٹ ہو رہا ہے...',
    'Device offline': 'ڈیوائس آف لائن ہے',
    'Timer & schedules': 'ٹائمر اور شیڈولز',
    'Energy estimate': 'انرجی اندازہ',
    'Shared device': 'شیئرڈ ڈیوائس',
    'Account access': 'اکاؤنٹ رسائی',

    // Stage 5C App Settings Urdu cleanup.
    'You can sign in again using email sign-in or your verified mobile number. Your devices, schedules and WiFi settings will not be changed.': 'آپ دوبارہ ای میل سائن اِن یا اپنے تصدیق شدہ موبائل نمبر سے سائن اِن کر سکتے ہیں۔ آپ کی ڈیوائسز، شیڈولز اور وائی فائی سیٹنگز تبدیل نہیں ہوں گی۔',
    'Could not sign out. Please try again.': 'سائن آؤٹ نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'Mobile number verified and added to your account.': 'موبائل نمبر تصدیق ہو کر آپ کے اکاؤنٹ میں شامل ہو گیا۔',
    'Recovery email added. Verify it from your inbox.': 'ریکوری ای میل شامل ہو گئی۔ اپنے اِن باکس سے اسے تصدیق کریں۔',
    'Verification email sent. Check inbox and spam folder.': 'تصدیقی ای میل بھیج دی گئی ہے۔ اِن باکس اور اسپیم فولڈر چیک کریں۔',
    'Email verified successfully.': 'ای میل کامیابی سے تصدیق ہو گئی۔',
    'Email is still pending verification. Open the link in your email, then try again.': 'ای میل کی تصدیق ابھی باقی ہے۔ اپنی ای میل میں لنک کھولیں، پھر دوبارہ کوشش کریں۔',
    'Appearance changed for this session. It will be saved when your connection is available.': 'ظاہری تھیم اس سیشن کے لیے تبدیل ہو گئی ہے۔ کنکشن دستیاب ہونے پر یہ محفوظ ہو جائے گی۔',
    'Control your connected switches, timers and weekly schedules from one secure account.\n\nThis app is currently being refined for its commercial release.': 'اپنے کنیکٹڈ سوئچز، ٹائمرز اور ہفتہ وار شیڈولز ایک محفوظ اکاؤنٹ سے کنٹرول کریں۔\n\nیہ ایپ کمرشل ریلیز کے لیے بہتر کی جا رہی ہے۔',
    'No verified sign-in method': 'کوئی تصدیق شدہ سائن اِن طریقہ نہیں',
    'Easy Home User': 'ایزی ہوم صارف',
    'Use mobile verification as an extra way to sign in.': 'سائن اِن کے اضافی طریقے کے طور پر موبائل تصدیق استعمال کریں۔',
    'Keep an email ready for account recovery.': 'اکاؤنٹ ریکوری کے لیے ای میل تیار رکھیں۔',
    'Open the verification link sent to': 'تصدیقی لنک کھولیں جو بھیجا گیا ہے',
    'Your sign-in and recovery options are ready.': 'آپ کے سائن اِن اور ریکوری آپشنز تیار ہیں۔',
    'Complete the items below to protect your account.': 'اپنے اکاؤنٹ کی حفاظت کے لیے نیچے دی گئی چیزیں مکمل کریں۔',
    'Mobile number verified': 'موبائل نمبر تصدیق شدہ ہے',
    'Add mobile number': 'موبائل نمبر شامل کریں',
    'Add mobile verification for easier sign-in.': 'آسان سائن اِن کے لیے موبائل تصدیق شامل کریں۔',
    'Recovery email verified': 'ریکوری ای میل تصدیق شدہ ہے',
    'Verify recovery email': 'ریکوری ای میل تصدیق کریں',
    'Add an email for sign-in and password recovery.': 'سائن اِن اور پاس ورڈ ریکوری کے لیے ای میل شامل کریں۔',
    'Verification pending': 'تصدیق باقی ہے',
    'Sending...': 'بھیجا جا رہا ہے...',
    'Resend': 'دوبارہ بھیجیں',
    'Checking verification...': 'تصدیق چیک ہو رہی ہے...',
    'I have verified my email': 'میں نے اپنی ای میل تصدیق کر لی ہے',
    'Appearance': 'ظاہری تھیم',
    'Choose a comfortable light or dark visual theme.': 'آسان روشنی یا ڈارک تھیم منتخب کریں۔',
    'Account protected': 'اکاؤنٹ محفوظ ہے',
    'Protection needs attention': 'حفاظت پر توجہ چاہیے',
    'Review': 'جائزہ لیں',
    'Light': 'لائٹ',
    'Clean and bright': 'صاف اور روشن',
    'Dark': 'ڈارک',
    'Easy at night': 'رات میں آسان',

    // Stage 5A Device Control screen text.
    'Add a recurring weekly schedule. It keeps working locally after WiFi disconnects.': 'ہفتہ وار دہرایا جانے والا شیڈول شامل کریں۔ وائی فائی بند ہونے کے بعد بھی یہ مقامی طور پر کام کرتا رہے گا۔',
    'Add appliance watts to see hourly and timer estimates.': 'فی گھنٹہ اور ٹائمر کا اندازہ دیکھنے کے لیے اپلائنس کے واٹس شامل کریں۔',
    'All options': 'تمام آپشنز',
    'Appliance': 'اپلائنس',
    'Approximation from wattage and time': 'واٹس اور وقت کی بنیاد پر اندازہ',
    'Choose ON/OFF time and repeat days': 'آن/آف وقت اور دہرائے جانے والے دن منتخب کریں',
    'Cost not set': 'لاگت سیٹ نہیں ہے',
    'Custom duration': 'اپنی مرضی کی مدت',
    'Delete schedule': 'شیڈول ڈیلیٹ کریں',
    'Edit estimate': 'اندازہ ایڈٹ کریں',
    'Estimate only': 'صرف اندازہ',
    'Estimated energy': 'اندازاً انرجی',
    'Example: 45 or 120': 'مثال: 45 یا 120',
    'Maximum 6 schedules are allowed.': 'زیادہ سے زیادہ 6 شیڈولز کی اجازت ہے۔',
    'Maximum timer allowed is 24 hours.': 'زیادہ سے زیادہ ٹائمر 24 گھنٹے کا ہو سکتا ہے۔',
    'More': 'مزید',
    'More hour choices': 'مزید گھنٹوں کے آپشنز',
    'No active schedules set by the owner': 'مالک نے کوئی فعال شیڈول سیٹ نہیں کیا',
    'ON and OFF time cannot be the same.': 'آن اور آف وقت ایک جیسا نہیں ہو سکتا۔',
    'Only the device owner can change schedules.': 'صرف ڈیوائس مالک شیڈول تبدیل کر سکتا ہے۔',
    'Owner only': 'صرف مالک',
    'Per hour': 'فی گھنٹہ',
    'Power rating': 'پاور ریٹنگ',
    'Quick choices': 'فوری انتخاب',
    'Repeat on': 'ان دنوں دہرائیں',
    'Replace timer': 'ٹائمر بدلیں',
    'Set automatic ON/OFF times': 'خودکار آن/آف اوقات سیٹ کریں',
    'Set timer': 'ٹائمر سیٹ کریں',
    'Set up': 'سیٹ اپ',
    'The switch will turn off automatically.': 'سوئچ خودکار طور پر آف ہو جائے گا۔',
    'This will replace the current timer with': 'یہ موجودہ ٹائمر کو اس سے بدل دے گا',
    'Timer is active': 'ٹائمر فعال ہے',
    'Timer running': 'ٹائمر چل رہا ہے',
    'Timer total': 'ٹائمر کل',
    'Turn the switch off automatically after': 'اس وقت کے بعد سوئچ خودکار طور پر آف کریں',
    'Use custom minutes': 'اپنی مرضی کے منٹ استعمال کریں',
    'Weekly Schedules': 'ہفتہ وار شیڈولز',
    'channel': 'چینل',
    'channels': 'چینلز',
    'hour': 'گھنٹہ',
    'minutes': 'منٹ',
    'select at least one day.': 'کم از کم ایک دن منتخب کریں۔',
    'Sun': 'اتوار',
    'Mon': 'پیر',
    'Tue': 'منگل',
    'Wed': 'بدھ',
    'Thu': 'جمعرات',
    'Fri': 'جمعہ',
    'Sat': 'ہفتہ',

    // Stage 5B Device Settings screen text.
    'Appliance watts and optional electricity price': 'اپلائنس کے واٹس اور بجلی کی اختیاری قیمت',
    'Archive device': 'ڈیوائس آرکائیو کریں',
    'Change home Wi-Fi or open the setup hotspot. Use the password on the device label or box.': 'ہوم وائی فائی تبدیل کریں یا سیٹ اپ ہاٹ اسپاٹ کھولیں۔ ڈیوائس لیبل یا باکس پر دیا گیا پاس ورڈ استعمال کریں۔',
    'Change the name shown in your app': 'ایپ میں دکھایا جانے والا نام تبدیل کریں',
    'Checking status': 'اسٹیٹس چیک ہو رہا ہے',
    'Choose “Stay connected” if your phone says the hotspot has no internet.': 'اگر فون کہے کہ ہاٹ اسپاٹ پر انٹرنیٹ نہیں ہے تو “Stay connected” منتخب کریں۔',
    'Contacting your switch…': 'سوئچ سے رابطہ ہو رہا ہے...',
    'Controls': 'کنٹرولز',
    'Could not open Wi-Fi setup. Check the device connection and try again.': 'وائی فائی سیٹ اپ نہیں کھل سکا۔ ڈیوائس کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'Could not remove the device. Please try again.': 'ڈیوائس ہٹائی نہیں جا سکی۔ دوبارہ کوشش کریں۔',
    'Could not rename the device. Please try again.': 'ڈیوائس کا نام تبدیل نہیں ہو سکا۔ دوبارہ کوشش کریں۔',
    'Device information': 'ڈیوائس معلومات',
    'Device information will appear when': 'ڈیوائس معلومات تب نظر آئیں گی جب',
    'Device renamed': 'ڈیوائس کا نام تبدیل ہو گیا',
    'Do not press Change Wi-Fi again.': 'دوبارہ Change Wi-Fi نہ دبائیں۔',
    'e.g. Living Room Switch': 'مثال: لیونگ روم سوئچ',
    'Hide it from Home and restore it later': 'اسے ہوم سے چھپائیں اور بعد میں واپس لائیں',
    'I am connected to the hotspot': 'میں ہاٹ اسپاٹ سے کنیکٹ ہوں',
    'is available.': 'دستیاب ہو۔',
    'Keep the switch powered. Hold the Wi-Fi button for 3 seconds, release it, then wait 10 seconds. If the button is not available, keep the switch powered and wait about 1 minute for automatic recovery.': 'سوئچ کو پاور پر رکھیں۔ وائی فائی بٹن 3 سیکنڈ دبائیں، چھوڑ دیں، پھر 10 سیکنڈ انتظار کریں۔ اگر بٹن دستیاب نہیں تو سوئچ کو پاور پر رکھیں اور آٹومیٹک ریکوری کے لیے تقریباً 1 منٹ انتظار کریں۔',
    'Manage access': 'ایکسس مینیج کریں',
    'Next, connect your phone to': 'اب فون کو کنیکٹ کریں',
    'OK': 'ٹھیک ہے',
    'Open phone Wi-Fi settings and connect to': 'فون کی وائی فائی سیٹنگز کھولیں اور کنیکٹ کریں',
    'Opening Wi-Fi setup': 'وائی فائی سیٹ اپ کھل رہا ہے',
    'Open Wi-Fi setup': 'وائی فائی سیٹ اپ کھولیں',
    'Open Wi-Fi setup?': 'وائی فائی سیٹ اپ کھولیں؟',
    'Please wait while your switch prepares setup.': 'براہ کرم انتظار کریں، سوئچ سیٹ اپ تیار کر رہا ہے۔',
    'Product ID': 'پروڈکٹ آئی ڈی',
    'Product status': 'پروڈکٹ اسٹیٹس',
    'Reconnect after a router or Wi-Fi password change. Keep the device label or box nearby.': 'راؤٹر یا وائی فائی پاس ورڈ تبدیل ہونے کے بعد دوبارہ کنیکٹ کریں۔ ڈیوائس لیبل یا باکس قریب رکھیں۔',
    'Reconnect an offline switch': 'آف لائن سوئچ دوبارہ کنیکٹ کریں',
    'Remove': 'ہٹائیں',
    'Remove from My Devices?': 'میری ڈیوائسز سے ہٹائیں؟',
    'Rename Device': 'ڈیوائس کا نام تبدیل کریں',
    'Rename device': 'ڈیوائس کا نام تبدیل کریں',
    'Return here, continue, and test the hotspot before entering the new home Wi-Fi details.': 'یہاں واپس آئیں، جاری رکھیں، اور نئے ہوم وائی فائی کی تفصیل درج کرنے سے پہلے ہاٹ اسپاٹ ٹیسٹ کریں۔',
    'Share this device or transfer ownership': 'یہ ڈیوائس شیئر کریں یا ملکیت منتقل کریں',
    'Smart Switch': 'سمارٹ سوئچ',
    'Switch did not confirm yet': 'سوئچ نے ابھی تصدیق نہیں کی',
    'The app cannot change Wi-Fi through Firebase while the switch is offline. Use the switch recovery hotspot instead. This does not pair the device again or change ownership.': 'سوئچ آف لائن ہو تو ایپ Firebase کے ذریعے وائی فائی تبدیل نہیں کر سکتی۔ اس کے بجائے سوئچ کا ریکوری ہاٹ اسپاٹ استعمال کریں۔ اس سے ڈیوائس دوبارہ پیئر نہیں ہوتی اور نہ ملکیت بدلتی ہے۔',
    'The safe Wi-Fi setup request was sent, but the app did not receive an acknowledgement. Keep the switch powered. If it is offline, use Reconnect Wi-Fi and open the local hotspot instead.': 'محفوظ وائی فائی سیٹ اپ درخواست بھیج دی گئی، مگر ایپ کو تصدیق نہیں ملی۔ سوئچ کو پاور پر رکھیں۔ اگر یہ آف لائن ہے تو Reconnect Wi-Fi استعمال کریں اور لوکل ہاٹ اسپاٹ کھولیں۔',
    'The switch will create': 'سوئچ بنائے گا',
    'This hides the device from your dashboard only. It does not erase WiFi, firmware, timers, schedules, ownership, or the physical switch. You can restore it later from Archived Devices.': 'یہ ڈیوائس صرف ڈیش بورڈ سے چھپاتا ہے۔ یہ وائی فائی، فرم ویئر، ٹائمرز، شیڈولز، ملکیت یا فزیکل سوئچ کو نہیں مٹاتا۔ آپ اسے بعد میں Archived Devices سے واپس لا سکتے ہیں۔',
    'This product can be paired with its printed claim code.': 'اس پروڈکٹ کو اس کے پرنٹڈ کلیم کوڈ سے پیئر کیا جا سکتا ہے۔',
    'This product is not yet marked eligible for activation.': 'یہ پروڈکٹ ابھی ایکٹیویشن کے لیے اہل نشان زد نہیں ہوئی۔',
    'This product is registered to its current owner.': 'یہ پروڈکٹ اپنے موجودہ مالک کے نام رجسٹرڈ ہے۔',
    'This is a legacy registered product.': 'یہ ایک پرانی رجسٹرڈ پروڈکٹ ہے۔',
    'Waiting for the switch to open Wi-Fi setup…': 'سوئچ کے وائی فائی سیٹ اپ کھولنے کا انتظار ہے...',
    'Wi-Fi & recovery': 'وائی فائی اور ریکوری',
    'Wi-Fi setup only updates the switch network. Your controls, timers, schedules, and access stay unchanged.': 'وائی فائی سیٹ اپ صرف سوئچ کا نیٹ ورک اپ ڈیٹ کرتا ہے۔ کنٹرولز، ٹائمرز، شیڈولز اور ایکسس تبدیل نہیں ہوتے۔',
    'You have shared access. You can control power, timers, and your own energy estimate. The owner manages Wi-Fi, schedules, and access.': 'آپ کے پاس شیئرڈ ایکسس ہے۔ آپ پاور، ٹائمرز اور اپنی انرجی کا اندازہ کنٹرول کر سکتے ہیں۔ مالک وائی فائی، شیڈولز اور ایکسس مینیج کرتا ہے۔',
    'Your current Wi-Fi stays saved until the new network works.': 'نیا نیٹ ورک کام کرنے تک موجودہ وائی فائی محفوظ رہتا ہے۔',
    'Ready to activate': 'ایکٹیویٹ کرنے کے لیے تیار',
    'Registered': 'رجسٹرڈ',
    'Activation blocked': 'ایکٹیویشن بلاک ہے',
    'Not activated for sale': 'فروخت کے لیے ایکٹیویٹ نہیں',
    'Not registered': 'رجسٹرڈ نہیں',
    'Contact Easy Home Control support for this product.': 'اس پروڈکٹ کے لیے ایزی ہوم کنٹرول سپورٹ سے رابطہ کریں۔',
    'Pair this product using its Device ID and claim code.': 'اس پروڈکٹ کو ڈیوائس آئی ڈی اور کلیم کوڈ سے پیئر کریں۔',

    // Stage 5E User Guide screen.
    'User guide': 'یوزر گائیڈ',
    'Step-by-step Wi-Fi setup, installation tips, and video guide.': 'مرحلہ وار وائی فائی سیٹ اپ، انسٹالیشن ٹپس اور ویڈیو گائیڈ۔',
    'Install and connect your switch': 'اپنا سوئچ انسٹال اور کنیکٹ کریں',
    'Follow these simple steps to connect your Easy Home Control switch to home Wi-Fi.': 'اپنے ایزی ہوم کنٹرول سوئچ کو ہوم وائی فائی سے جوڑنے کے لیے یہ آسان مراحل فالو کریں۔',
    'Wi-Fi setup steps': 'وائی فائی سیٹ اپ مراحل',
    'Use these steps for a new switch or after changing your router password.': 'نئے سوئچ کے لیے یا راؤٹر پاس ورڈ بدلنے کے بعد یہ مراحل استعمال کریں۔',
    'Power the switch safely': 'سوئچ کو محفوظ طریقے سے پاور دیں',
    'Power the switch only after safe installation. Do not touch live wiring. For wall installation, use a qualified electrician.': 'محفوظ انسٹالیشن کے بعد ہی سوئچ کو پاور دیں۔ لائیو وائرنگ کو ہاتھ نہ لگائیں۔ وال انسٹالیشن کے لیے مستند الیکٹریشن استعمال کریں۔',
    'Keep the label or box nearby': 'لیبل یا باکس قریب رکھیں',
    'You may need the Device ID, claim code, setup hotspot name, and setup password printed on the device label or product box.': 'آپ کو ڈیوائس لیبل یا پروڈکٹ باکس پر پرنٹ ڈیوائس آئی ڈی، کلیم کوڈ، سیٹ اپ ہاٹ اسپاٹ نام اور سیٹ اپ پاس ورڈ کی ضرورت پڑ سکتی ہے۔',
    'Open the switch hotspot': 'سوئچ ہاٹ اسپاٹ کھولیں',
    'For a new switch, turn it on and wait for the setup hotspot. For reconnect, hold the Wi-Fi button for 3 seconds or wait about 1 minute after Wi-Fi fails.': 'نئے سوئچ کے لیے اسے آن کریں اور سیٹ اپ ہاٹ اسپاٹ کا انتظار کریں۔ دوبارہ کنیکٹ کے لیے وائی فائی بٹن 3 سیکنڈ دبائیں یا وائی فائی فیل ہونے کے بعد تقریباً 1 منٹ انتظار کریں۔',
    'Connect your phone to switch Wi-Fi': 'فون کو سوئچ وائی فائی سے کنیکٹ کریں',
    'Open phone Wi-Fi settings and join EHC_SETUP_XXXXX using the setup password printed on the label or box.': 'فون کی وائی فائی سیٹنگز کھولیں اور لیبل یا باکس پر پرنٹ سیٹ اپ پاس ورڈ سے EHC_SETUP_XXXXX جوائن کریں۔',
    'Stay connected if Android says no internet': 'اگر Android no internet کہے تو کنیکٹ رہیں',
    'Some phones show “No internet” because the switch hotspot is only for setup. Choose Stay connected, then return to the app.': 'کچھ فون “No internet” دکھاتے ہیں کیونکہ سوئچ ہاٹ اسپاٹ صرف سیٹ اپ کے لیے ہے۔ Stay connected منتخب کریں، پھر ایپ میں واپس آئیں۔',
    'Enter home Wi-Fi details': 'ہوم وائی فائی تفصیلات درج کریں',
    'Enter your home Wi-Fi name and password in the app. Keep the page open until the switch confirms that Wi-Fi was accepted.': 'ایپ میں ہوم وائی فائی نام اور پاس ورڈ درج کریں۔ جب تک سوئچ تصدیق نہ کرے کہ وائی فائی قبول ہو گیا ہے، صفحہ کھلا رکھیں۔',
    'Reconnect your phone normally': 'فون کو نارمل کنکشن پر واپس لائیں',
    'After the switch accepts Wi-Fi, connect your phone back to normal Wi-Fi or mobile data and let the app confirm the switch is online.': 'سوئچ کے وائی فائی قبول کرنے کے بعد فون کو نارمل وائی فائی یا موبائل ڈیٹا پر واپس کنیکٹ کریں اور ایپ کو سوئچ آن لائن کنفرم کرنے دیں۔',
    'If something does not work': 'اگر کچھ کام نہ کرے',
    'Try these checks before contacting support.': 'سپورٹ سے رابطہ کرنے سے پہلے یہ چیزیں چیک کریں۔',
    'Wrong Wi-Fi password': 'غلط وائی فائی پاس ورڈ',
    'The switch will not save wrong details. Reconnect to the switch hotspot and enter the correct home Wi-Fi password again.': 'سوئچ غلط تفصیلات محفوظ نہیں کرے گا۔ سوئچ ہاٹ اسپاٹ سے دوبارہ کنیکٹ کریں اور درست ہوم وائی فائی پاس ورڈ دوبارہ درج کریں۔',
    'Router password changed': 'راؤٹر پاس ورڈ تبدیل ہو گیا',
    'Keep the switch powered. Its recovery hotspot opens automatically after about 1 minute, then you can enter the new home Wi-Fi details.': 'سوئچ کو پاور پر رکھیں۔ اس کا ریکوری ہاٹ اسپاٹ تقریباً 1 منٹ بعد خود کھل جائے گا، پھر آپ نئے ہوم وائی فائی کی تفصیلات درج کر سکتے ہیں۔',
    'Hotspot not visible': 'ہاٹ اسپاٹ نظر نہیں آ رہا',
    'Wait a few seconds, refresh phone Wi-Fi, and keep the switch powered. If needed, power cycle the switch once and try again.': 'چند سیکنڈ انتظار کریں، فون وائی فائی ریفریش کریں، اور سوئچ کو پاور پر رکھیں۔ ضرورت ہو تو سوئچ کو ایک بار پاور سائیکل کریں اور دوبارہ کوشش کریں۔',
    'Watch video guide': 'ویڈیو گائیڈ دیکھیں',
    'If setup is confusing, open our YouTube guide.': 'اگر سیٹ اپ مشکل لگے تو ہماری یوٹیوب گائیڈ کھولیں۔',
    'Open YouTube': 'یوٹیوب کھولیں',
    'Copy link': 'لنک کاپی کریں',
    'YouTube link copied.': 'یوٹیوب لنک کاپی ہو گیا۔',
    'YouTube link copied. Open it in your browser.': 'یوٹیوب لنک کاپی ہو گیا۔ اسے اپنے براؤزر میں کھولیں۔',
    'Guide': 'گائیڈ',
    'User Guide': 'یوزر گائیڈ',
    'Installation guide': 'انسٹالیشن گائیڈ',
    'Video guide': 'ویڈیو گائیڈ',
    'Wi-Fi guide': 'وائی فائی گائیڈ',
    // Stage 5H Add / Join / Reconnect screens.
    'Asking the switch to open its secure setup Wi-Fi…': 'سوئچ سے محفوظ سیٹ اپ وائی فائی کھولنے کی درخواست بھیجی جا رہی ہے...',
    'Before you start': 'شروع کرنے سے پہلے',
    'Change Wi-Fi': 'وائی فائی تبدیل کریں',
    'Change a switch to a new home Wi-Fi, or reconnect it after a router or password change.': 'سوئچ کو نئے ہوم وائی فائی سے جوڑیں، یا راؤٹر/پاس ورڈ بدلنے کے بعد دوبارہ کنیکٹ کریں۔',
    'Checking device…': 'ڈیوائس چیک ہو رہی ہے...',
    'Choose a switch': 'سوئچ منتخب کریں',
    'Claim code': 'کلیم کوڈ',
    'Continue to Wi-Fi': 'وائی فائی پر جاری رکھیں',
    'Control a home switch together': 'گھر کے سوئچ کو مل کر کنٹرول کریں',
    'Could not join this device. Check your internet connection and try again.': 'یہ ڈیوائس جوائن نہیں ہو سکی۔ انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'Could not open device Wi-Fi. Check your connection and try again.': 'ڈیوائس وائی فائی نہیں کھل سکا۔ اپنا کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'Could not pair this device. Please check your internet and try again.': 'یہ ڈیوائس پیئر نہیں ہو سکی۔ براہ کرم انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں۔',
    'Device ID looks too short': 'ڈیوائس آئی ڈی بہت چھوٹی لگ رہی ہے',
    'Device Wi-Fi': 'ڈیوائس وائی فائی',
    'Device name (optional)': 'ڈیوائس کا نام (اختیاری)',
    'Enter shared device details': 'شیئرڈ ڈیوائس کی تفصیلات درج کریں',
    'Example: 8K29P4': 'مثال: 8K29P4',
    'Example: Bedroom light': 'مثال: بیڈروم لائٹ',
    'Example: EHC001A7F92': 'مثال: EHC001A7F92',
    'Example: Living Room': 'مثال: لیونگ روم',
    'Find your device details': 'اپنی ڈیوائس کی تفصیلات تلاش کریں',
    'How shared access works': 'شیئرڈ ایکسس کیسے کام کرتا ہے',
    'How to get a code': 'کوڈ کیسے حاصل کریں',
    'Join device': 'ڈیوائس جوائن کریں',
    'Join shared device': 'شیئرڈ ڈیوائس جوائن کریں',
    'Joining a shared switch does not change its Wi-Fi, timers, or existing schedules.': 'شیئرڈ سوئچ جوائن کرنے سے اس کا وائی فائی، ٹائمرز یا موجودہ شیڈولز تبدیل نہیں ہوتے۔',
    'Joining device…': 'ڈیوائس جوائن ہو رہی ہے...',
    'Keep the device label or product box nearby. You need the setup hotspot password printed there. The Device ID identifies the switch; the Claim Code is only needed when adding a new switch to an account.': 'ڈیوائس لیبل یا پروڈکٹ باکس قریب رکھیں۔ سیٹ اپ ہاٹ اسپاٹ پاس ورڈ وہیں پرنٹ ہوتا ہے۔ ڈیوائس آئی ڈی سوئچ کو پہچانتی ہے؛ کلیم کوڈ صرف نیا سوئچ اکاؤنٹ میں شامل کرتے وقت چاہیے ہوتا ہے۔',
    'Look for the product label on the switch, its box, or the QR label.': 'سوئچ، اس کے باکس، یا QR لیبل پر پروڈکٹ لیبل دیکھیں۔',
    'Name in your app': 'آپ کی ایپ میں نام',
    'New setup or shared access': 'نیا سیٹ اپ یا شیئرڈ ایکسس',
    'Offline · Use the local recovery hotspot': 'آف لائن · لوکل ریکوری ہاٹ اسپاٹ استعمال کریں',
    'One-time share code': 'ون ٹائم شیئر کوڈ',
    'Online · Open setup Wi-Fi remotely': 'آن لائن · سیٹ اپ وائی فائی ریموٹلی کھولیں',
    'Only the device owner can change its Wi-Fi connection.': 'صرف ڈیوائس مالک اس کا وائی فائی کنکشن تبدیل کر سکتا ہے۔',
    'Open My Devices': 'میری ڈیوائسز کھولیں',
    'Open setup Wi-Fi': 'سیٹ اپ وائی فائی کھولیں',
    'Open switch setup Wi-Fi?': 'سوئچ کا سیٹ اپ وائی فائی کھولیں؟',
    'Pair': 'پیئر',
    'Pair your switch': 'اپنا سوئچ پیئر کریں',
    'Please enter Device ID': 'براہ کرم ڈیوائس آئی ڈی درج کریں',
    'Please enter the claim code printed on the device': 'براہ کرم ڈیوائس پر پرنٹ کلیم کوڈ درج کریں',
    'Product label details': 'پروڈکٹ لیبل کی تفصیلات',
    'Reconnect': 'دوبارہ کنیکٹ',
    'Set up a new switch with its printed code, or join a device shared by its owner.': 'پرنٹڈ کوڈ سے نیا سوئچ سیٹ اپ کریں، یا مالک کی طرف سے شیئر کی گئی ڈیوائس جوائن کریں۔',
    'The claim code verifies ownership. Your home Wi-Fi password is requested in the next step only.': 'کلیم کوڈ ملکیت کی تصدیق کرتا ہے۔ ہوم وائی فائی پاس ورڈ صرف اگلے مرحلے میں لیا جائے گا۔',
    'The owner can remove shared access at any time. A share code works once and expires after 10 minutes.': 'مالک کسی بھی وقت شیئرڈ ایکسس ختم کر سکتا ہے۔ شیئر کوڈ ایک بار کام کرتا ہے اور 10 منٹ بعد ختم ہو جاتا ہے۔',
    'The switch did not confirm setup mode. Check that it is online, then try again.': 'سوئچ نے سیٹ اپ موڈ کی تصدیق نہیں کی۔ چیک کریں کہ یہ آن لائن ہے، پھر دوبارہ کوشش کریں۔',
    'Use the Device ID and Claim Code printed on your product label.': 'پروڈکٹ لیبل پر پرنٹ ڈیوائس آئی ڈی اور کلیم کوڈ استعمال کریں۔',
    'Use the Device ID and temporary code sent by the owner.': 'مالک کے بھیجے ہوئے ڈیوائس آئی ڈی اور عارضی کوڈ استعمال کریں۔',
    'Use the information printed on your switch.': 'اپنے سوئچ پر پرنٹ معلومات استعمال کریں۔',
    'Use the printed claim code only for first ownership. For family access, ask the owner for a temporary share code.': 'پرنٹڈ کلیم کوڈ صرف پہلی ملکیت کے لیے استعمال کریں۔ فیملی ایکسس کے لیے مالک سے عارضی شیئر کوڈ مانگیں۔',
    'Waiting for the switch to confirm…': 'سوئچ کی تصدیق کا انتظار ہے...',
    'Where is it?': 'یہ کہاں ہے؟',
    'Wi-Fi': 'وائی فائی',
    'Set up my new switch': 'میرا نیا سوئچ سیٹ اپ کریں',
    'Use the Device ID and printed claim code. You will connect Wi-Fi next.': 'ڈیوائس آئی ڈی اور پرنٹڈ کلیم کوڈ استعمال کریں۔ اگلے مرحلے میں وائی فائی کنیکٹ ہوگا۔',
    'Start new setup': 'نیا سیٹ اپ شروع کریں',
    'Join a shared switch': 'شیئرڈ سوئچ جوائن کریں',
    'Use a temporary code from the owner. No Wi-Fi setup is needed.': 'مالک کا عارضی کوڈ استعمال کریں۔ وائی فائی سیٹ اپ کی ضرورت نہیں۔',
    'Reconnect an existing switch': 'موجودہ سوئچ دوبارہ کنیکٹ کریں',
    'Use this after a router, network, or Wi-Fi password change. Pairing is not repeated.': 'راؤٹر، نیٹ ورک، یا وائی فائی پاس ورڈ بدلنے کے بعد یہ استعمال کریں۔ پیئرنگ دوبارہ نہیں ہوتی۔',
    'Reconnect switch': 'سوئچ دوبارہ کنیکٹ کریں',
    'Switch has power': 'سوئچ کو پاور مل رہی ہے',
    'Turn it on before starting setup.': 'سیٹ اپ شروع کرنے سے پہلے اسے آن کریں۔',
    'Product label is nearby': 'پروڈکٹ لیبل قریب ہے',
    'You need the Device ID and claim code.': 'آپ کو ڈیوائس آئی ڈی اور کلیم کوڈ چاہیے۔',
    'Home Wi-Fi details are ready': 'ہوم وائی فائی تفصیلات تیار ہیں',
    'You will enter them after pairing.': 'آپ انہیں پیئرنگ کے بعد درج کریں گے۔',
    'Usually begins with EHC. Enter it exactly as printed.': 'عام طور پر EHC سے شروع ہوتی ہے۔ اسے بالکل پرنٹ کے مطابق درج کریں۔',
    'A short code that confirms this switch belongs to you.': 'ایک مختصر کوڈ جو تصدیق کرتا ہے کہ یہ سوئچ آپ کا ہے۔',
    'DEVICE ID': 'ڈیوائس آئی ڈی',
    'CLAIM CODE': 'کلیم کوڈ',
    'Check your internet connection and try again.': 'اپنا انٹرنیٹ کنکشن چیک کریں اور دوبارہ کوشش کریں۔',
    'No registered switch found': 'کوئی رجسٹرڈ سوئچ نہیں ملا',
    'Add your first Easy Home Control switch before managing device Wi-Fi.': 'ڈیوائس وائی فائی مینیج کرنے سے پہلے اپنا پہلا ایزی ہوم کنٹرول سوئچ شامل کریں۔',
    'Offline switch?': 'آف لائن سوئچ؟',
    'Keep it powered. The next screen will show the shortest way to open its setup hotspot and reconnect it.': 'اسے پاور پر رکھیں۔ اگلی اسکرین سیٹ اپ ہاٹ اسپاٹ کھولنے اور دوبارہ کنیکٹ کرنے کا آسان طریقہ دکھائے گی۔',
    'Ask the switch owner to open Device settings and choose Manage access.': 'سوئچ مالک سے کہیں کہ Device settings کھول کر Manage access منتخب کرے۔',
    'They create a one-time 20-character share code for you.': 'وہ آپ کے لیے 20 حروف کا ون ٹائم شیئر کوڈ بناتے ہیں۔',
    'You do not need the printed claim code or the home Wi-Fi password.': 'آپ کو پرنٹڈ کلیم کوڈ یا ہوم وائی فائی پاس ورڈ کی ضرورت نہیں۔',
    'Transfer request accepted': 'ٹرانسفر درخواست قبول ہو گئی',
    'Already in your devices': 'پہلے ہی آپ کی ڈیوائسز میں ہے',
    'Device added': 'ڈیوائس شامل ہو گئی',

    // Stage 5I Wi-Fi setup and activation screens.
    'Still connecting your switch. It can briefly stop answering while it joins home Wi-Fi. Keep this page open.': 'سوئچ ابھی ہوم وائی فائی سے کنیکٹ ہو رہا ہے۔ اس دوران یہ کچھ دیر جواب دینا روک سکتا ہے۔ یہ صفحہ کھلا رکھیں۔',
    'Still connecting your switch. It can briefly stop answering while it joins home Wi-Fi. Keep this page open. About {seconds} seconds remaining.': 'سوئچ ابھی ہوم وائی فائی سے کنیکٹ ہو رہا ہے۔ اس دوران یہ کچھ دیر جواب دینا روک سکتا ہے۔ یہ صفحہ کھلا رکھیں۔ تقریباً {seconds} سیکنڈ باقی ہیں۔',
    'Join {hotspot} using the setup password printed on the device label or box.': '{hotspot} جوائن کریں۔ سیٹ اپ پاس ورڈ ڈیوائس لیبل یا باکس پر پرنٹ ہے۔',
    'Checking connection to {hotspot}…': '{hotspot} سے کنکشن چیک ہو رہا ہے...',
    'Connect your phone to {hotspot} first. Use the setup password printed on the device label or box.': 'پہلے اپنے فون کو {hotspot} سے کنیکٹ کریں۔ سیٹ اپ پاس ورڈ ڈیوائس لیبل یا باکس پر پرنٹ ہے۔',
    'Reconnect to {hotspot} and wait for the switch status before trying again.': '{hotspot} سے دوبارہ کنیکٹ کریں اور دوبارہ کوشش سے پہلے سوئچ اسٹیٹس کا انتظار کریں۔',
    'Could not send the details to the switch. Keep your phone connected to {hotspot}, then try again.': 'تفصیلات سوئچ کو نہیں بھیجی جا سکیں۔ فون کو {hotspot} سے کنیکٹ رکھیں، پھر دوبارہ کوشش کریں۔',
    'Reconnect to {hotspot}, then the app will check the switch result.': '{hotspot} سے دوبارہ کنیکٹ کریں، پھر ایپ سوئچ کا نتیجہ چیک کرے گی۔',
    'Look for {hotspot} in phone Wi-Fi settings.': 'فون کی وائی فائی سیٹنگز میں {hotspot} تلاش کریں۔',
    'In phone Wi-Fi settings, join {hotspot} with the password on the device label or box. If Android says “No internet”, keep the connection and return here.': 'فون کی وائی فائی سیٹنگز میں {hotspot} جوائن کریں۔ پاس ورڈ ڈیوائس لیبل یا باکس پر ہے۔ اگر Android “No internet” کہے تو کنکشن برقرار رکھیں اور یہاں واپس آئیں۔',
    'Keep this page open. If it still does not update, reconnect to {hotspot}, keep the phone connected even if it says “No internet”, then check again.': 'یہ صفحہ کھلا رکھیں۔ اگر پھر بھی اپ ڈیٹ نہ ہو تو {hotspot} سے دوبارہ کنیکٹ کریں، فون کو کنیکٹ رکھیں چاہے “No internet” لکھا آئے، پھر دوبارہ چیک کریں۔',
    'Reconnect this phone from {hotspot} to your normal Wi-Fi or mobile data. The app will confirm the switch automatically once it comes online.': 'اس فون کو {hotspot} سے ہٹا کر اپنے نارمل وائی فائی یا موبائل ڈیٹا پر واپس کنیکٹ کریں۔ سوئچ آن لائن ہوتے ہی ایپ خود تصدیق کر دے گی۔',
    'Elapsed time: {seconds} seconds': 'گزرا ہوا وقت: {seconds} سیکنڈ',
    '{name} is ready': '{name} تیار ہے',
    'Reconnect {name}': '{name} دوبارہ کنیکٹ کریں',
    'Connect {name}': '{name} کنیکٹ کریں',
    'The switch has already saved your home Wi-Fi. It will restart shortly.': 'سوئچ نے پہلے ہی ہوم وائی فائی محفوظ کر لیا ہے۔ یہ تھوڑی دیر میں ری اسٹارٹ ہوگا۔',
    'Testing your home Wi-Fi. Keep this page open.': 'آپ کا ہوم وائی فائی ٹیسٹ ہو رہا ہے۔ یہ صفحہ کھلا رکھیں۔',
    'The switch is connected. The previous home Wi-Fi details were not accepted. Correct them below and try again.': 'سوئچ کنیکٹ ہے۔ پچھلی ہوم وائی فائی تفصیلات قبول نہیں ہوئیں۔ نیچے درست کریں اور دوبارہ کوشش کریں۔',
    'Phone connected to the secure switch hotspot. Enter your home Wi-Fi below.': 'فون محفوظ سوئچ ہاٹ اسپاٹ سے کنیکٹ ہے۔ نیچے اپنا ہوم وائی فائی درج کریں۔',
    'Switch hotspot confirmed. Enter your home Wi-Fi below.': 'سوئچ ہاٹ اسپاٹ کنفرم ہو گیا۔ نیچے اپنا ہوم وائی فائی درج کریں۔',
    'The switch is preparing its setup hotspot. Wait a few seconds, then check again.': 'سوئچ اپنا سیٹ اپ ہاٹ اسپاٹ تیار کر رہا ہے۔ چند سیکنڈ انتظار کریں، پھر دوبارہ چیک کریں۔',
    'Enter your home Wi-Fi name.': 'اپنے ہوم وائی فائی کا نام درج کریں۔',
    'Sending details to the switch…': 'تفصیلات سوئچ کو بھیجی جا رہی ہیں...',
    'Testing your home Wi-Fi. Keep this page open until the switch confirms the result.': 'آپ کا ہوم وائی فائی ٹیسٹ ہو رہا ہے۔ جب تک سوئچ نتیجہ کنفرم نہ کرے یہ صفحہ کھلا رکھیں۔',
    'Home Wi-Fi was accepted and saved. The switch is restarting now.': 'ہوم وائی فائی قبول اور محفوظ ہو گیا۔ سوئچ اب ری اسٹارٹ ہو رہا ہے۔',
    'Connecting your switch to home Wi-Fi. Keep this page open.': 'سوئچ ہوم وائی فائی سے کنیکٹ ہو رہا ہے۔ یہ صفحہ کھلا رکھیں۔',
    'Waiting for the switch to start checking your home Wi-Fi…': 'سوئچ کے ہوم وائی فائی چیک شروع کرنے کا انتظار ہے...',
    'Still waiting for the switch result. The app will keep checking automatically.': 'ابھی سوئچ کے نتیجے کا انتظار ہے۔ ایپ خود بخود چیک کرتی رہے گی۔',
    'Home Wi-Fi was not accepted. Check the Wi-Fi name and password, then try again.': 'ہوم وائی فائی قبول نہیں ہوا۔ وائی فائی نام اور پاس ورڈ چیک کریں، پھر دوبارہ کوشش کریں۔',
    'The home Wi-Fi details were not accepted. Check the Wi-Fi name and password, then try again.': 'ہوم وائی فائی تفصیلات قبول نہیں ہوئیں۔ وائی فائی نام اور پاس ورڈ چیک کریں، پھر دوبارہ کوشش کریں۔',
    'Wait for the switch to confirm that your home Wi-Fi was accepted.': 'سوئچ کی تصدیق کا انتظار کریں کہ ہوم وائی فائی قبول ہو گیا ہے۔',
    'Reconnect Wi-Fi': 'وائی فائی دوبارہ کنیکٹ کریں',
    'Connect Wi-Fi': 'وائی فائی کنیکٹ کریں',
    'This only updates the home Wi-Fi used by this switch. Pairing, ownership, timers and schedules stay unchanged.': 'یہ صرف اس سوئچ کا ہوم وائی فائی اپ ڈیٹ کرتا ہے۔ پیئرنگ، ملکیت، ٹائمرز اور شیڈولز تبدیل نہیں ہوتے۔',
    'Use the secure setup hotspot, then give the switch your home Wi-Fi details. Keep the device label or box nearby.': 'محفوظ سیٹ اپ ہاٹ اسپاٹ استعمال کریں، پھر سوئچ کو ہوم وائی فائی تفصیلات دیں۔ ڈیوائس لیبل یا باکس قریب رکھیں۔',
    'Testing home Wi-Fi…': 'ہوم وائی فائی ٹیسٹ ہو رہا ہے...',
    'Try again': 'دوبارہ کوشش کریں',
    'Connect to home Wi-Fi': 'ہوم وائی فائی سے کنیکٹ کریں',
    'Keep the device label or box nearby': 'ڈیوائس لیبل یا باکس قریب رکھیں',
    'Switch Wi-Fi': 'سوئچ وائی فائی',
    'Setup password': 'سیٹ اپ پاس ورڈ',
    'Printed on the device label or product box': 'ڈیوائس لیبل یا پروڈکٹ باکس پر پرنٹ ہے',
    'Claim Code': 'کلیم کوڈ',
    'Not needed for this reconnect; keep it safe for first-time pairing.': 'اس دوبارہ کنیکٹ کے لیے ضرورت نہیں؛ پہلی بار پیئرنگ کے لیے محفوظ رکھیں۔',
    'Use it to add this switch to your account.': 'اس سوئچ کو اپنے اکاؤنٹ میں شامل کرنے کے لیے اسے استعمال کریں۔',
    'Hold the switch Wi-Fi button for 3 seconds, release it, then wait up to 10 seconds.': 'سوئچ کا وائی فائی بٹن 3 سیکنڈ دبائیں، چھوڑ دیں، پھر 10 سیکنڈ تک انتظار کریں۔',
    'Turn the switch on. Its setup hotspot should appear in your phone Wi-Fi list within about 10 seconds.': 'سوئچ آن کریں۔ اس کا سیٹ اپ ہاٹ اسپاٹ تقریباً 10 سیکنڈ میں فون کی وائی فائی لسٹ میں آ جانا چاہیے۔',
    'Changed your router password? Turn the switch off and on, then wait about 1 minute for this recovery hotspot. You can also hold the Wi-Fi button for 3 seconds.': 'راؤٹر پاس ورڈ بدل گیا ہے؟ سوئچ کو بند کر کے دوبارہ آن کریں، پھر اس ریکوری ہاٹ اسپاٹ کے لیے تقریباً 1 منٹ انتظار کریں۔ آپ وائی فائی بٹن 3 سیکنڈ بھی دبا سکتے ہیں۔',
    'If the hotspot does not appear, check that the switch has power and wait a few seconds.': 'اگر ہاٹ اسپاٹ نظر نہ آئے تو چیک کریں کہ سوئچ کو پاور مل رہی ہے، پھر چند سیکنڈ انتظار کریں۔',
    '1. Open switch Wi-Fi': '1. سوئچ وائی فائی کھولیں',
    '2. Phone connected to switch': '2. فون سوئچ سے کنیکٹ ہے',
    '2. Join switch Wi-Fi': '2. سوئچ وائی فائی جوائن کریں',
    'Checking switch…': 'سوئچ چیک ہو رہا ہے...',
    'Check connection again': 'کنکشن دوبارہ چیک کریں',
    'I joined switch Wi-Fi': 'میں نے سوئچ وائی فائی جوائن کر لیا',
    'The app detected the switch automatically.': 'ایپ نے سوئچ خود بخود ڈھونڈ لیا۔',
    'The app checks automatically when you return from phone Wi-Fi settings.': 'فون وائی فائی سیٹنگز سے واپس آنے پر ایپ خود بخود چیک کرتی ہے۔',
    '3. Enter home Wi-Fi': '3. ہوم وائی فائی درج کریں',
    'This is the Wi-Fi the switch will use every day.': 'یہ وہ وائی فائی ہے جو سوئچ روز استعمال کرے گا۔',
    'Home Wi-Fi name': 'ہوم وائی فائی نام',
    'Network / SSID': 'نیٹ ورک / SSID',
    'Home Wi-Fi password': 'ہوم وائی فائی پاس ورڈ',
    'Home Wi-Fi saved': 'ہوم وائی فائی محفوظ ہو گیا',
    'The switch accepted the new Wi-Fi details. Reconnect this phone to your normal Wi-Fi or mobile data, then let the app confirm the switch is online.': 'سوئچ نے نئی وائی فائی تفصیلات قبول کر لیں۔ اس فون کو نارمل وائی فائی یا موبائل ڈیٹا پر واپس کنیکٹ کریں، پھر ایپ کو سوئچ آن لائن کنفرم کرنے دیں۔',
    'I reconnected my phone': 'میں نے اپنا فون دوبارہ کنیکٹ کر لیا',
    'Wi-Fi result not confirmed': 'وائی فائی نتیجہ کنفرم نہیں ہوا',
    'The switch has not confirmed the final result yet. Do not continue. The app is still checking automatically because the hotspot can pause while the switch changes Wi-Fi.': 'سوئچ نے ابھی حتمی نتیجہ کنفرم نہیں کیا۔ آگے نہ بڑھیں۔ ایپ ابھی بھی خود بخود چیک کر رہی ہے کیونکہ وائی فائی بدلتے وقت ہاٹ اسپاٹ رک سکتا ہے۔',
    'Check now': 'ابھی چیک کریں',
    'Your home Wi-Fi password is sent only to the local switch setup hotspot. It is not stored in Firebase.': 'آپ کا ہوم وائی فائی پاس ورڈ صرف لوکل سوئچ سیٹ اپ ہاٹ اسپاٹ کو بھیجا جاتا ہے۔ یہ Firebase میں محفوظ نہیں ہوتا۔',
    'Confirm reconnect': 'دوبارہ کنیکٹ کنفرم کریں',
    'Finish setup': 'سیٹ اپ مکمل کریں',
    'Still waiting for the switch': 'ابھی سوئچ کا انتظار ہے',
    'Confirming your switch': 'سوئچ کنفرم ہو رہا ہے',
    'Connecting your switch': 'سوئچ کنیکٹ ہو رہا ہے',
    'Wi-Fi recovery is complete. You can now control this switch from the app.': 'وائی فائی ریکوری مکمل ہو گئی۔ اب آپ ایپ سے اس سوئچ کو کنٹرول کر سکتے ہیں۔',
    'Check the Wi-Fi name and password, then return to the previous step and try again.': 'وائی فائی نام اور پاس ورڈ چیک کریں، پھر پچھلے مرحلے پر واپس جا کر دوبارہ کوشش کریں۔',
    'Your phone is back on a normal connection. We are waiting for the registered switch to come online.': 'آپ کا فون نارمل کنکشن پر واپس آ گیا ہے۔ ہم رجسٹرڈ سوئچ کے آن لائن ہونے کا انتظار کر رہے ہیں۔',
    'The switch is restarting and joining your home Wi-Fi. This usually takes less than a minute.': 'سوئچ ری اسٹارٹ ہو کر ہوم وائی فائی جوائن کر رہا ہے۔ عام طور پر اس میں ایک منٹ سے کم وقت لگتا ہے۔',
    'Open home': 'ہوم کھولیں',
    'Waiting for switch…': 'سوئچ کا انتظار ہے...',
    'Back to Wi-Fi setup': 'وائی فائی سیٹ اپ پر واپس جائیں',
    'Saved': 'محفوظ',
    'Ready': 'تیار',
    'Step 3 of 3': 'مرحلہ 3 از 3',
    'Wi-Fi details saved': 'وائی فائی تفصیلات محفوظ ہو گئیں',
    'The switch accepted your home network details.': 'سوئچ نے آپ کے ہوم نیٹ ورک کی تفصیلات قبول کر لیں۔',
    'Joining your home Wi-Fi': 'ہوم وائی فائی جوائن ہو رہا ہے',
    'The switch has joined your network.': 'سوئچ آپ کے نیٹ ورک سے کنیکٹ ہو گیا۔',
    'This step needs attention.': 'اس مرحلے کو توجہ چاہیے۔',
    'The switch is restarting now.': 'سوئچ اب ری اسٹارٹ ہو رہا ہے۔',
    'Ready in Easy Home Control': 'ایزی ہوم کنٹرول میں تیار',
    'You can now control this switch from Home.': 'اب آپ ہوم سے اس سوئچ کو کنٹرول کر سکتے ہیں۔',
    'We are waiting for the switch to come online.': 'ہم سوئچ کے آن لائن ہونے کا انتظار کر رہے ہیں۔',
    'Switch is online': 'سوئچ آن لائن ہے',
    'Connection is taking longer': 'کنکشن میں زیادہ وقت لگ رہا ہے',
    'Waiting for switch to come online': 'سوئچ کے آن لائن ہونے کا انتظار ہے',
    'Setup is complete.': 'سیٹ اپ مکمل ہو گیا۔',


  };

}

extension EhcLocalizationContext on BuildContext {
  AppLanguageController get languageController =>
      AppLanguageScope.controllerOf(this);

  EhcLocalizations get l10n => EhcLocalizations.of(this);

  String tr(String english) => l10n.text(english);

  String trParams(String english, Map<String, Object?> values) {
    var translated = tr(english);
    for (final entry in values.entries) {
      translated = translated.replaceAll('{${entry.key}}', entry.value?.toString() ?? '');
    }
    return translated;
  }
}
