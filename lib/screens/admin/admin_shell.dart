import 'package:flutter/material.dart';

import '../common/account_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_support_screen.dart';
import 'libraries_screen.dart';
import 'plans_screen.dart';

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
      const LibrariesScreen(),
      const AdminPaymentsScreen(),
      AccountScreen(extraTiles: [
        ListTile(
          leading: const Icon(Icons.workspace_premium_outlined),
          title: const Text('Plans & prices'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlansScreen())),
        ),
        ListTile(
          leading: const Icon(Icons.support_agent),
          title: const Text('Support requests'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminSupportScreen())),
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
          NavigationDestination(icon: Icon(Icons.store_outlined), selectedIcon: Icon(Icons.store), label: 'Libraries'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
