import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _loader = GlobalKey<AsyncLoaderState<List<Map<String, dynamic>>>>();

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await Api.instance.get('/notifications', query: {'per_page': 50});
    return r.list;
  }

  Future<void> _markAll() async {
    try {
      await Api.instance.post('/notifications/read-all');
      await _loader.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  IconData _icon(String type) => switch (type) {
        'fee_due' => Icons.currency_rupee,
        'membership_expiry' => Icons.event_busy,
        'payment_confirmed' => Icons.check_circle_outline,
        'announcement' => Icons.campaign_outlined,
        'subscription' => Icons.workspace_premium_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [TextButton(onPressed: _markAll, child: const Text('Mark all read'))],
      ),
      body: AsyncLoader<List<Map<String, dynamic>>>(
        key: _loader,
        load: _load,
        builder: (context, items, reload) {
          if (items.isEmpty) {
            return ListView(children: const [
              EmptyView(icon: Icons.notifications_none, title: 'No notifications yet'),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              final unread = n['read_at'] == null;
              return ListTile(
                tileColor: unread ? AppColors.greenSoft : Colors.white,
                leading: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(_icon('${n['type']}'), color: AppColors.green),
                ),
                title: Text('${n['title']}',
                    style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                subtitle: Text('${n['body']}\n${niceDateTime(n['created_at'])}'),
                isThreeLine: true,
                onTap: unread
                    ? () async {
                        try {
                          await Api.instance.post('/notifications/${n['id']}/read');
                          await reload();
                        } on ApiException catch (_) {}
                      }
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}
