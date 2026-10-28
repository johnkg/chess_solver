import 'package:flutter/material.dart';

import 'board_screen.dart';
import 'learn_screen.dart';
import 'play_screen.dart';
import 'practice_screen.dart';
import 'progress_store.dart';
import 'settings_store.dart';
import 'theme.dart';

/// The whole app: four tabs, and Settings behind the gear in each top bar.
class ChessSolverApp extends StatefulWidget {
  const ChessSolverApp({super.key});

  @override
  State<ChessSolverApp> createState() => _ChessSolverAppState();
}

class _ChessSolverAppState extends State<ChessSolverApp> {
  final SettingsStore _settings = SettingsStore();

  /// The saved settings have been read; screens start from them.
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _settings.load().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    return SettingsScope(
      settings: _settings,
      child: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => MaterialApp(
          title: 'Chess Technique Teacher',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: _settings.themeMode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final ProgressStore _progress = ProgressStore();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _progress.load();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          LearnScreen(progress: _progress),
          PracticeScreen(progress: _progress),
          PlayScreen(progress: _progress),
          BoardScreen(progress: _progress),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          NavigationDestination(
            icon: Icon(Icons.gps_fixed),
            selectedIcon: Icon(Icons.gps_fixed),
            label: 'Practice',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_esports_outlined),
            selectedIcon: Icon(Icons.sports_esports),
            label: 'Play',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_on_outlined),
            selectedIcon: Icon(Icons.grid_on),
            label: 'Board',
          ),
        ],
      ),
    );
  }
}
