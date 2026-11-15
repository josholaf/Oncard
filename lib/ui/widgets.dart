import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../data/app_data.dart';
import '../data/models.dart';
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

/// Pill badge for due/new counts.
class CountBadge extends StatelessWidget {
  final String label;
  final Color color;
  const CountBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? lightenForDark(color)
        : color;
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with icon and hint.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title. $subtitle',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: Icon(icon,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small statistic card used on Home and Stats.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? color;
  const StatCard(
      {super.key,
      required this.icon,
      required this.value,
      required this.label,
      this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = color ?? cs.primary;
    final shown = Theme.of(context).brightness == Brightness.dark
        ? lightenForDark(tint)
        : tint;
    return Semantics(
      label: '$label: $value',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: shown.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: shown),
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

String iconBase(String icon) {
  final at = icon.indexOf('@');
  return at == -1 ? icon : icon.substring(0, at);
}

Color? iconTint(String icon) {
  final at = icon.indexOf('@');
  if (at == -1) return null;
  final hex = icon.substring(at + 1);
  if (hex.length != 7 || !hex.startsWith('#')) return null;
  final value = int.tryParse('FF${hex.substring(1)}', radix: 16);
  return value == null ? null : Color(value);
}

class DeckIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color? color;
  const DeckIcon({super.key, required this.icon, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final base = iconBase(icon);
    final tint = color ?? iconTint(icon);
    if (base.startsWith('lucide:')) {
      return LucideIcon(name: base.substring(7), size: size, color: tint);
    }
    return Text(base, style: TextStyle(fontSize: size, color: tint));
  }
}

class DeckAvatar extends StatelessWidget {
  final String icon;
  final int colorIndex;
  final double size;
  const DeckAvatar(
      {super.key, required this.icon, required this.colorIndex, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final base = iconTint(icon) ??
        deckPalette[colorIndex % deckPalette.length];
    final tint = Theme.of(context).brightness == Brightness.dark
        ? lightenForDark(base)
        : base;
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: DeckIcon(
          icon: icon,
          size: size * 0.8,
          color: tint,
        ),
      ),
    );
  }
}
