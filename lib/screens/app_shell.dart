import 'package:flutter/material.dart';

import 'landing_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _pages = const [
    LandingPage(),
    SearchHubPage(),
    ExpensesHubPage(),
    RankingsHubPage(),
    ProfileHubPage(),
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
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_rounded),
            label: 'Rankings',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class SearchHubPage extends StatelessWidget {
  const SearchHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureHubPage(
      title: 'Search',
      subtitle: 'Find politicians by name, party, or state.',
      icon: Icons.search_rounded,
      primaryLabel: 'Deputies',
      secondaryLabel: 'Senators',
      primaryRoute: null,
      secondaryRoute: null,
    );
  }
}

class ExpensesHubPage extends StatelessWidget {
  const ExpensesHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureHubPage(
      title: 'Expenses',
      subtitle: 'Compare annual and monthly spending patterns.',
      icon: Icons.receipt_long_rounded,
      primaryLabel: 'Deputy expenses',
      secondaryLabel: 'Senator expenses',
      primaryRoute: null,
      secondaryRoute: null,
    );
  }
}

class RankingsHubPage extends StatelessWidget {
  const RankingsHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureHubPage(
      title: 'Rankings',
      subtitle: 'Surface leaders by activity, spending, and proposals.',
      icon: Icons.leaderboard_rounded,
      primaryLabel: 'Most active',
      secondaryLabel: 'Highest expenses',
      primaryRoute: null,
      secondaryRoute: null,
    );
  }
}

class ProfileHubPage extends StatelessWidget {
  const ProfileHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureHubPage(
      title: 'Profile',
      subtitle: 'Sources, transparency notes, and app settings.',
      icon: Icons.person_rounded,
      primaryLabel: 'Sources',
      secondaryLabel: 'About app',
      primaryRoute: null,
      secondaryRoute: null,
    );
  }
}

class _FeatureHubPage extends StatelessWidget {
  const _FeatureHubPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.primaryRoute,
    required this.secondaryRoute,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryLabel;
  final String secondaryLabel;
  final String? primaryRoute;
  final String? secondaryRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 34, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ActionCard(label: primaryLabel, icon: Icons.arrow_forward_rounded),
              _ActionCard(label: secondaryLabel, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width / 2 - 24,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Icon(icon),
            ],
          ),
        ),
      ),
    );
  }
}
