import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../services/note_service.dart';
import '../models/note_model.dart';
import 'create_note_screen.dart';
import 'note_detail_screen.dart';
import '../../settings/settings_screen.dart';
// Dev sign-in removed for production

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  String? _selectedTag;

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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.appTitle,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(fontSize: 20),
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
                child: Row(
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
                    const SizedBox(width: 8),
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

                        final notes = data.where((n) {
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
                          return matchesQuery && matchesTag;
                        }).toList();

                        if (notes.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  t.noNotes,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 8),
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
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            NoteDetailScreen(note: note),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            note.title.isEmpty
                                                ? t.untitledNote
                                                : note.title,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Text(
                                              _previewForContent(note.content),
                                              maxLines: 6,
                                              overflow: TextOverflow.ellipsis,
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
