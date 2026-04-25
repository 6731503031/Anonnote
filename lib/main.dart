import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/notes/screens/home_screen.dart';
import 'features/notes/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/security/screens/pin_lock_screen.dart';
import 'features/security/services/pin_lock_service.dart';
import 'features/notes/screens/share_note_screen.dart';
import 'theme/app_theme.dart';
// debug badge removed for production

// Global key to access app-level state (theme/locale) from small settings UI.
final GlobalKey<MyAppState> appKey = GlobalKey<MyAppState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initializeFirestoreOfflinePersistence();
  // Ensure anonymous auth happens before the UI is shown so UID is available.
  try {
    final existing = authService.currentUser;
    if (existing == null) {
      final user = await authService.signInAnonymously();
      if (kDebugMode) {
        if (user != null) {
          debugPrint('Auth uid: ${user.uid}');
        } else {
          debugPrint('AuthService: anonymous sign-in returned null');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('Using existing uid: ${existing.uid}');
      }
    }
  } catch (_) {
    // ignore errors: auth service returns null on failure.
  }
  runApp(MyApp(key: appKey));
}

Future<void> _initializeFirestoreOfflinePersistence() async {
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (_) {
    // Keep startup resilient: app can continue even if persistence is already configured.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  final PinLockService _pinLockService = PinLockService.instance;

  // Theme and locale are mutable at runtime via settings.
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale;
  bool _pinReady = false;
  bool _isAppUnlocked = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    var resolvedTheme = ThemeMode.system;
    Locale? resolvedLocale;
    var hasPin = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final tm = prefs.getString('themeMode') ?? 'system';
      final savedLocale = prefs.getString('locale') ?? '';
      resolvedTheme = tm == 'light'
          ? ThemeMode.light
          : tm == 'dark'
          ? ThemeMode.dark
          : ThemeMode.system;
      resolvedLocale = savedLocale.isEmpty ? null : Locale(savedLocale);
      hasPin = await _pinLockService.hasPin();
    } catch (_) {
      // ignore and keep defaults
      try {
        hasPin = await _pinLockService.hasPin();
      } catch (_) {
        hasPin = false;
      }
    }

    if (!mounted) return;
    setState(() {
      themeMode = resolvedTheme;
      locale = resolvedLocale;
      _pinReady = true;
      _isAppUnlocked = !hasPin;
    });
  }

  Future<void> refreshPinState() async {
    var hasPin = false;
    try {
      hasPin = await _pinLockService.hasPin();
    } catch (_) {
      hasPin = false;
    }
    if (!mounted) return;
    setState(() {
      if (!hasPin) {
        _isAppUnlocked = true;
      }
      if (!_pinReady) {
        _pinReady = true;
      }
    });
  }

  void unlockWithPin() {
    if (!mounted) return;
    setState(() {
      _isAppUnlocked = true;
    });
  }

  void lockIfPinExists() async {
    var hasPin = false;
    try {
      hasPin = await _pinLockService.hasPin();
    } catch (_) {
      hasPin = false;
    }
    if (!mounted) return;
    if (hasPin) {
      setState(() {
        _isAppUnlocked = false;
      });
    }
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => themeMode = mode);
    SharedPreferences.getInstance().then(
      (p) => p.setString(
        'themeMode',
        mode == ThemeMode.light
            ? 'light'
            : mode == ThemeMode.dark
            ? 'dark'
            : 'system',
      ),
    );
  }

  void setLocale(Locale? newLocale) {
    setState(() => locale = newLocale);
    SharedPreferences.getInstance().then(
      (p) => p.setString('locale', newLocale?.languageCode ?? ''),
    );
  }

  // Debug helpers were removed — use the public setters `setThemeMode` and `setLocale`.

  String? _sharedNoteIdFromUri() {
    final uri = Uri.base;

    // Flutter web hash route format: /#/share/{noteId}
    final fragment = uri.fragment;
    if (fragment.startsWith('/share/')) {
      final id = fragment.substring('/share/'.length).trim();
      if (id.isNotEmpty) return id;
    }

    // Non-hash deep link fallback: /share/{noteId}
    final path = uri.path;
    if (path.startsWith('/share/')) {
      final id = path.substring('/share/'.length).trim();
      if (id.isNotEmpty) return id;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final sharedNoteId = _sharedNoteIdFromUri();

    final Widget home = !_pinReady
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : sharedNoteId != null
        ? ShareNoteScreen(noteId: sharedNoteId)
        : _isAppUnlocked
        ? const HomeScreen()
        : PinLockScreen(onUnlocked: unlockWithPin);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: locale,
      // No custom builder in production - use default widget tree.
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'AnonNote',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('th')],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (locale != null) return locale;
        if (deviceLocale == null) return supportedLocales.first;
        for (final supported in supportedLocales) {
          if (supported.languageCode == deviceLocale.languageCode) {
            return supported;
          }
        }
        return supportedLocales.first;
      },
      theme: AppTheme.light().copyWith(
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      darkTheme: AppTheme.dark().copyWith(
        inputDecorationTheme: const InputDecorationTheme(filled: true),
      ),
      themeMode: themeMode,
      home: home,
    );
  }
}
