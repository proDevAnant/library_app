import 'package:flutter/material.dart';

import '../common/account_screen.dart';
import 'student_home_screen.dart';
import 'student_lists.dart';
import 'student_profile_edit_screen.dart';

/// Student app: only the student's own information.
class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      StudentHomeScreen(onOpenTab: (i) => setState(() => _tab = i)),
      const StudentPaymentsScreen(),
      const StudentNoticesScreen(),
      AccountScreen(extraTiles: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('My profile'),
          subtitle: const Text('Email, address, emergency contact'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StudentProfileEditScreen())),
        ),
      ]),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Payments'),
          NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Notices'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }
}
