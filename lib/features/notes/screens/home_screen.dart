import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../../../l10n/app_localizations.dart';
import '../services/note_service.dart';
import '../models/note_model.dart';
import 'create_note_screen.dart';
import 'note_detail_screen.dart';
import '../../settings/settings_screen.dart';
import '../../security/services/pin_lock_service.dart';
// Dev sign-in removed for production

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const Duration _hiddenModeReauthTimeout = Duration(minutes: 2);
  static const Duration _expirySweepInterval = Duration(minutes: 1);
  static const Duration _countdownTickInterval = Duration(seconds: 30);

  String _query = '';
  String? _selectedTag;
  bool _showHiddenOnly = false;
  bool _showFavoritesOnly = false;
  final PinLockService _pinLockService = PinLockService.instance;
  DateTime? _lastHiddenPinVerifiedAt;
  final Set<String> _pendingExpiredDeletions = <String>{};
  Timer? _expirySweepTimer;
  Timer? _countdownTimer;
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _isOfflineMode = false;

  Future<void> _toggleFavorite(NoteModel note) async {
    try {
      final service = NoteService();
      await service.updateNote(note.copyWith(isFavorite: !note.isFavorite));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.isFavorite ? 'Removed from favorites' : 'Added to favorites',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update favorite: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivityListener();
    _cleanupExpiredNotes();
    _expirySweepTimer = Timer.periodic(
      _expirySweepInterval,
      (_) => _cleanupExpiredNotes(),
    );
    _countdownTimer = Timer.periodic(_countdownTickInterval, (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _expirySweepTimer?.cancel();
    _countdownTimer?.cancel();
    _connectivitySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _initializeConnectivityListener() async {
    if (kIsWeb) {
      // Some web builds may not have connectivity plugin implementation wired.
      // Keep app stable and default to online UI state on web.
      if (!mounted) return;
      setState(() => _isOfflineMode = false);
      return;
    }

    try {
      final initial = await Connectivity().checkConnectivity();
      _applyConnectivityStatus(initial);
    } catch (_) {
      // Keep current value when plugin is temporarily unavailable.
    }

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _applyConnectivityStatus,
    );
  }

  void _applyConnectivityStatus(dynamic status) {
    bool hasInternet;
    if (status is List<ConnectivityResult>) {
      hasInternet = status.any((r) => r != ConnectivityResult.none);
    } else if (status is ConnectivityResult) {
      hasInternet = status != ConnectivityResult.none;
    } else {
      // Unknown payload shape; avoid false offline warning.
      hasInternet = true;
    }

    if (!mounted) return;
    final nextOffline = !hasInternet;
    if (nextOffline == _isOfflineMode) return;
    setState(() => _isOfflineMode = nextOffline);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Security requirement: always exit hidden mode when app goes background.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (_showHiddenOnly && mounted) {
        setState(() {
          _showHiddenOnly = false;
        });
      }
    }

    if (state == AppLifecycleState.resumed) {
      _cleanupExpiredNotes();
    }
  }

  Future<void> _cleanupExpiredNotes() async {
    try {
      await NoteService().deleteExpiredNotesForCurrentUser();
    } catch (_) {
      // Best-effort cleanup only.
    }
  }

  void _scheduleDeleteExpiredNotes(Iterable<NoteModel> notes) {
    final expiredIds = notes
        .where((n) => n.isExpired)
        .map((n) => n.id)
        .where((id) => id.isNotEmpty && !_pendingExpiredDeletions.contains(id))
        .toList();

    if (expiredIds.isEmpty) return;

    _pendingExpiredDeletions.addAll(expiredIds);

    unawaited(() async {
      try {
        await NoteService().deleteNotesByIds(expiredIds);
      } catch (_) {
        // Best-effort deletion only.
      } finally {
        _pendingExpiredDeletions.removeAll(expiredIds);
      }
    }());
  }

  String _formatRemainingTime(DateTime expiry) {
    final now = DateTime.now();
    final remaining = expiry.difference(now);
    if (remaining <= Duration.zero) return 'Expired';

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h left';
    }
    if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${minutes}m left';
    }
    if (remaining.inMinutes > 0) {
      return '${remaining.inMinutes}m left';
    }
    return '<1m left';
  }

  bool get _isHiddenPinStillFresh {
    final last = _lastHiddenPinVerifiedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) <= _hiddenModeReauthTimeout;
  }

  Future<void> _enterHiddenMode() async {
    // Re-PIN required whenever timeout has elapsed.
    if (_isHiddenPinStillFresh) {
      if (!mounted) return;
      setState(() {
        _showHiddenOnly = true;
      });
      return;
    }
    final unlocked = await _verifyHiddenPin();
    if (!mounted || !unlocked) return;
    setState(() {
      _showHiddenOnly = true;
    });
  }

  Future<bool> _verifyHiddenPin() async {
    final hasPin = await _pinLockService.hasPin();
    if (!mounted) return false;

    if (!hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set a PIN in Settings to access hidden notes.'),
        ),
      );
      return false;
    }

    String pin = '';
    String error = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Enter PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter your PIN to view hidden notes.'),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    onChanged: (value) {
                      pin = value.trim();
                      if (error.isNotEmpty) {
                        setDialogState(() => error = '');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: '4-digit PIN',
                      counterText: '',
                      errorText: error.isEmpty ? null : error,
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
                    final valid = await _pinLockService.verifyPin(pin);
                    if (!valid) {
                      setDialogState(() => error = 'Incorrect PIN');
                      return;
                    }
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return false;
    if (ok == true) {
      _lastHiddenPinVerifiedAt = DateTime.now();
      return true;
    }
    return false;
  }

  Future<void> _openNote(NoteModel note) async {
    if (!note.isHidden || _isHiddenPinStillFresh) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
      );
      return;
    }

    final unlocked = await _verifyHiddenPin();
    if (!mounted || !unlocked) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
    );
  }

  void _exitHiddenMode() {
    setState(() {
      _showHiddenOnly = false;
    });
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });
  }

  String _previewForContent(dynamic content, {int maxChars = 300}) {
    // If content is saved as a Quill delta JSON (List of ops), extract insert strings.
    if (content is List) {
      final buffer = StringBuffer();
      for (final op in content) {
        if (op is Map && op.containsKey('insert')) {
          final ins = op['insert'];
          if (ins is String) buffer.write(ins);
        } else if (op is String) {
          buffer.write(op);
        }
        if (buffer.length > maxChars) break;
      }
      final text = buffer.toString().replaceAll('\n', ' ').trim();
      if (text.length > maxChars) return '${text.substring(0, maxChars)}…';
      return text;
    }

    // Otherwise assume it's already a plain string.
    if (content is String) {
      final text = content.replaceAll('\n', ' ').trim();
      return text.length > maxChars ? '${text.substring(0, maxChars)}…' : text;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    final service = NoteService();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface.withAlpha(230),
              Theme.of(context).colorScheme.surface.withAlpha(210),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_isOfflineMode)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(32),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withAlpha(120)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Offline Mode',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'web/logo.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          t.appTitle,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(fontSize: 20),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      tooltip: t.settings,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 24.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        'web/logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t.appTitle,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.heroSubtitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(190),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (!_showHiddenOnly)
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateNoteScreen(),
                          ),
                        ),
                        child: Text(t.createNoteCTA),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: t.searchHint,
                              prefixIcon: const Icon(Icons.search),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _query = v.trim()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _toggleFavoritesFilter,
                            icon: Icon(
                              _showFavoritesOnly
                                  ? Icons.star
                                  : Icons.star_border_outlined,
                            ),
                            label: Text(
                              _showFavoritesOnly
                                  ? 'All Notes'
                                  : 'Favorites Only',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showHiddenOnly
                                ? _exitHiddenMode
                                : _enterHiddenMode,
                            icon: Icon(
                              _showHiddenOnly
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            label: Text(
                              _showHiddenOnly ? 'All Notes' : 'Hidden Only',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Builder(
                  builder: (context) {
                    late final Stream<List<NoteModel>> notesStream;
                    try {
                      notesStream = service.getNotesForCurrentUser();
                    } catch (_) {
                      notesStream = Stream.value(<NoteModel>[]);
                    }

                    return StreamBuilder<List<NoteModel>>(
                      stream: notesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          final errText =
                              snapshot.error?.toString() ?? 'Unknown error';
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Failed to load notes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(errText, textAlign: TextAlign.center),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: () => setState(() {}),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final data = snapshot.data ?? [];
                        final expiredNotes = data.where((n) => n.isExpired);
                        _scheduleDeleteExpiredNotes(expiredNotes);

                        final notes =
                            data.where((n) {
                              final matchesExpiry = !n.isExpired;
                              final matchesVisibility = _showHiddenOnly
                                  ? n.isHidden
                                  : true;
                              final matchesFavorite =
                                  !_showFavoritesOnly || n.isFavorite;
                              final matchesQuery =
                                  _query.isEmpty ||
                                  n.title.toLowerCase().contains(
                                    _query.toLowerCase(),
                                  ) ||
                                  n.tags.any(
                                    (tag) => tag.toLowerCase().contains(
                                      _query.toLowerCase(),
                                    ),
                                  );
                              final matchesTag =
                                  _selectedTag == null || _selectedTag!.isEmpty
                                  ? true
                                  : n.tags.contains(_selectedTag);
                              return matchesExpiry &&
                                  matchesVisibility &&
                                  matchesFavorite &&
                                  matchesQuery &&
                                  matchesTag;
                            }).toList()..sort((a, b) {
                              if (a.isFavorite != b.isFavorite) {
                                return a.isFavorite ? -1 : 1;
                              }
                              return b.createdAt.compareTo(a.createdAt);
                            });

                        if (notes.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showHiddenOnly
                                      ? 'No hidden notes yet'
                                      : _showFavoritesOnly
                                      ? 'No favorite notes yet'
                                      : t.noNotes,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
                                if (!_showHiddenOnly)
                                  ElevatedButton(
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const CreateNoteScreen(),
                                      ),
                                    ),
                                    child: Text(t.createNoteCTA),
                                  ),
                              ],
                            ),
                          );
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.maxWidth;
                            int crossAxisCount = 1;
                            if (width > 1200) {
                              crossAxisCount = 4;
                            } else if (width > 900) {
                              crossAxisCount = 3;
                            } else if (width > 600) {
                              crossAxisCount = 2;
                            }

                            return GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.2,
                                  ),
                              itemCount: notes.length,
                              itemBuilder: (context, index) {
                                final note = notes[index];
                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 4,
                                  child: InkWell(
                                    onTap: () => _openNote(note),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  note.title.isEmpty
                                                      ? t.untitledNote
                                                      : note.title,
                                                  style: Theme.of(
                                                    context,
                                                  ).textTheme.titleMedium,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (note.isHidden)
                                                const Padding(
                                                  padding: EdgeInsets.only(
                                                    right: 4,
                                                  ),
                                                  child: Icon(
                                                    Icons.lock,
                                                    size: 20,
                                                  ),
                                                ),
                                              IconButton(
                                                icon: Icon(
                                                  note.isFavorite
                                                      ? Icons.star
                                                      : Icons.star_border,
                                                  color: note.isFavorite
                                                      ? Colors.amber
                                                      : null,
                                                ),
                                                tooltip: note.isFavorite
                                                    ? 'Remove favorite'
                                                    : 'Add favorite',
                                                onPressed: () =>
                                                    _toggleFavorite(note),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: note.isHidden
                                                ? Row(
                                                    children: [
                                                      Icon(
                                                        Icons.lock_outline,
                                                        color: Theme.of(
                                                          context,
                                                        ).colorScheme.primary,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Hidden note (PIN required)',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .bodyMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : Text(
                                                    _previewForContent(
                                                      note.content,
                                                    ),
                                                    maxLines: 6,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                                  ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 6,
                                            children: note.tags
                                                .take(4)
                                                .map(
                                                  (tag) =>
                                                      Chip(label: Text(tag)),
                                                )
                                                .toList(),
                                          ),
                                          if (note.expireAt != null) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              _formatRemainingTime(
                                                note.expireAt!,
                                              ),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
