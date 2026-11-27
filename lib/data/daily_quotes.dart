/// Short encouragement lines for the daily revision reminder.
///
/// Kept separate from the home-screen quotes so the notification can use its
/// own set without pulling widget code into a platform service.
const List<String> dailyQuotes = <String>[
  'Repetition is the mother of learning.',
  'Small steps every day beat cramming every way.',
  'You remember what you retrieve, not what you reread.',
  'Consistency compounds. Show up again tomorrow.',
  'A card a day keeps forgetting away.',
  'Focus on the card in front of you.',
  'Mastery is built one honest review at a time.',
  'Five minutes now saves an hour later.',
  'Every review is a vote for the future you.',
  'Recall is the workout, rereading is only the warm-up.',
];

/// A stable quote for each calendar day.
String quoteForDay(DateTime day) {
  final dayOfYear = DateTime(day.year, day.month, day.day)
      .difference(DateTime(day.year))
      .inDays;
  return dailyQuotes[dayOfYear % dailyQuotes.length];
}
