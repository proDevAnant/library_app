import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../common/account_screen.dart';
import 'admin_dashboard_screen.dart';

/// Super Admin (software owner) app.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const AdminDashboardScreen(),
      const ComingSoon(title: 'Libraries', detail: 'Add, edit, suspend libraries and renew plans (update 6C).'),
      const ComingSoon(title: 'Payments', detail: 'Verify subscription payments and see support requests (update 6C).'),
      const AccountScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Libraries'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
