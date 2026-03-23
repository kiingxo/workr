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
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: IndexedStack(
        index: _index,
        children: const [
          BoardScreen(),
          WorkersListScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.06),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey.shade400,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Canvas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.list_alt_rounded),
              activeIcon: Icon(Icons.list_alt_rounded),
              label: 'Workers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

