import 'package:flutter/material.dart';

import '../data/app_data.dart';
import '../data/models.dart';

/// Full-year study activity calendar with horizontal scrolling.
///
/// - January → December for the current year
/// - Columns are weeks; rows are Monday → Sunday
/// - Fixed, readable cell size; the year scrolls horizontally
/// - Purple intensity is independent of the app theme color
class StudyHeatmap extends StatelessWidget {
  final Map<String, DayLog> byDate;
  final int dailyGoal;
  final bool compact;

  const StudyHeatmap({
    super.key,
    required this.byDate,
    this.dailyGoal = 20,
    this.compact = false,
  });

  static const List<Color> _purpleLight = <Color>[
    Color(0xFFEDE7F6),
    Color(0xFFD1C4E9),
    Color(0xFFB39DDB),
    Color(0xFF9575CD),
    Color(0xFF673AB7),
  ];

  static const List<Color> _purpleDark = <Color>[
    Color(0xFF30283A),
    Color(0xFF493765),
    Color(0xFF654A91),
    Color(0xFF8462BD),
    Color(0xFFB69AE8),
  ];

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = <String>[
    'Mon', '', 'Wed', '', 'Fri', '', '',
  ];

  int levelFor(int count, int goal) {
    if (count <= 0) return 0;
    final g = goal.clamp(5, 200);
    if (count < (g * 0.4).ceil()) return 1;
    if (count < g) return 2;
    if (count <= (g * 1.4).ceil()) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final palette = isDark ? _purpleDark : _purpleLight;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yearStart = DateTime(now.year, 1, 1);
    final yearEnd = DateTime(now.year, 12, 31);

    // Monday of the week that contains Jan 1 through the Monday of the
    // week that contains Dec 31 → 52 or 53 columns.
    final firstMonday =
        yearStart.subtract(Duration(days: yearStart.weekday - 1));
    final lastMonday =
        yearEnd.subtract(Duration(days: yearEnd.weekday - 1));
    final weekCount = lastMonday.difference(firstMonday).inDays ~/ 7 + 1;

    int countOn(DateTime date) => byDate[dayKey(date)]?.reviewed ?? 0;

    var activeDays = 0;
    var heavyDays = 0;
    for (var day = 0; day < 366; day++) {
      final date = yearStart.add(Duration(days: day));
      if (date.year != now.year || date.isAfter(today)) break;
      final count = countOn(date);
      if (count > 0) activeDays++;
      if (levelFor(count, dailyGoal) == 4) heavyDays++;
    }

    final caption = activeDays == 0
        ? 'Your study activity for this year will appear here.'
        : heavyDays > activeDays * 0.25
            ? 'Several heavy study days. Short, regular sessions can be easier to sustain.'
            : activeDays >= 20
                ? 'A steady pace. Consistency beats last-minute cramming.'
                : 'Every study session counts. Keep building the habit.';

    // Fixed, readable cell size. The calendar scrolls horizontally instead
    // of shrinking every week to fit the screen.
    final cellSize = compact ? 11.0 : 14.0;
    final gap = compact ? 3.0 : 4.0;
    final columnWidth = cellSize + gap;
    final rowHeight = cellSize + gap;
    final labelWidth = compact ? 26.0 : 32.0;

    // Build month labels positioned over their first week.
    final monthSpans = <_MonthSpan>[];
    for (var month = 1; month <= 12; month++) {
      final firstOfMonth = DateTime(now.year, month, 1);
      final weekIndex = firstOfMonth.difference(firstMonday).inDays ~/ 7;
      monthSpans.add(_MonthSpan(label: _months[month - 1], weekIndex: weekIndex));
    }

    final columns = <Widget>[];
    for (var week = 0; week < weekCount; week++) {
      final cells = <Widget>[];
      for (var weekday = 0; weekday < 7; weekday++) {
        final date = firstMonday.add(Duration(days: week * 7 + weekday));
        final inThisYear = date.year == now.year;
        final isFuture = date.isAfter(today);
        final count = inThisYear ? countOn(date) : 0;
        final level = (!inThisYear || isFuture)
            ? -1
            : levelFor(count, dailyGoal);

        final Color fill = level < 0
            ? Colors.transparent
            : level == 0
                ? (isDark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.55)
                    : const Color(0xFFF1F0F3))
                : palette[level];

        final dateLabel = '${_months[date.month - 1]} ${date.day}, ${date.year}';
        final tooltip = !inThisYear
            ? dateLabel
            : isFuture
                ? '$dateLabel · Future'
                : '$dateLabel · $count review${count == 1 ? '' : 's'}';

        cells.add(
          SizedBox(
            width: columnWidth,
            height: rowHeight,
            child: Center(
              child: Tooltip(
                message: tooltip,
                child: Semantics(
                  label: tooltip,
                  child: Container(
                    width: cellSize,
                    height: cellSize,
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(cellSize * 0.22),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      columns.add(
        SizedBox(
          width: columnWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: cells,
          ),
        ),
      );
    }

    final labels = Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        7,
        (index) => SizedBox(
          width: labelWidth,
          height: rowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _weekdays[index],
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: compact ? 9 : 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );

    final totalWidth = weekCount * columnWidth;

    return Semantics(
      container: true,
      label: 'Study activity for ${now.year}. $activeDays active days. $caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month labels + scrollable grid share the same horizontal scroll.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sticky weekday labels
              labels,
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: totalWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Month row
                        SizedBox(
                          height: compact ? 16 : 18,
                          child: Stack(
                            children: [
                              for (final span in monthSpans)
                                Positioned(
                                  left: span.weekIndex * columnWidth,
                                  child: Text(
                                    span.label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: compact ? 10 : 11,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 4),
                        // Week columns
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: columns,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 14),
          // Legend
          Row(
            children: [
              Text(
                'Less',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              for (var i = 0; i < palette.length; i++)
                Container(
                  width: compact ? 11 : 13,
                  height: compact ? 11 : 13,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? (isDark
                            ? theme.colorScheme.surfaceContainerHighest
                                .withOpacity(0.55)
                            : const Color(0xFFF1F0F3))
                        : palette[i],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              Text(
                'More',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSpan {
  final String label;
  final int weekIndex;
  const _MonthSpan({required this.label, required this.weekIndex});
}
