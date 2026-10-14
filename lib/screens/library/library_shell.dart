import 'package:flutter/material.dart';

import '../common/account_screen.dart';
import '../fees/fees_screen.dart';
import 'library_dashboard_screen.dart';
import 'seat_map_screen.dart';
import 'students_screen.dart';

/// Library admin app: bottom tabs.
class LibraryShell extends StatefulWidget {
  const LibraryShell({super.key});

  @override
  State<LibraryShell> createState() => _LibraryShellState();
}

class _LibraryShellState extends State<LibraryShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      LibraryDashboardScreen(onOpenTab: (i) => setState(() => _tab = i)),
      const StudentsScreen(),
      const FeesScreen(),
      AccountScreen(extraTiles: [
        ListTile(
          leading: const Icon(Icons.event_seat_outlined),
          title: const Text('Seat map'),
          subtitle: const Text('Free and taken seats, add seats'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeatMapScreen())),
        ),
      ]),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Students'),
          NavigationDestination(icon: Icon(Icons.currency_rupee), label: 'Fees'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
