import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              selected: <String>{
                if (appKey.currentState?.locale == null)
                  'system'
                else
                  appKey.currentState!.locale!.languageCode,
              },
              onSelectionChanged: (newSelection) {
                final value = newSelection.first;
                if (value == 'system') {
                  appKey.currentState?.setLocale(null);
                } else {
                  appKey.currentState?.setLocale(Locale(value));
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
              selected: <String>{
                switch (appKey.currentState?.themeMode) {
                  ThemeMode.light => 'light',
                  ThemeMode.dark => 'dark',
                  _ => 'system',
                },
              },
              onSelectionChanged: (newSelection) {
                final value = newSelection.first;
                switch (value) {
                  case 'system':
                    appKey.currentState?.setThemeMode(ThemeMode.system);
                    break;
                  case 'light':
                    appKey.currentState?.setThemeMode(ThemeMode.light);
                    break;
                  case 'dark':
                    appKey.currentState?.setThemeMode(ThemeMode.dark);
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
