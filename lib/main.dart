import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'features/notes/screens/home_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'l10n/app_localizations.dart';

// Global key to access app-level state (theme/locale) from small settings UI.
final GlobalKey<MyAppState> appKey = GlobalKey<MyAppState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp(key: appKey));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  // Theme and locale are mutable at runtime via settings.
  ThemeMode themeMode = ThemeMode.system;
  Locale? locale;

  void setThemeMode(ThemeMode mode) => setState(() => themeMode = mode);
  void setLocale(Locale? newLocale) => setState(() => locale = newLocale);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: widget.key,
      debugShowCheckedModeBanner: false,
      locale: locale,
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(filled: true),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
