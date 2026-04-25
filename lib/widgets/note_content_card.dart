import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NoteContentCard extends StatelessWidget {
  final quill.QuillController? controller;
  final String? plainText;
  final bool isEmpty;

  const NoteContentCard({
    super.key,
    this.controller,
    this.plainText,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor = isDark ? Colors.grey[300] : Colors.grey[700];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.04))
            : null,
      ),
      child: isEmpty
          ? Center(
              child: Text(
                'No content yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: secondaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : controller != null
          ? DefaultTextStyle(
              style: TextStyle(color: textColor, height: 1.5, fontSize: 15),
              child: quill.QuillEditor(
                controller: controller!,
                focusNode: FocusNode(),
                scrollController: ScrollController(),
                config: quill.QuillEditorConfig(
                  autoFocus: false,
                  expands: false,
                  padding: EdgeInsets.zero,
                ),
              ),
            )
          : Text(
              plainText ?? '',
              style: TextStyle(color: textColor, height: 1.5, fontSize: 15),
            ),
    );
  }
}
