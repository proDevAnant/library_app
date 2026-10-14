import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/common.dart';
import 'seat_map_screen.dart';

class LibraryDashboardScreen extends StatefulWidget {
  /// Switch bottom tab (1 = Students, 2 = Fees).
  final void Function(int tab) onOpenTab;

  const LibraryDashboardScreen({super.key, required this.onOpenTab});

  @override
  State<LibraryDashboardScreen> createState() => _LibraryDashboardScreenState();
}

class _LibraryDashboardScreenState extends State<LibraryDashboardScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();
  int _unread = 0;

  Future<Map<String, dynamic>> _load() async {
    final results = await Future.wait([
      Api.instance.get('/library/dashboard'),
      Api.instance.get('/notifications', query: {'unread': 1, 'per_page': 1}),
    ]);
    if (mounted) setState(() => _unread = toInt(results[1].meta['unread']));
    // the login info (plan dates) may have changed too
    if (mounted) context.read<AuthState>().refreshMe().catchError((_) {});
    return results[0].map;
  }

  Map<String, dynamic> _m(dynamic v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<AuthState>().user?.library;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lib?.name ?? 'Dashboard', overflow: TextOverflow.ellipsis),
            if (lib != null)
              Text('Code ${lib.code}', style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          BellButton(unread: _unread, onReturn: () => _loader.currentState?.reload()),
        ],
      ),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final st = _m(d['students']);
          final fees = _m(d['fees']);
          final wait = _m(fees['awaiting_verification']);
          final seats = _m(d['seats']);
          final shifts = (seats['by_shift'] as List? ?? []).map((e) => _m(e)).toList();
          final mem = _m(d['memberships']);
          final expiring = (mem['expiring_soon'] as List? ?? []).map((e) => _m(e)).toList();
          final month = _m(d['this_month']);
          final plan = _m(d['plan']);
          final planEnd = plan['plan_end']?.toString();
          final daysLeft = planEnd == null ? null : DateTime.tryParse(planEnd)?.difference(DateTime.now()).inDays;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (plan['plan_expired'] == true)
                const Banner2(
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.danger,
                  background: AppColors.dangerSoft,
                  text: 'Your subscription has expired. You can view data, but adding or editing is paused until you renew.',
                )
              else if (daysLeft != null && daysLeft <= 5)
                Banner2(
                  icon: Icons.schedule,
                  text: 'Your plan ends on ${niceDate(planEnd)}. Renew soon to avoid interruption.',
                ),
              if (toInt(wait['count']) > 0)
                Banner2(
                  icon: Icons.hourglass_top_rounded,
                  color: AppColors.blue,
                  background: const Color(0xFFE8F0FE),
                  text: '${wait['count']} UPI/bank payment(s) of ${money(wait['amount'])} waiting for verification. '
                      'Check your bank/UPI app, then verify.',
                ),
              StatGrid(children: [
                StatCard(
                  label: 'Active students',
                  value: '${st['active'] ?? 0}',
                  icon: Icons.people_alt_outlined,
                  hint: '${st['inactive'] ?? 0} inactive • ${st['new_this_month'] ?? 0} new',
                  onTap: () => widget.onOpenTab(1),
                ),
                StatCard(
                  label: 'Collected today',
                  value: money(fees['collected_today']),
                  icon: Icons.today_outlined,
                  onTap: () => widget.onOpenTab(2),
                ),
                StatCard(
                  label: 'Collected this month',
                  value: money(fees['collected_this_month']),
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () => widget.onOpenTab(2),
                ),
                StatCard(
                  label: 'Pending fees',
                  value: money(fees['pending_total']),
                  icon: Icons.pending_actions_outlined,
                  color: AppColors.warn,
                  hint: '${fees['students_with_dues'] ?? 0} students • ${money(fees['overdue'])} overdue',
                  onTap: () => widget.onOpenTab(2),
                ),
              ]),

              SectionTitle('Seats',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SeatMapScreen())),
                    child: Text('Seat map (${seats['total'] ?? 0})'),
                  )),
              Panel(
                child: shifts.isEmpty
                    ? const Text('No active shifts', style: TextStyle(color: AppColors.muted))
                    : Column(
                        children: [
                          for (final s in shifts) _ShiftRow(s: s, total: toInt(seats['total']) - toInt(seats['reserved'])),
                          if (toInt(st['without_seat']) > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text('${st['without_seat']} active student(s) have no seat',
                                  style: const TextStyle(color: AppColors.warn)),
                            ),
                        ],
                      ),
              ),

              SectionTitle('This month'),
              Panel(
                child: Column(
                  children: [
                    _MoneyRow('Fees collected', month['fee_income']),
                    _MoneyRow('Other income', month['other_income']),
                    _MoneyRow('Refunds', month['refunds'], minus: true),
                    _MoneyRow('Expenses', month['expenses'], minus: true),
                    const Divider(height: 20),
                    _MoneyRow('Net income', month['net_income'], bold: true),
                  ],
                ),
              ),

              SectionTitle('Memberships ending soon',
                  trailing: Text('next ${mem['expiring_days'] ?? 7} days', style: const TextStyle(color: AppColors.muted))),
              Panel(
                padding: EdgeInsets.zero,
                child: expiring.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No memberships ending soon 👍', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (final e in expiring)
                            ListTile(
                              dense: true,
                              leading: const Icon(Icons.event_busy, color: AppColors.warn),
                              title: Text('${e['name']}'),
                              subtitle: Text('${e['student_code']} • ends ${niceDate(e['end_date'])}'),
                              trailing: Text(
                                toInt(e['days_left']) == 0 ? 'Today' : '${e['days_left']}d',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.warn),
                              ),
                            ),
                        ],
                      ),
              ),
              if (toInt(mem['expired_not_renewed']) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text('${mem['expired_not_renewed']} active student(s) have an expired membership',
                      style: const TextStyle(color: AppColors.danger)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final Map<String, dynamic> s;
  final int total;

  const _ShiftRow({required this.s, required this.total});

  @override
  Widget build(BuildContext context) {
    final occ = toInt(s['occupied']);
    final ratio = total <= 0 ? 0.0 : (occ / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${s['name']}  (${s['start_time']}–${s['end_time']})',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text('${s['available']} free', style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: AppColors.greenSoft,
              color: ratio > 0.9 ? AppColors.danger : AppColors.green,
            ),
          ),
          const SizedBox(height: 2),
          Text('$occ of $total occupied', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  final String label;
  final dynamic value;
  final bool minus;
  final bool bold;

  const _MoneyRow(this.label, this.value, {this.minus = false, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final n = toNum(value);
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      fontSize: bold ? 16 : 14,
      color: bold ? (n < 0 ? AppColors.danger : AppColors.green) : AppColors.ink,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style.copyWith(color: AppColors.ink))),
          Text('${minus && n > 0 ? '− ' : ''}${money(n)}', style: style),
        ],
      ),
    );
  }
}
