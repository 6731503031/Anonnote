import 'package:flutter/material.dart';

class TagChip extends StatelessWidget {
  final String tag;
  const TagChip({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Use primary-based tint for chip backgrounds, but keep low opacity
    final base = colorScheme.primary;
    final bg = base.withValues(alpha: isDark ? 0.12 : 0.10);
    final textColor = isDark ? Colors.lightBlueAccent : colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        // subtle border to ensure separation on similar backgrounds
        border: Border.all(color: base.withValues(alpha: isDark ? 0.14 : 0.12)),
      ),
      child: Text(
        '#${tag.trim()}',
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
