import 'dart:convert';

import 'models.dart';

/// User-facing daily revision reminder configuration.
///
/// Persisted as one JSON blob under a single prefs key so the settings
/// shape can grow without scattering new keys across the app.
class ReminderSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const ReminderSettings({
    this.enabled = false,
    this.hour = 19,
    this.minute = 0,
  });

  factory ReminderSettings.fromJson(Map<String, dynamic> json) =>
      ReminderSettings(
        enabled: json['enabled'] == true,
        hour: ((json['hour'] as num?) ?? 19).clamp(0, 23).toInt(),
        minute: ((json['minute'] as num?) ?? 0).clamp(0, 59).toInt(),
      );

  factory ReminderSettings.fromJsonString(String raw) {
    try {
      return ReminderSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const ReminderSettings();
    }
  }

  Map<String, dynamic> toJson() =>
      <String, dynamic>{'enabled': enabled, 'hour': hour, 'minute': minute};

  ReminderSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ReminderSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// The deck that owns the earliest-due card across all decks.
///
/// Falls back to the first deck with any card, so the reminder always has a
/// useful tap target. Returns null only when there are no cards at all.
Deck? deckOfTheDay(List<Deck> decks) {
  Deck? best;
  int bestDue = -1;
  for (final deck in decks) {
    int? earliest;
    for (final card in deck.cards) {
      if (!card.isDue) continue;
      if (earliest == null || card.due < earliest) earliest = card.due;
    }
    if (earliest == null) continue;
    if (best == null || earliest < bestDue) {
      best = deck;
      bestDue = earliest;
    }
  }
  if (best != null) return best;
  for (final deck in decks) {
    if (deck.cards.isNotEmpty) return deck;
  }
  return null;
}

/// The question shown in the notification body, earliest due card first.
String? dueQuestion(List<Deck> decks) {
  String? best;
  int bestDue = -1;
  for (final deck in decks) {
    for (final card in deck.cards) {
      if (!card.isDue) continue;
      if (best == null || card.due < bestDue) {
        best = card.question;
        bestDue = card.due;
      }
    }
  }
  return best;
}
