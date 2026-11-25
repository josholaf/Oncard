import 'package:flutter/material.dart';

import 'lucide_icons.dart';
import 'theme.dart';

export 'study_heatmap.dart';

/// Five small dots showing how deep a card's memory trace is.
class MasteryDots extends StatelessWidget {
  final int mastery;
  const MasteryDots({super.key, required this.mastery});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Mastery $mastery of 5',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final filled = i < mastery;
          return Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? cs.primary : cs.surfaceContainerHighest,
            ),
          );
        }),
      ),
    );
  }
}
