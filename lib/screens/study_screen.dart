import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../services/audio.dart';
import '../ui/cloze.dart';
import '../data/models.dart';
import '../ui/occlusion.dart';
import '../ui/rich_text.dart';
import '../data/scheduler.dart';

/// The way to study a deck: flip cards.
enum StudyMode { flip }

/// Lazily created text-to-speech engine. Never constructed unless the user
/// enables TTS in settings, so tests and non-supported platforms are safe.
class Tts {
  static FlutterTts? _instance;

  static Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      final tts = _instance ??= FlutterTts();
      // No pinned language: the platform's own native voice speaks,
      // following the device language and installed voices.
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // TTS unavailable on this platform: silently ignore.
    }
  }

  static void stop() {
    try {
      _instance?.stop();
    } catch (_) {
      // ignore
    }
  }
}

class StudyScreen extends StatefulWidget {
  final Deck deck;
  final StudyMode mode;
  const StudyScreen({super.key, required this.deck, required this.mode});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final List<Flashcard> _queue;
  final List<Grade> _grades = <Grade>[];
  final List<Flashcard> _skippedCards = <Flashcard>[];
  int _index = 0;
  int _skippedTotal = 0;
  bool _showBack = false;
  bool _reviewingSkipped = false;
  bool _audioPlaying = false;
  bool _audioStarted = false;
  double _horizontalDrag = 0;

  @override
  void initState() {
    super.initState();
    _queue = widget.deck.cards.where((c) => c.isDue).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    CardAudio.setOnCompleted(() {
      if (!mounted) return;
      setState(() {
        _audioPlaying = false;
        _audioStarted = false;
      });
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    Tts.stop();
    CardAudio.setOnCompleted(null);
    unawaited(CardAudio.stop());
    super.dispose();
  }

  bool get _finished => _index >= _queue.length;

  int get _known => _grades.where((g) => g != Grade.again).length;

  int get _total => _grades.length;

  int get _againCount => _grades.where((g) => g == Grade.again).length;

  int get _remaining =>
      (_queue.length - _index).clamp(0, _queue.length);

  void _advance(Grade grade) {
    final card = _queue[_index];
    context.read<AppData>().recordReview(widget.deck.id, card, grade);
    setState(() => _grades.add(grade));
  }

  Future<void> _stopAudio() async {
    await CardAudio.stop();
    _audioPlaying = false;
    _audioStarted = false;
  }

  Future<void> _next({bool stopAudio = true}) async {
    if (stopAudio) await _stopAudio();
    if (!mounted) return;
    _flip.stop();
    _flip.value = 0;
    setState(() {
      _showBack = false;
      _index += 1;
    });
  }

  Future<void> _skipCurrent() async {
    if (_finished) return;
    await _stopAudio();
    if (!mounted || _finished) return;
    _flip.stop();
    _flip.value = 0;
    setState(() {
      _skippedCards.add(_queue[_index]);
      _skippedTotal += 1;
      _showBack = false;
      _index += 1;
    });
  }

  void _reviewSkipped() {
    if (_skippedCards.isEmpty) return;
    _flip.stop();
    _flip.value = 0;
    setState(() {
      _queue
        ..clear()
        ..addAll(_skippedCards);
      _skippedCards.clear();
      _index = 0;
      _showBack = false;
      _reviewingSkipped = true;
    });
  }

  Future<void> _gradeAndAdvance(Grade grade) async {
    _advance(grade);
    if (grade == Grade.again) {
      _queue.add(_queue[_index]); // relearn later in the session
    }
    await _stopAudio();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await _next(stopAudio: false);
  }

  Future<void> _toggleAudio(String path) async {
    if (_audioPlaying) {
      final paused = await CardAudio.pause();
      if (!mounted) return;
      if (paused) setState(() => _audioPlaying = false);
      return;
    }

    final started = _audioStarted
        ? await CardAudio.resume()
        : await CardAudio.play(path);
    if (!mounted) return;
    if (started) {
      setState(() {
        _audioPlaying = true;
        _audioStarted = true;
      });
    }
  }

  void _flipCard() {
    if (_showBack) {
      _flip.reverse();
    } else {
      _flip.forward();
      final card = _queue[_index];
      if (context.read<AppData>().ttsEnabled && card.answer.isNotEmpty) {
        Tts.speak(RichMarkup.stripMarkup(card.answer));
      }
    }
    setState(() => _showBack = !_showBack);
  }

  Widget _answerContent(BuildContext context, Flashcard card) {
    if (Cloze.hasCloze(card.question)) {
      return Text.rich(
        TextSpan(
          style: Theme.of(context).textTheme.headlineSmall,
          children: Cloze.revealSpans(
            card.question,
            card.clozeIndex,
            Theme.of(context).textTheme.headlineSmall ?? const TextStyle(),
          ),
        ),
        textAlign: TextAlign.center,
      );
    }
    return RichAnswer(
      text: card.answer,
      style: Theme.of(context).textTheme.headlineSmall ?? const TextStyle(),
    );
  }

  Widget _face(BuildContext context, bool back) {
    final card = _queue[_index];
    final cs = Theme.of(context).colorScheme;
    final showImage = card.imagePath != null &&
        (card.occlusions.isNotEmpty ||
            card.imageSide == (back ? CardSide.back : CardSide.front));
    if (showImage) {
      return _imageFace(context, card, back);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: back ? cs.secondaryContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          back
              ? _answerContent(context, card)
              : Text(
                  Cloze.blanked(card.question, card.clozeIndex),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
          if (back && card.note.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(card.note,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (card.audioPath != null &&
              card.audioSide == (back ? CardSide.back : CardSide.front)) ...[
            const SizedBox(height: 12),
            _audioControl(card),
          ],
          if (card.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in card.tags)
                  Chip(label: Text(t), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _imageFace(BuildContext context, Flashcard card, bool back) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.passthrough,
              children: [
                Image.file(
                  cardFile(card.imagePath!),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 120,
                    child: Center(child: Text('Image not available')),
                  ),
                ),
                if (card.occlusions.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: OcclusionPainter(
                        rects: card.occlusions,
                        revealed: back,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (back && card.occlusions.isEmpty)
            _answerContent(context, card)
          else
            Text(card.question,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
          if (back && card.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(card.note,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (card.audioPath != null &&
              card.audioSide == (back ? CardSide.back : CardSide.front)) ...[
            const SizedBox(height: 12),
            _audioControl(card),
          ],
          if (card.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final tag in card.tags)
                  Chip(label: Text(tag), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _audioControl(Flashcard card) {
    return OutlinedButton.icon(
      onPressed: () => _toggleAudio(card.audioPath!),
      icon: Icon(_audioPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
      label: Text(_audioPlaying ? 'Pause audio' : 'Play audio'),
    );
  }

  Widget _flipMode(BuildContext context) {
    final card = _queue[_index];
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _flipCard,
            onHorizontalDragStart: (_) => _horizontalDrag = 0,
            onHorizontalDragUpdate: (details) =>
                _horizontalDrag += details.delta.dx,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              final shouldSkip = _horizontalDrag > 80 || velocity > 450;
              _horizontalDrag = 0;
              if (shouldSkip) unawaited(_skipCurrent());
            },
            child: AnimatedBuilder(
              animation: _flip,
              builder: (context, child) {
                final showingFront = _flip.value < 0.5;
                final angle = _flip.value * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(
                        showingFront ? angle : angle - math.pi),
                  child: showingFront
                      ? _face(context, false)
                      : _face(context, true),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Swipe right to skip',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        if (!_showBack)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _flipCard,
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Show answer'),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _gradeButton(
                  context,
                  'Again',
                  Scheduler.intervalLabel(card, Grade.again),
                  const Color(0xFF9C4146),
                  () => _gradeAndAdvance(Grade.again),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gradeButton(
                  context,
                  'Hard',
                  Scheduler.intervalLabel(card, Grade.hard),
                  const Color(0xFFD99A42),
                  () => _gradeAndAdvance(Grade.hard),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gradeButton(
                  context,
                  'Good',
                  Scheduler.intervalLabel(card, Grade.good),
                  const Color(0xFF39845B),
                  () => _gradeAndAdvance(Grade.good),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _gradeButton(
                  context,
                  'Easy',
                  Scheduler.intervalLabel(card, Grade.easy),
                  const Color(0xFF1565C0),
                  () => _gradeAndAdvance(Grade.easy),
                ),
              ),
            ],
          ),
        if (widget.deck.cards.isEmpty) const SizedBox.shrink(),
      ],
    );
  }

  Widget _gradeButton(BuildContext context, String label, String hint,
      Color color, VoidCallback onPressed) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: color.withOpacity(0.14),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                maxLines: 1,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(hint, maxLines: 1, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return _summary(context);
    }
    final total = _queue.length;
    final cs = Theme.of(context).colorScheme;
    final hintParts = <String>['$_remaining left'];
    if (_againCount > 0) hintParts.add('$_againCount again');
    if (_skippedCards.isNotEmpty) {
      hintParts.add('${_skippedCards.length} skipped');
    }
    if (_reviewingSkipped) hintParts.insert(0, 'Skipped review');
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deck.name),
        actions: [
          IconButton(
            tooltip: 'End session',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Text('${_index + 1} / $total',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child:
                        LinearProgressIndicator(value: (_index + 1) / total),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                hintParts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _flipMode(context)),
          ],
        ),
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final accuracy = _total == 0 ? 0 : (_known / _total * 100).round();
    return Scaffold(
      appBar: AppBar(title: Text(widget.deck.name)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.celebration_rounded, size: 64),
              const SizedBox(height: 16),
              Text('Session complete',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('$_total cards reviewed · $accuracy% correct'),
              if (_skippedTotal > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '$_skippedTotal skips during this session',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (_skippedCards.isNotEmpty) ...[
                Text(
                  '${_skippedCards.length} still skipped · not graded',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  'Skipped cards remain due for review.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              if (_skippedCards.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _reviewSkipped,
                    icon: const Icon(Icons.replay_rounded),
                    label: Text('Review skipped (${_skippedCards.length})'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }
}

/// Real File handle for a stored card image.
File cardFile(String path) => File(path);
