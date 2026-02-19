import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../services/note_service.dart';
import '../models/note_model.dart';
import 'create_note_screen.dart';
import '../../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _query = '';
  String? _selectedTag;

  @override
  Widget build(BuildContext context) {
    final service = NoteService();
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      // We draw a custom background (dark gradient) to match the mock.
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.surface.withAlpha(230),
              Theme.of(context).colorScheme.surface.withAlpha(210),
            ],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // AppBar row
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
                    Row(
                      children: [
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
                  ],
                ),
              ),

              // Hero / header area
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 28.0,
                  horizontal: 24.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.appTitle,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
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
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateNoteScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        backgroundColor: Colors.blue[600],
                      ),
                      child: Text(
                        t.createNoteCTA,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Search row
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

              // Notes area (stream)
              Expanded(
                child: Builder(
                  builder: (context) {
                    // Protect tests and startup from Firebase not being initialized.
                    // If getting the real stream throws, fall back to an empty list stream.
                    late final Stream<List<NoteModel>> notesStream;
                    try {
                      notesStream = service.getNotes();
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

                        final data = snapshot.data ?? [];

                        // build dynamic tag list for filter menu
                        final allTags = <String>{};
                        for (final n in data) {
                          allTags.addAll(n.tags);
                        }

                        // Filter notes by query and selected tag
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

                        // Tag chips and grid

                        if (notes.isEmpty) {
                          // Large hero empty state like the provided mock
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 760,
                                  child: Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 40.0,
                                        horizontal: 24.0,
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            t.appTitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .displaySmall
                                                ?.copyWith(
                                                  fontSize: 48,
                                                  color: Colors.white,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            t.heroSubtitle,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 18),
                                          ElevatedButton(
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const CreateNoteScreen(),
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 36,
                                                    vertical: 14,
                                                  ),
                                              backgroundColor: Colors.blue[600],
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              t.createNoteCTA,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Render notes as a responsive grid
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 1;
                              final width = constraints.maxWidth;
                              if (width > 1200) {
                                crossAxisCount = 4;
                              } else if (width > 900) {
                                crossAxisCount = 3;
                              } else if (width > 600) {
                                crossAxisCount = 2;
                              } else {
                                crossAxisCount = 1;
                              }

                              return GridView.builder(
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    elevation: 6,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const CreateNoteScreen(),
                                          ),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
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
                                                (note.content is List)
                                                    ? '[rich text]'
                                                    : '${note.content}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withAlpha(200),
                                                    ),
                                                maxLines: 6,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: note.tags
                                                  .take(4)
                                                  .map(
                                                    (tag) => Chip(
                                                      label: Text(tag),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ); // end GridView.builder
                            }, // end LayoutBuilder builder
                          ), // end LayoutBuilder
                        ); // end Padding
                      }, // end StreamBuilder builder
                    ); // end StreamBuilder
                  },
                ), // end Builder
              ), // end Expanded
            ],
          ),
        ),
      ),
    );
  }
}
