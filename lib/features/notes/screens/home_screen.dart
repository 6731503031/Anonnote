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
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: t.settings,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: t.add,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateNoteScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
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
            child: StreamBuilder<List<NoteModel>>(
              stream: service.getNotes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
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
                      n.title.toLowerCase().contains(_query.toLowerCase()) ||
                      n.tags.any(
                        (t) => t.toLowerCase().contains(_query.toLowerCase()),
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
                        Icon(
                          Icons.note_add,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t.noNotes,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.createNote,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                // Tag chips and list
                final tagList = allTags.toList()..sort();

                return Column(
                  children: [
                    if (tagList.isNotEmpty)
                      SizedBox(
                        height: 56,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: const Text('All'),
                                selected: _selectedTag == null,
                                onSelected: (s) => setState(
                                  () => _selectedTag = s ? null : _selectedTag,
                                ),
                              ),
                            ),
                            for (final tag in tagList)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ChoiceChip(
                                  label: Text(tag),
                                  selected: _selectedTag == tag,
                                  onSelected: (s) => setState(
                                    () => _selectedTag = s ? tag : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          final note = notes[index];

                          return Dismissible(
                            key: ValueKey(note.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Theme.of(context).colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (_) {
                              service.deleteNote(note.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${note.title.isEmpty ? t.untitledNote : note.title} deleted',
                                  ),
                                  action: SnackBarAction(
                                    label: 'Undo',
                                    onPressed: () async {
                                      await service.createNote(note);
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    note.title.isNotEmpty
                                        ? note.title[0].toUpperCase()
                                        : '?',
                                  ),
                                ),
                                title: Text(
                                  note.title.isEmpty
                                      ? t.untitledNote
                                      : note.title,
                                ),
                                subtitle: Text(note.tags.join(', ')),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  tooltip: t.delete,
                                  onPressed: () => service.deleteNote(note.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
