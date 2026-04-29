import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../settings/settings_screen.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../../security/services/pin_lock_service.dart';
// HiddenUnlockService removed: require PIN on each open for stronger security.
import '../../../widgets/note_card.dart';
import 'create_note_screen.dart';
import 'note_detail_screen.dart';

// HomeScreen: sliver-based, responsive grid of notes.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NoteService _service = NoteService();
  final PinLockService _pinLockService = PinLockService.instance;

  StreamSubscription? _connectivitySub;
  bool _isOfflineMode = false;

  String _query = '';
  String? _selectedTag;
  bool _showHiddenOnly = false;
  bool _showFavoritesOnly = false;

  // No persistent unlock state: require PIN for each open.

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((event) {
      // Some versions of connectivity_plus deliver a single ConnectivityResult,
      // others may deliver a list. Handle both safely.
      bool isNone = false;
      try {
        final iterable = event as Iterable;
        isNone = iterable.isEmpty;
      } catch (_) {
        final name = event.toString().toLowerCase();
        isNone = name.contains('none');
      }
      setState(() {
        _isOfflineMode = isNone;
      });
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  // no persistent unlock state

  Future<bool> _verifyHiddenPin() async {
    String pin = '';
    String error = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Hidden note PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter PIN to view hidden note'),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    onChanged: (value) {
                      pin = value.trim();
                      if (error.isNotEmpty) setDialogState(() => error = '');
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
      // do NOT persist unlock state here; require PIN each time
      return true;
    }
    return false;
  }

  Future<void> _openNote(NoteModel note) async {
    if (note.isHidden) {
      final ok = await _verifyHiddenPin();
      if (!mounted || !ok) return;
    }

    if (!mounted) return;
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

  void _toggleFavorite(NoteModel note) async {
    try {
      final updated = note.copyWith(isFavorite: !note.isFavorite);
      await _service.updateNote(updated);
    } catch (_) {
      // ignore
    }
  }

  void _scheduleDeleteExpiredNotes(Iterable<NoteModel> expired) {
    // no-op: placeholder for any future scheduling logic. Keep idempotent.
  }

  @override
  Widget build(BuildContext context) {
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
          child: CustomScrollView(
            slivers: [
              if (_isOfflineMode)
                SliverToBoxAdapter(
                  child: Container(
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
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

              SliverAppBar(
                pinned: true,
                stretch: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                expandedHeight: MediaQuery.of(context).size.width > 600
                    ? 260
                    : 180,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset(
                            'assets/logo.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          t.appTitle,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.heroSubtitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(190),
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (!_showHiddenOnly)
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreateNoteScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.add),
                            label: Text(t.createNoteCTA),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/logo.png',
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
                      ).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: t.settings,
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
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
                              onChanged: (v) =>
                                  setState(() => _query = v.trim()),
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
                            FilledButton.icon(
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
                              style: FilledButton.styleFrom(
                                backgroundColor: _showFavoritesOnly
                                    ? Colors.amber.shade500
                                    : Colors.grey.shade400,
                                foregroundColor: Colors.black87,
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _showHiddenOnly
                                  ? _exitHiddenMode
                                  : () =>
                                        setState(() => _showHiddenOnly = true),
                              icon: Icon(
                                _showHiddenOnly
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              label: Text(
                                _showHiddenOnly ? 'All Notes' : 'Hidden Only',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _showHiddenOnly
                                    ? Colors.purple.shade500
                                    : Colors.grey.shade400,
                                foregroundColor: _showHiddenOnly
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              StreamBuilder<List<NoteModel>>(
                stream: (() {
                  try {
                    return _service.getNotesForCurrentUser();
                  } catch (_) {
                    return Stream.value(<NoteModel>[]);
                  }
                })(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    final errText =
                        snapshot.error?.toString() ?? 'Unknown error';
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Failed to load notes',
                                style: Theme.of(context).textTheme.titleLarge,
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
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
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
                              FilledButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CreateNoteScreen(),
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: Text(t.createNoteCTA),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }

                  final width = MediaQuery.of(context).size.width;
                  int crossAxisCount = 1;
                  if (width > 1200) {
                    crossAxisCount = 4;
                  } else if (width > 900) {
                    crossAxisCount = 3;
                  } else if (width > 600) {
                    crossAxisCount = 2;
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.all(12),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.2,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final note = notes[index];
                        return NoteCard(
                          note: note,
                          onTap: () => _openNote(note),
                          onLongPress: () => _toggleFavorite(note),
                          onFavorite: () => _toggleFavorite(note),
                        );
                      }, childCount: notes.length),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateNoteScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(t.createNoteCTA),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
