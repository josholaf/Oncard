import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/app_data.dart';
import '../services/audio.dart';
import '../ui/cloze.dart';
import '../data/models.dart';
import '../ui/occlusion.dart';
import '../ui/rich_text.dart';
import 'study_screen.dart' show Tts;

/// Create or edit a card. Supports an optional image, tags and TTS preview.
class CardEditorScreen extends StatefulWidget {
  final String deckId;
  final Flashcard? card;
  const CardEditorScreen({super.key, required this.deckId, this.card});

  @override
  State<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends State<CardEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _answerFocus = FocusNode();
  final _questionFocus = FocusNode();
  late final TextEditingController _question =
      TextEditingController(text: widget.card?.question ?? '');
  late final TextEditingController _answer =
      TextEditingController(text: widget.card?.answer ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.card?.note ?? '');
  late final TextEditingController _tags =
      TextEditingController(text: widget.card?.tags.join(', ') ?? '');
  String? _imagePath;
  CardSide _imageSide = CardSide.front;
  late List<double> _occlusions =
      List<double>.from(widget.card?.occlusions ?? const <double>[]);
  String? _audioPath;
  CardSide _audioSide = CardSide.back;
  String? _lastAnswerText;

  bool get _isEditing => widget.card != null;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.card?.imagePath;
    _imageSide = widget.card?.imageSide ?? CardSide.front;
    _audioPath = widget.card?.audioPath;
    _audioSide = widget.card?.audioSide ?? CardSide.back;
    _lastAnswerText = _answer.text;
    _answer.addListener(_autoContinueList);
    _answerFocus.addListener(_onAnswerFocus);
  }

  @override
  void dispose() {
    _answer.removeListener(_autoContinueList);
    _question.dispose();
    _answer.dispose();
    _questionFocus.dispose();
    _answerFocus.dispose();
    _note.dispose();
    _tags.dispose();
    super.dispose();
  }

  void _onAnswerFocus() {
    if (mounted) setState(() {});
  }

  /// Rich-text toolbar for the back side. Sits directly above the keyboard
  /// while the back field is focused, like the reference editor.
  Widget _floatingToolbar() {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Cloze: blank the selected text',
                  icon: const Icon(Icons.visibility_off_rounded),
                  visualDensity: VisualDensity.compact,
                  onPressed: _wrapCloze,
                ),
                _formatButton(Icons.format_bold_rounded, 'Bold',
                    () => RichMarkup.toggleWrap(_answer, '**', '**')),
                _formatButton(Icons.format_italic_rounded, 'Italic',
                    () => RichMarkup.toggleWrap(_answer, '*', '*')),
                _formatButton(Icons.format_underline_rounded, 'Underline',
                    () => RichMarkup.toggleWrap(_answer, '__', '__')),
                _formatButton(Icons.format_list_bulleted_rounded, 'Bullet list',
                    () => _toggleLinePrefix('- ')),
                _formatButton(Icons.format_list_numbered_rounded, 'Numbered list',
                    () => _toggleLinePrefix('1. ')),
                _formatButton(Icons.format_indent_decrease_rounded,
                    'Indent backward', () => _indentLine(-1)),
                _formatButton(Icons.format_indent_increase_rounded,
                    'Indent forward', () => _indentLine(1)),
                PopupMenuButton<String>(
                  tooltip: 'Highlight color',
                  icon: const Icon(Icons.highlight_rounded),
                  onSelected: (name) {
                    RichMarkup.toggleWrap(
                        _answer, name == 'amber' ? '==' : '==$name:', '==');
                    FocusScope.of(context).requestFocus(_answerFocus);
                  },
                  itemBuilder: (_) => [
                    for (final entry in _highlightColors.entries)
                      PopupMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: entry.value,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(entry.key),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 80, maxWidth: 1600);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${dir.path}/card-images')
        ..createSync(recursive: true);
      final name =
          'img_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final saved =
          await File(picked.path).copy('${imagesDir.path}/$name');
      setState(() => _imagePath = saved.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load that image.')));
      }
    }
  }

  Future<void> _attachMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_rounded),
              title: const Text('Image'),
              subtitle: const Text('Pick a picture from the gallery'),
              onTap: () => Navigator.pop(sheetContext, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: const Text('Audio'),
              subtitle: const Text('Pick an audio file (mp3, m4a, wav)'),
              onTap: () => Navigator.pop(sheetContext, 'audio'),
            ),
          ],
        ),
      ),
    );
    if (choice == 'image') await _pickImage();
    if (choice == 'audio') await _pickAudio();
  }

  Future<void> _pickAudio() async {
    try {
      final picked =
          await FilePicker.platform.pickFiles(type: FileType.audio);
      final path = picked?.files.single.path;
      if (path == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final audioDir = Directory(dir.path + '/card-audio')
        ..createSync(recursive: true);
      final name = 'aud_' +
          DateTime.now().millisecondsSinceEpoch.toString() +
          '_' +
          path.split('/').last;
      final saved = await File(path).copy(audioDir.path + '/' + name);
      setState(() => _audioPath = saved.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not load that audio file.')));
      }
    }
  }

  Future<void> _editOcclusions() async {
    final result = await Navigator.push<List<double>>(
      context,
      MaterialPageRoute<List<double>>(
        builder: (_) => OcclusionEditor(
          imagePath: _imagePath!,
          initial: _occlusions,
        ),
      ),
    );
    if (result != null) setState(() => _occlusions = result);
  }

  /// Continues lists on Enter: after a line starting with '- ' the new
  /// line gets '- ' too, after '1. ' it gets '2. ', and so on. Pressing
  /// Enter on an empty list item removes the marker and exits the list.
  void _autoContinueList() {
    final text = _answer.text;
    final old = _lastAnswerText;
    _lastAnswerText = text;
    if (old == null || text.length != old.length + 1) return;
    var at = 0;
    while (at < old.length && old[at] == text[at]) at++;
    if (text[at] != '\n') return;

    final lineStart = old.lastIndexOf('\n', at - 1) + 1;
    final line = old.substring(lineStart, at);
    final m = RegExp('^(\\s*)(- |(\\d+)\\. )').firstMatch(line);
    if (m == null) return;
    final indent = m.group(1) ?? '';
    final marker = m.group(2)!;
    final number = m.group(3);

    // Bare marker on this line: leave the list instead of growing it.
    if (line.trim() == marker.trim()) {
      _answer.value = TextEditingValue(
        text: old.replaceRange(lineStart, at, ''),
        selection: TextSelection.collapsed(offset: lineStart),
      );
      _lastAnswerText = _answer.text;
      return;
    }

    final cont = number == null
        ? indent + '- '
        : indent + (int.parse(number) + 1).toString() + '. ';
    _answer.value = TextEditingValue(
      text: text.replaceRange(at + 1, at + 1, cont),
      selection: TextSelection.collapsed(offset: at + 1 + cont.length),
    );
    _lastAnswerText = _answer.text;
  }

  /// Toggles a line prefix (bullet or numbered) on the answer's line.
  void _toggleLinePrefix(String prefix) {
    _lineEdit((line) {
      if (line.startsWith(prefix)) {
        return line.substring(prefix.length);
      }
      final stripped = line.replaceFirst(RegExp(r'^(- |\d+\. |>*)'), '');
      return prefix + stripped;
    });
  }

  /// Indents (delta 1) or outdents (delta -1) the answer's line.
  void _indentLine(int delta) {
    _lineEdit((line) {
      if (delta > 0) return '>' + line;
      if (line.startsWith('>')) return line.substring(1);
      return line;
    });
  }

  /// Applies [transform] to the line holding the caret in the answer.
  void _lineEdit(String Function(String) transform) {
    final controller = _answer;
    final sel = controller.selection;
    final text = controller.text;
    final s = sel.start < 0 ? text.length : sel.start;
    var lineStart = 0;
    if (s > 0) {
      lineStart = text.lastIndexOf('\n', s - 1) + 1;
    }
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd == -1) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);
    final next = transform(line);
    final caret = s + (next.length - line.length);
    controller.value = TextEditingValue(
      text: text.replaceRange(lineStart, lineEnd, next),
      selection: TextSelection.collapsed(offset: caret),
    );
    setState(() {});
    FocusScope.of(context).requestFocus(_answerFocus);
  }

  List<String> _parseTags(String raw) => raw
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  String _sideLabel(CardSide side) =>
      side == CardSide.front ? 'Front' : 'Back';

  Widget _sidePicker(CardSide value, ValueChanged<CardSide> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CardSide>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more_rounded, size: 18),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onSurface,
              ),
          items: CardSide.values
              .map((side) => DropdownMenuItem<CardSide>(
                    value: side,
                    child: Text(_sideLabel(side)),
                  ))
              .toList(),
          onChanged: (side) {
            if (side != null) onChanged(side);
          },
        ),
      ),
    );
  }

  Widget _imageAttachmentTile() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(_imagePath!),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: cs.surfaceContainerHighest,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image attached',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Show on',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 6),
                    if (_occlusions.isEmpty)
                      _sidePicker(
                        _imageSide,
                        (side) => setState(() => _imageSide = side),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Both sides',
                            style: Theme.of(context).textTheme.labelLarge),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove image',
            onPressed: () => setState(() {
              _imagePath = null;
              _occlusions = <double>[];
            }),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  Widget _audioAttachmentTile() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.secondaryContainer,
            foregroundColor: cs.onSecondaryContainer,
            child: const Icon(Icons.graphic_eq_rounded),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Audio attached',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Show on',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(width: 6),
                    _sidePicker(
                      _audioSide,
                      (side) => setState(() => _audioSide = side),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Play audio',
            onPressed: () => CardAudio.play(_audioPath!),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
          IconButton(
            tooltip: 'Remove audio',
            onPressed: () => setState(() => _audioPath = null),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final question = _question.text.trim();
    final answer = _answer.text.trim();
    final note = _note.text.trim();
    final tags = _parseTags(_tags.text);
    if (_isEditing) {
      context.read<AppData>().updateCard(
            widget.deckId,
            widget.card!.id,
            question: question,
            answer: answer.isEmpty && Cloze.hasCloze(question)
                ? Cloze.answerFor(question, widget.card!.clozeIndex)
                : answer,
            note: note,
            imagePath: _imagePath,
            audioPath: _audioPath,
            imageSide: _imageSide,
            audioSide: _audioSide,
            occlusions: _occlusions,
            tags: tags,
          );
    } else {
      final groups = Cloze.groups(question);
      if (groups.length > 1) {
        // Anki-style cloze: one card per deletion group.
        for (final group in groups) {
          context.read<AppData>().addCard(
                widget.deckId,
                Flashcard(
                  id: uuid.v4(),
                  question: question,
                  answer: answer.isNotEmpty
                      ? answer
                      : Cloze.answerFor(question, group),
                  note: note,
                  tags: tags,
                  imagePath: _imagePath,
                  audioPath: _audioPath,
                  imageSide: _imageSide,
                  audioSide: _audioSide,
                  occlusions: _occlusions,
                  clozeIndex: group,
                ),
              );
        }
      } else {
        context.read<AppData>().addCard(
              widget.deckId,
              Flashcard(
                id: uuid.v4(),
                question: question,
                answer: answer.isNotEmpty
                    ? answer
                    : Cloze.answerFor(question, 1),
                note: note,
                tags: tags,
                imagePath: _imagePath,
                audioPath: _audioPath,
                imageSide: _imageSide,
                audioSide: _audioSide,
                occlusions: _occlusions,
              ),
            );
      }
    }
    final wasEditing = _isEditing;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (!wasEditing) {
      messenger.showSnackBar(const SnackBar(
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        content: _CardCreatedToast(),
      ));
    }
  }

  /// Wraps the question's current selection in the next cloze marker.
  void _wrapCloze() {
    final controller = _question;
    final selection = controller.value.selection;
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Select some text in the question first.')));
      return;
    }
    final text = controller.text;
    final hidden = text.substring(selection.start, selection.end);
    final wrapped = '{{c${Cloze.nextGroup(text)}::$hidden}}';
    final next =
        TextSelection.collapsed(offset: selection.start + wrapped.length);
    controller.value = controller.value.copyWith(
        text: text.replaceRange(selection.start, selection.end, wrapped),
        selection: next,
        composing: TextRange.empty);
    setState(() {});
    FocusScope.of(context).requestFocus(_questionFocus);
  }

  /// Swatches offered in the highlight menu (amber default + palette).
  static const Map<String, Color> _highlightColors = <String, Color>{
    'amber': RichMarkup.highlight,
    ...RichMarkup.colors,
  };

  Widget _formatButton(
      IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
      onPressed: () {
        onPressed();
        FocusScope.of(context).requestFocus(_answerFocus);
      },
    );
  }

  /// Full preview of the card as it will look when studied: the
  /// question with any cloze blanked, the image, playable audio and
  /// the formatted answer.
  void _preview() {
    if (_question.text.trim().isEmpty && _answer.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Type a question or answer to preview.')));
      return;
    }
    final group = widget.card?.clozeIndex ?? 1;
    final hasCloze = Cloze.hasCloze(_question.text);
    final answer = _answer.text.isEmpty && hasCloze
        ? Cloze.answerFor(_question.text, group)
        : _answer.text;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF26272F), Color(0xFF0B0B0F)],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hasCloze
                      ? Cloze.blanked(_question.text, group)
                      : _question.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: const Color(0xFFECEAF4)),
                ),
                const Divider(height: 28, color: Color(0x33FFFFFF)),
                if (_imagePath != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_imagePath!),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_audioPath != null) ...[
                  OutlinedButton.icon(
                    onPressed: () => CardAudio.play(_audioPath!),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Play audio'),
                  ),
                  const SizedBox(height: 16),
                ],
                RichAnswer(
                  text: answer,
                  style: Theme.of(ctx)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: const Color(0xFFECEAF4)) ??
                      const TextStyle(),
                ),
                if (_note.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_note.text.trim(),
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: const Color(0xFFB9B7C6))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit card' : 'New card'),
        actions: [
          IconButton(
            tooltip: _isEditing ? 'Save changes' : 'Save card',
            icon: const Icon(Icons.check_rounded),
            onPressed: _save,
          ),
        ],
      ),
      bottomNavigationBar: _answerFocus.hasFocus ? _floatingToolbar() : null,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _question,
              focusNode: _questionFocus,
              decoration: const InputDecoration(
                  labelText: 'Front',
                  border: OutlineInputBorder(),
                  hintText: 'Front'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Front is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _answer,
              focusNode: _answerFocus,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Back',
                  border: OutlineInputBorder(),
                  hintText: 'Back'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) &&
                          !Cloze.hasCloze(_question.text)
                      ? 'Back is required, or add a cloze blank'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Context, mnemonic, or related topic'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                  border: OutlineInputBorder(),
                  hintText: 'history, chapter 3'),
            ),
            const SizedBox(height: 16),

            Text('Attachments',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (_imagePath != null) ...[
              _imageAttachmentTile(),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _editOcclusions,
                  icon: const Icon(Icons.crop_free_rounded, size: 18),
                  label: Text(_occlusions.isEmpty
                      ? 'Hide parts of image'
                      : '${_occlusions.length ~/ 4} region(s) hidden'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_audioPath != null) ...[
              _audioAttachmentTile(),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _attachMenu,
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_imagePath == null && _audioPath == null
                    ? 'Add attachment'
                    : (_imagePath != null && _audioPath != null
                        ? 'Replace attachment'
                        : 'Add another attachment')),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _preview,
                    icon: const Icon(Icons.visibility_rounded),
                    label: const Text('Preview'),
                  ),
                ),
                if (data.ttsEnabled) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Tts.speak(
                          '${Cloze.stripped(_question.text)} ... ${RichMarkup.stripMarkup(_answer.text)}'),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEditing ? 'Save changes' : 'Save card'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Green confirmation in a small dark 3D box (corner radius 16).
class _CardCreatedToast extends StatelessWidget {
  const _CardCreatedToast();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF26272F), Color(0xFF0B0B0F)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 8)),
          const BoxShadow(
              color: Color(0x14FFFFFF), blurRadius: 0, offset: Offset(0, -1)),
        ],
      ),
      child: const Text('Card created',
          style: TextStyle(
              color: Color(0xFF4ADE80),
              fontWeight: FontWeight.w700,
              fontSize: 14)),
    );
  }
}
