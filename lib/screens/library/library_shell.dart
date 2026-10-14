import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../common/account_screen.dart';
import 'library_dashboard_screen.dart';

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
      const ComingSoon(title: 'Students', detail: 'Add students, photos, seats and ID cards (update 6B).'),
      const ComingSoon(title: 'Fees', detail: 'Memberships, payments, UPI verification and receipts (update 6B).'),
      const AccountScreen(),
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
