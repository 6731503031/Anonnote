import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Set<String> _langSelected;
  late Set<String> _themeSelected;

  @override
  void initState() {
    super.initState();
    final state = appKey.currentState;
    _langSelected = {
      if (state?.locale == null) 'system' else state!.locale!.languageCode,
    };
    _themeSelected = {
      switch (state?.themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        _ => 'system',
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(t.settings, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),

            Text('Language', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment(value: 'system', label: Text(t.system)),
                const ButtonSegment(value: 'en', label: Text('English')),
                const ButtonSegment(value: 'th', label: Text('ไทย')),
              ],
              selected: _langSelected,
              onSelectionChanged: (newSelection) {
                final value = newSelection.first;
                setState(() => _langSelected = {value});
                if (value == 'system') {
                  appKey.currentState?.setLocale(null);
                  debugPrint('Settings: locale set to system');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Language: ${t.system}')),
                  );
                } else {
                  appKey.currentState?.setLocale(Locale(value));
                  debugPrint('Settings: locale set to $value');
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Language: $value')));
                }
              },
            ),

            const Divider(),

            Text('Theme', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: <ButtonSegment<String>>[
                ButtonSegment(value: 'system', label: Text(t.system)),
                ButtonSegment(value: 'light', label: Text(t.light)),
                ButtonSegment(value: 'dark', label: Text(t.dark)),
              ],
              selected: _themeSelected,
              onSelectionChanged: (newSelection) {
                final value = newSelection.first;
                setState(() => _themeSelected = {value});
                switch (value) {
                  case 'system':
                    appKey.currentState?.setThemeMode(ThemeMode.system);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Theme: ${t.system}')),
                    );
                    debugPrint('Settings: theme set to system');
                    break;
                  case 'light':
                    appKey.currentState?.setThemeMode(ThemeMode.light);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Theme: ${t.light}')),
                    );
                    debugPrint('Settings: theme set to light');
                    break;
                  case 'dark':
                    appKey.currentState?.setThemeMode(ThemeMode.dark);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Theme: ${t.dark}')));
                    debugPrint('Settings: theme set to dark');
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
