import 'package:flutter/material.dart';

class ColorPickerWidget extends StatelessWidget {
  final List<Color> colors;
  final Color? selected;
  final ValueChanged<Color> onSelected;
  const ColorPickerWidget({
    super.key,
    required this.colors,
    this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colors.map((c) {
        final isSel = selected != null && selected!.toARGB32() == c.toARGB32();
        return GestureDetector(
          onTap: () => onSelected(c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: isSel ? 44 : 40,
            height: isSel ? 44 : 40,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: isSel
                  ? Border.all(color: Colors.black26, width: 2)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
