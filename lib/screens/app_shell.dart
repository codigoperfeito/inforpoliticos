import 'package:flutter/material.dart';

import 'home_page.dart';
import 'landing_page.dart';
import 'senators_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    LandingPage(),
    HomePage(),
    SenatorsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.visibility_rounded),
            label: 'Informações',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_rounded),
            label: 'Deputados',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_rounded),
            label: 'Senadores',
          ),
        ],
      ),
    );
  }
}
