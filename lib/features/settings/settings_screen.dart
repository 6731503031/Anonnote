import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import 'package:flutter/foundation.dart';
import '../notes/services/auth_service.dart';
import '../notes/helpers/note_import_helper.dart';
import '../security/screens/pin_setup_screen.dart';
import '../security/services/pin_lock_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Set<String> _langSelected;
  late Set<String> _themeSelected;
  final PinLockService _pinLockService = PinLockService.instance;
  bool _hasPin = false;
  bool _loadingPinState = true;

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
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    var hasPin = false;
    try {
      hasPin = await _pinLockService.hasPin();
    } catch (_) {
      hasPin = false;
    }
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _loadingPinState = false;
    });
  }

  Future<void> _openPinSetup({required bool changing}) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => PinSetupScreen(isChanging: changing)),
    );
    if (saved != true || !mounted) return;

    await _loadPinState();
    await appKey.currentState?.refreshPinState();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(changing ? 'PIN updated' : 'PIN set successfully'),
      ),
    );
  }

  Future<void> _removePin() async {
    String currentPin = '';
    String error = '';

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Remove PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter current PIN to remove app lock.'),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    onChanged: (value) {
                      currentPin = value.trim();
                      if (error.isNotEmpty) {
                        setDialogState(() => error = '');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '4-digit PIN',
                      errorText: error.isEmpty ? null : error,
                      counterText: '',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final ok = await _pinLockService.verifyPin(currentPin);
                    if (!ok) {
                      setDialogState(() => error = 'Incorrect PIN');
                      return;
                    }
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Remove'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldRemove != true || !mounted) return;

    await _pinLockService.removePin();
    await _loadPinState();
    await appKey.currentState?.refreshPinState();

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN removed')));
  }

  Future<void> _refreshAuthUid() async {
    final user = await authService.signInAnonymously();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          user != null ? 'Signed in: ${user.uid}' : 'Sign-in failed',
        ),
      ),
    );
  }

  Future<void> _importNotes() async {
    try {
      final result = await pickAndImportNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.settings)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
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

            // Debug: show current auth UID when running in debug mode.
            if (kDebugMode)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ListTile(
                  title: const Text('Auth UID (debug)'),
                  subtitle: Text(
                    authService.currentUser?.uid ?? 'not signed in',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh / sign-in anonymously',
                    onPressed: _refreshAuthUid,
                  ),
                ),
              ),

            const Divider(),

            Text('Security', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loadingPinState)
              const LinearProgressIndicator(minHeight: 2)
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(_hasPin ? Icons.lock_reset : Icons.lock_outline),
                title: Text(_hasPin ? 'Change PIN' : 'Set PIN'),
                subtitle: Text(
                  _hasPin
                      ? 'Update your 4-digit app lock PIN'
                      : 'Protect app access with a 4-digit PIN',
                ),
                onTap: () => _openPinSetup(changing: _hasPin),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_open_outlined),
                title: const Text('Remove PIN'),
                subtitle: const Text('Disable app lock'),
                enabled: _hasPin,
                onTap: _hasPin ? _removePin : null,
              ),
            ],

            const Divider(),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('Import Notes'),
              subtitle: const Text('Import .txt or .json into your notes'),
              onTap: _importNotes,
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
