import 'package:flutter/material.dart';

class TopActionCard extends StatelessWidget {
  final Widget child;
  const TopActionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.onSurface.withAlpha(18);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
      color: theme.cardColor,
      child: child,
    );
  }
}
