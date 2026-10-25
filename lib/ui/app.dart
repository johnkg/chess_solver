import 'package:flutter/material.dart';

import 'board_screen.dart';
import 'learn_screen.dart';
import 'play_screen.dart';
import 'practice_screen.dart';
import 'progress_store.dart';

/// The whole app: four tabs.
class ChessSolverApp extends StatelessWidget {
  const ChessSolverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Technique Teacher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF769656),
        useMaterial3: true,
      ),
      home: const HomeShell(),
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
          const LearnScreen(),
          PracticeScreen(progress: _progress),
          PlayScreen(progress: _progress),
          const BoardScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.school_outlined), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), label: 'Practice'),
          NavigationDestination(icon: Icon(Icons.sports_esports_outlined), label: 'Play'),
          NavigationDestination(icon: Icon(Icons.grid_on), label: 'Board'),
        ],
      ),
    );
  }
}
