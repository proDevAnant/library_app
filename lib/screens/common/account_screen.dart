import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';

/// "More" tab: profile, notifications, password, logout. Extra rows can be added per role.
class AccountScreen extends StatelessWidget {
  final List<Widget> extraTiles;

  const AccountScreen({super.key, this.extraTiles = const []});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final u = auth.user!;
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Panel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.greenSoft,
                  child: Text(u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 22, color: AppColors.green, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${u.roleLabel} • ${u.phone}', style: const TextStyle(color: AppColors.muted)),
                      if (u.library != null)
                        Text('${u.library!.name} (${u.library!.code})', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ...extraTiles,
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notifications'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Log out', style: TextStyle(color: AppColors.danger)),
                  onTap: () async {
                    final ok = await confirmDialog(context,
                        title: 'Log out?', message: 'You will need your password to log in again.', confirmText: 'Log out', danger: true);
                    if (ok && context.mounted) await context.read<AuthState>().logout();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('${AppConfig.appName} • v1.2', style: TextStyle(color: AppColors.muted, fontSize: 12))),
        ],
      ),
    );
  }
}
