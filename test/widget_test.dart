import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oncard/data/app_data.dart';
import 'package:oncard/data/models.dart';
import 'package:oncard/main.dart';
import 'package:oncard/screens/card_editor_screen.dart';
import 'package:oncard/screens/study_screen.dart';

void main() {
  testWidgets('returning users land on the home screen', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'onboarded': true,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(OncardApp(prefs: prefs));
    await tester.pump();
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Start studying'), findsOneWidget);
  });

  testWidgets('first launch shows onboarding', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(OncardApp(prefs: prefs));
    await tester.pump();
    expect(find.text('Welcome to Oncard'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });


  testWidgets('audio can be paused and stops when moving to the next card',
      (tester) async {
    const channel = MethodChannel('oncard/share');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final data = AppData(prefs);
    final first = Flashcard(
      id: 'audio-card',
      question: 'Question 1',
      answer: 'Answer 1',
      audioPath: '/tmp/card-audio.mp3',
    );
    final second = Flashcard(
      id: 'second-card',
      question: 'Question 2',
      answer: 'Answer 2',
    );
    final deck = Deck(id: 'test-deck', name: 'Test deck', cards: [first, second]);
    data.decks = [deck];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppData>.value(
        value: data,
        child: MaterialApp(
          home: StudyScreen(deck: deck, mode: StudyMode.flip),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play audio'));
    await tester.pump();
    expect(calls, contains('playAudio'));

    await tester.tap(find.text('Pause audio'));
    await tester.pump();
    expect(calls, contains('pauseAudio'));

    await tester.tap(find.text('Play audio'));
    await tester.pump();
    expect(calls, contains('resumeAudio'));

    await tester.drag(
        find.byWidgetPredicate((widget) =>
            widget is GestureDetector && widget.onHorizontalDragEnd != null),
        const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);
    expect(calls, contains('stopAudio'));
  });

  testWidgets('swiped cards are skipped, not graded, and can be reviewed',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final data = AppData(prefs);
    final first = Flashcard(
      id: 'first-card',
      question: 'Question 1',
      answer: 'Answer 1',
    );
    final second = Flashcard(
      id: 'second-card',
      question: 'Question 2',
      answer: 'Answer 2',
    );
    final deck = Deck(id: 'test-deck', name: 'Test deck', cards: [first, second]);
    data.decks = [deck];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppData>.value(
        value: data,
        child: MaterialApp(
          home: StudyScreen(deck: deck, mode: StudyMode.flip),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
        find.byWidgetPredicate((widget) =>
            widget is GestureDetector && widget.onHorizontalDragEnd != null),
        const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('Question 2'), findsOneWidget);
    expect(first.reps, 0);

    await tester.drag(
        find.byWidgetPredicate((widget) =>
            widget is GestureDetector && widget.onHorizontalDragEnd != null),
        const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 still skipped · not graded'), findsOneWidget);
    expect(find.text('Review skipped (2)'), findsOneWidget);
    expect(first.due, 0);
    expect(second.due, 0);

    await tester.tap(find.text('Review skipped (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1'), findsOneWidget);
  });


  testWidgets('attachments appear on their configured card sides',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final data = AppData(prefs);
    final card = Flashcard(
      id: 'placed-attachments',
      question: 'Front prompt',
      answer: 'Back answer',
      imagePath: '/tmp/missing-card-image.png',
      imageSide: CardSide.back,
      audioPath: '/tmp/card-audio.mp3',
      audioSide: CardSide.front,
    );
    final deck = Deck(id: 'placement-deck', name: 'Placement', cards: [card]);
    data.decks = [deck];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppData>.value(
        value: data,
        child: MaterialApp(
          home: StudyScreen(deck: deck, mode: StudyMode.flip),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Front prompt'), findsOneWidget);
    expect(find.text('Play audio'), findsOneWidget);
    expect(find.text('Image not available'), findsNothing);

    await tester.tap(find.text('Show answer'));
    await tester.pumpAndSettle();

    expect(find.text('Back answer'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Play audio'), findsNothing);
  });

  testWidgets('card editor saves image placement from the compact dropdown',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final data = AppData(prefs);
    final card = Flashcard(
      id: 'editable-image',
      question: 'Question',
      answer: 'Answer',
      imagePath: '/tmp/missing-card-image.png',
    );
    final deck = Deck(id: 'editor-deck', name: 'Editor', cards: [card]);
    data.decks = [deck];

    await tester.pumpWidget(
      ChangeNotifierProvider<AppData>.value(
        value: data,
        child: MaterialApp(
          home: CardEditorScreen(deckId: deck.id, card: card),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<CardSide>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(card.imageSide, CardSide.back);
  });

}
