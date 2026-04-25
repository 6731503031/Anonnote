import 'package:flutter/material.dart';
import '../features/notes/models/note_model.dart';
// HiddenUnlockService not used in the card — PIN is required on open.
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import 'tag_chip.dart';

class NoteCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavorite;
  const NoteCard({
    super.key,
    required this.note,
    this.onTap,
    this.onLongPress,
    this.onFavorite,
  });

  static const _colors = <Color>[
    Color(0xFFFBF8FF), // pastel purple
    Color(0xFFFFFBF0), // pastel yellow
    Color(0xFFF0FFF4), // pastel green
    Color(0xFFF0F7FF), // pastel blue
    Color(0xFFFFF0F6), // pastel pink
    Color(0xFFF7FFF9), // pastel mint
    Color(0xFFF6F6F9), // neutral light
  ];

  Color _resolveColor(BuildContext context) {
    if (note.colorHex != null && note.colorHex!.isNotEmpty) {
      try {
        return Color(int.parse(note.colorHex!.replaceFirst('#', '0xff')));
      } catch (_) {}
    }
    // pick by id hash to give deterministic color
    final idx = note.id.hashCode.abs() % _colors.length;
    return _colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor(context);
    final theme = Theme.of(context);
    // For security, hidden notes must never reveal preview text here. The
    // unlock check happens when opening the note detail screen which will
    // prompt for PIN every time. Always redact previews in the card itself.

    // Compute a readable foreground color for text on this card background.
    final titleColor = AppTheme.readableForeground(color);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      note.title.isEmpty ? 'Untitled' : note.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onFavorite,
                    child: Icon(
                      note.isFavorite ? Icons.star : Icons.star_border,
                      size: 18,
                      color: note.isFavorite
                          ? Colors.amber
                          : AppTheme.readableForeground(
                              color,
                            ).withValues(alpha: 0.6),
                    ),
                  ),
                  if (note.isHidden) const SizedBox(width: 6),
                  if (note.isHidden) const Icon(Icons.lock_outline, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              if (note.isHidden)
                Tooltip(
                  message: AppLocalizations.of(context)!.lockedNote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.readableForeground(
                        color,
                      ).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: AppTheme.readableForeground(color),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.locked,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.readableForeground(color),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (note.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: note.tags
                      .take(3)
                      .map((t) => TagChip(tag: t))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // previews are intentionally not extracted in the card for security.
}
