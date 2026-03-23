import 'package:flutter/material.dart';

import '../board/board_screen.dart';
import '../settings/settings_screen.dart';
import '../workers/workers_list_screen.dart';

class WorkrHomeScreen extends StatefulWidget {
  const WorkrHomeScreen({super.key});

  @override
  State<WorkrHomeScreen> createState() => _WorkrHomeScreenState();
}

class _WorkrHomeScreenState extends State<WorkrHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      body: IndexedStack(
        index: _index,
        children: const [
          BoardScreen(),
          WorkersListScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withAlpha(140),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Canvas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_rounded),
            label: 'Workers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

