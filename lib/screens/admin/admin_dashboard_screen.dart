import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/common.dart';
import '../../widgets/decor.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();
  int _unread = 0;

  Future<Map<String, dynamic>> _load() async {
    final r = await Future.wait([
      Api.instance.get('/admin/dashboard'),
      Api.instance.get('/admin/alerts'),
      Api.instance.get('/notifications', query: {'unread': 1, 'per_page': 1}),
    ]);
    if (mounted) setState(() => _unread = toInt(r[2].meta['unread']));
    return {'dash': r[0].map, 'alerts': r[1].map};
  }

  Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.map((e) => _m(e)).toList() : <Map<String, dynamic>>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner dashboard'),
        actions: [BellButton(unread: _unread, onReturn: () => _loader.currentState?.reload())],
      ),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, data, reload) {
          final d = _m(data['dash']);
          final libs = _m(d['libraries']);
          final plans = _m(d['plans']);
          final money_ = _m(d['subscription_income']);
          final alerts = _m(data['alerts']);
          final expiring = _l(alerts['expiring_soon']);
          final expired = _l(alerts['expired']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              RoomPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CountUpMoney(
                    toNum(money_['this_month']),
                    style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, height: 1),
                  ),
                  const Text('earned from libraries this month', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  Text('${libs['total'] ?? 0} libraries, ${d['total_active_students'] ?? 0} students using the app',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 14),
              if (toInt(money_['pending_verification']) > 0)
                Banner2(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.blue,
                  background: const Color(0xFFE8F0FE),
                  text: '${money_['pending_verification']} subscription payment(s) waiting for your verification.',
                ),
              StatGrid(children: [
                StatCard(
                  label: 'Libraries',
                  value: '${libs['total'] ?? 0}',
                  icon: Icons.store_outlined,
                  hint: '${libs['active'] ?? 0} active • ${libs['trial'] ?? 0} trial',
                ),
                StatCard(
                  label: 'Suspended / off',
                  value: '${toInt(libs['suspended']) + toInt(libs['deactivated'])}',
                  icon: Icons.block,
                  color: AppColors.danger,
                ),
                StatCard(
                  label: 'Earned this year',
                  value: money(money_['this_year']),
                  icon: Icons.account_balance_wallet_outlined,
                  hint: '${money_['pending_verification'] ?? 0} payment(s) to verify',
                ),
                StatCard(
                  label: 'Active students (all)',
                  value: '${d['total_active_students'] ?? 0}',
                  icon: Icons.people_alt_outlined,
                  color: AppColors.blue,
                ),
                StatCard(
                  label: 'Plans expiring (7 days)',
                  value: '${plans['expiring_7_days'] ?? 0}',
                  icon: Icons.schedule,
                  color: AppColors.warn,
                ),
                StatCard(
                  label: 'Open support requests',
                  value: '${d['open_support_requests'] ?? 0}',
                  icon: Icons.support_agent,
                  color: AppColors.blue,
                ),
              ]),
              SectionTitle('Plans expiring soon'),
              _AlertList(rows: expiring, emptyText: 'No plans ending in the next 7 days', expired: false),
              SectionTitle('Expired plans'),
              _AlertList(rows: expired, emptyText: 'No expired plans', expired: true),
            ],
          );
        },
      ),
    );
  }
}

class _AlertList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final bool expired;

  const _AlertList({required this.rows, required this.emptyText, required this.expired});

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: EdgeInsets.zero,
      child: rows.isEmpty
          ? Padding(padding: const EdgeInsets.all(14), child: Text(emptyText, style: const TextStyle(color: AppColors.muted)))
          : Column(
              children: [
                for (final r in rows)
                  ListTile(
                    dense: true,
                    leading: Icon(expired ? Icons.error_outline : Icons.schedule,
                        color: expired ? AppColors.danger : AppColors.warn),
                    title: Text('${r['name']} (${r['code']})'),
                    subtitle: Text('${r['owner_name'] ?? ''} ${r['owner_phone'] ?? ''}'.trim()),
                    trailing: Text(
                      r['plan_end'] == null ? 'No plan' : niceDate(r['plan_end']),
                      style: TextStyle(color: expired ? AppColors.danger : AppColors.warn, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
    );
  }
}
