import 'package:flutter/material.dart';

import 'lucide_icons.dart';

/// Opens a simplified icon chooser tuned for decks.
/// Returns 'lucide:<name>' (optionally with '@#RRGGBB') or null if dismissed.
Future<String?> showEmojiPickerSheet(BuildContext context,
    {String current = 'lucide:book-open'}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
      child: _IconLibrarySheet(current: current),
    ),
  );
}

/// Swatches offered under the icon grid.
const List<String> iconSwatches = <String>[
  '#F5F5F5', // white
  '#9E9E9E', // gray
  '#F44336', // red
  '#FF9800', // orange
  '#FFEB3B', // yellow
  '#4CAF50', // green
  '#009688', // teal
  '#2196F3', // blue
  '#E91E63', // pink
];

Color _hexColor(String hex) {
  final value = int.tryParse('FF' + hex.substring(1), radix: 16);
  return Color(value ?? 0xFFFFFFFF);
}

/// Curated quick picks so the user rarely needs the full library.
const List<String> _quickPicks = <String>[
  'book-open',
  'brain',
  'layers',
  'sparkles',
  'rocket',
  'star',
  'heart',
  'zap',
  'flask-conical',
  'stethoscope',
  'pill',
  'atom',
  'code',
  'languages',
  'globe',
  'palette',
  'music',
  'dumbbell',
  'calculator',
  'landmark',
  'cpu',
  'database',
  'lightbulb',
  'compass',
  'trophy',
  'gem',
  'flower',
  'leaf',
  'sun',
  'moon',
];

class _IconLibrarySheet extends StatefulWidget {
  final String current;
  const _IconLibrarySheet({required this.current});

  @override
  State<_IconLibrarySheet> createState() => _IconLibrarySheetState();
}

class _IconLibrarySheetState extends State<_IconLibrarySheet> {
  final _search = TextEditingController();
  String _selectedName = '';
  String? _color;
  List<String> _matches = const <String>[];
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    var base = widget.current;
    final at = base.indexOf('@');
    if (at != -1) {
      final hex = base.substring(at + 1);
      if (iconSwatches.contains(hex)) _color = hex;
      base = base.substring(0, at);
    }
    if (base.startsWith('lucide:') &&
        kLucideIcons.containsKey(base.substring(7))) {
      _selectedName = base.substring(7);
    }
    _filter();
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.removeListener(_filter);
    _search.dispose();
    super.dispose();
  }

  void _filter() {
    final q = _search.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _matches = _showAll
            ? kLucideIcons.keys.toList(growable: false)
            : _quickPicks
                .where((n) => kLucideIcons.containsKey(n))
                .toList(growable: false);
      } else {
        _matches = kLucideIcons.keys
            .where((name) => name.replaceAll('-', ' ').contains(q))
            .toList(growable: false);
      }
    });
  }

  void _done() {
    if (_selectedName.isEmpty) return;
    Navigator.pop(context,
        'lucide:' + _selectedName + (_color == null ? '' : '@' + _color!));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final searching = _search.text.trim().isNotEmpty;

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Choose deck icon',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search (book, brain, rocket…)',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Mode toggle when not searching
            if (!searching)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Quick picks'),
                      selected: !_showAll,
                      onSelected: (_) {
                        setState(() {
                          _showAll = false;
                          _filter();
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('All icons'),
                      selected: _showAll,
                      onSelected: (_) {
                        setState(() {
                          _showAll = true;
                          _filter();
                        });
                      },
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _matches.isEmpty
                  ? const Center(child: Text('Nothing matches that search.'))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5, childAspectRatio: 1),
                      itemCount: _matches.length,
                      itemBuilder: (context, i) {
                        final name = _matches[i];
                        final selected = name == _selectedName;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _selectedName = name),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: selected
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHigh.withOpacity(0.5),
                              border: selected
                                  ? Border.all(color: cs.primary, width: 2)
                                  : null,
                            ),
                            child: Center(
                              child: LucideIcon(
                                  name: name,
                                  size: 28,
                                  color: _color == null
                                      ? cs.onSurface
                                      : _hexColor(_color!)),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Color row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final hex in iconSwatches)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () =>
                              setState(() => _color = _color == hex ? null : hex),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hexColor(hex),
                              border: _color == hex
                                  ? Border.all(color: cs.primary, width: 3)
                                  : Border.all(color: cs.outlineVariant),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedName.isEmpty ? null : _done,
                  child: const Text('Use this icon'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
