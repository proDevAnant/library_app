import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../screens/common/notifications_screen.dart';

/// Bell icon with a red count. [onReturn] runs after the notifications screen closes.
class BellButton extends StatelessWidget {
  final int unread;
  final VoidCallback? onReturn;

  const BellButton({super.key, required this.unread, this.onReturn});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        onReturn?.call();
      },
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.danger,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
