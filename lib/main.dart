import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/app_data.dart';
import 'services/home_widget_sync.dart';
import 'services/reminder_service.dart';
import 'screens/create_screen.dart';
import 'screens/home_screen.dart';
import 'screens/library_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/quick_add_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/study_screen.dart';
import 'ui/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await ReminderService.init();
  runApp(OncardApp(prefs: prefs));
}

class OncardApp extends StatefulWidget {
  final SharedPreferences prefs;
  const OncardApp({super.key, required this.prefs});

  @override
  State<OncardApp> createState() => _OncardAppState();
}

class _OncardAppState extends State<OncardApp> {
  late final AppData _data = AppData(widget.prefs);

  @override
  void initState() {
    super.initState();
    // Keep the Android home-screen widget in sync with study data.
    _data.addListener(_syncHomeWidget);
    unawaited(updateHomeWidget(_data));
    // Re-arm the daily reminder on every start, and handle a cold start
    // that was launched by tapping a reminder notification.
    unawaited(ReminderService.apply(_data));
    ReminderService.onTap = _openDeckFromReminder;
    unawaited(ReminderService.handleLaunch());
  }

  @override
  void dispose() {
    _data.removeListener(_syncHomeWidget);
    super.dispose();
  }

  void _syncHomeWidget() {
    unawaited(updateHomeWidget(_data));
  }

  void _openDeckFromReminder(String deckId) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final data = context.read<AppData>();
    final deck = data.deckById(deckId) ?? data.nextDeckToStudy;
    if (deck == null || deck.cards.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => StudyScreen(deck: deck, mode: StudyMode.flip)));
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppData>.value(
      value: _data,
      child: Consumer<AppData>(
        builder: (context, data, _) {
          final light = buildLightTheme(ThemeData.light().textTheme);
          final dark = buildDarkTheme(ThemeData.dark().textTheme);
          return MaterialApp(
            title: 'Oncard',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: light,
            darkTheme: dark,
            themeMode: data.themeMode,
            home: data.onboarded
                ? const RootShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeOpenQuickAdd(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const LibraryScreen(),
      const CreateScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          // Filled rounded silhouettes, matching the reference set.
          NavigationDestination(
              icon: Icon(Icons.home_rounded),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.laptop_rounded),
              selectedIcon: Icon(Icons.laptop_rounded),
              label: 'Library'),
          NavigationDestination(
              icon: Icon(Icons.library_add_rounded),
              selectedIcon: Icon(Icons.library_add_rounded),
              label: 'Create'),
          NavigationDestination(
              icon: Icon(Icons.insert_chart_rounded),
              selectedIcon: Icon(Icons.insert_chart_rounded),
              label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.settings_rounded),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings'),
        ],
      ),
    );
  }
}
