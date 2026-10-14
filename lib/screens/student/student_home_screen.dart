import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../widgets/bell_button.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

/// Student's home: seat, membership, fees, recent payments, notices.
class StudentHomeScreen extends StatefulWidget {
  final void Function(int tab) onOpenTab;

  const StudentHomeScreen({super.key, required this.onOpenTab});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();
  int _unread = 0;

  Future<Map<String, dynamic>> _load() async {
    final r = await Future.wait([
      Api.instance.get('/student/home'),
      Api.instance.get('/notifications', query: {'unread': 1, 'per_page': 1}),
    ]);
    if (mounted) setState(() => _unread = toInt(r[1].meta['unread']));
    return r[0].map;
  }

  List<Map<String, dynamic>> _l(dynamic v) => v is List ? v.map((e) => (e as Map).cast<String, dynamic>()).toList() : [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My library'),
        actions: [BellButton(unread: _unread, onReturn: () => _loader.currentState?.reload())],
      ),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final s = (d['student'] as Map).cast<String, dynamic>();
          final lib = (d['library'] as Map).cast<String, dynamic>();
          final seats = _l(d['seats']);
          final cur = d['current_membership'] is Map ? (d['current_membership'] as Map).cast<String, dynamic>() : null;
          final pays = _l(d['recent_payments']);
          final notices = _l(d['notices']);
          final due = toNum(d['balance_due']);
          final end = d['membership_end']?.toString();
          final endDate = end == null ? null : DateTime.tryParse(end);
          final today = DateTime.now();
          final daysLeft = endDate?.difference(DateTime(today.year, today.month, today.day)).inDays;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ---- ID strip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  Avatar(url: s['photo_url']?.toString(), name: '${s['name']}', radius: 30),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${s['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('${s['student_code']}', style: const TextStyle(color: Colors.white70)),
                      Text('${lib['name']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  IconButton(
                    tooltip: 'ID card',
                    onPressed: () => openLink(context, '${d['id_card_url']}'),
                    icon: const Icon(Icons.badge_outlined, color: Colors.white),
                  ),
                ]),
              ),
              const SizedBox(height: 12),

              if (daysLeft != null && daysLeft < 0)
                Banner2(
                  icon: Icons.event_busy,
                  color: AppColors.danger,
                  background: AppColors.dangerSoft,
                  text: 'Your membership ended on ${niceDate(end)}. Please renew at the library.',
                )
              else if (daysLeft != null && daysLeft <= 5)
                Banner2(icon: Icons.schedule, text: 'Your membership ends on ${niceDate(end)} ($daysLeft days left).'),

              StatGrid(children: [
                StatCard(
                  label: seats.isEmpty ? 'Seat' : seats.map((x) => x['shift_name']).join(', '),
                  value: seats.isEmpty ? 'Not given' : seats.map((x) => x['seat_no']).join(', '),
                  icon: Icons.event_seat_outlined,
                ),
                StatCard(
                  label: 'Membership till',
                  value: end == null ? '-' : niceDate(end),
                  icon: Icons.event_available_outlined,
                  color: AppColors.blue,
                  hint: cur == null ? null : planLabel('${cur['plan_type']}'),
                ),
                StatCard(
                  label: due > 0 ? 'Fees due' : 'Fees',
                  value: due > 0 ? money(due) : 'All paid',
                  icon: Icons.currency_rupee,
                  color: due > 0 ? AppColors.danger : AppColors.green,
                  onTap: () => widget.onOpenTab(1),
                ),
                StatCard(
                  label: 'Monthly fee',
                  value: money(s['monthly_fee']),
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.warn,
                ),
              ]),

              if (seats.isNotEmpty) ...[
                const SectionTitle('My seat'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final x in seats)
                      ListTile(
                        leading: const Icon(Icons.event_seat, color: AppColors.green),
                        title: Text('Seat ${x['seat_no']}'),
                        subtitle: Text('${x['shift_name']} • ${x['start_time']}–${x['end_time']}'),
                      ),
                  ]),
                ),
              ],

              if (due > 0) ...[
                const SectionTitle('How to pay'),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${money(due)} is due. Pay at the library counter or by UPI.'),
                    if (lib['upi_id'] != null) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Text('UPI: ${lib['upi_id']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        IconButton(
                          tooltip: 'Copy UPI ID',
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: '${lib['upi_id']}'));
                            showSnack(context, 'UPI ID copied');
                          },
                        ),
                      ]),
                      const Text('After paying by UPI, send the screenshot to the library. Your receipt comes once they confirm.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ],
                    if (lib['whatsapp'] != null) ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => openWhatsApp(context, '${lib['whatsapp']}',
                            'Namaste, main ${s['name']} (${s['student_code']}). Maine fees ka payment kiya hai.'),
                        icon: const Icon(Icons.chat, size: 18),
                        label: const Text('Message the library'),
                      ),
                    ],
                  ]),
                ),
              ],

              SectionTitle('Recent payments',
                  trailing: TextButton(onPressed: () => widget.onOpenTab(1), child: const Text('All'))),
              Panel(
                padding: EdgeInsets.zero,
                child: pays.isEmpty
                    ? const Padding(padding: EdgeInsets.all(14), child: Text('No payments yet', style: TextStyle(color: AppColors.muted)))
                    : Column(children: [for (final p in pays) StudentPaymentTile(p: p)]),
              ),

              if (notices.isNotEmpty) ...[
                SectionTitle('Notices', trailing: TextButton(onPressed: () => widget.onOpenTab(2), child: const Text('All'))),
                for (final n in notices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${n['body']}', maxLines: 3, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(niceDateTime(n['created_at']), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      ]),
                    ),
                  ),
              ],

              const SectionTitle('Library'),
              Panel(
                child: Column(children: [
                  InfoRow('Name', '${lib['name']}'),
                  InfoRow('Address', '${lib['address'] ?? ''}'),
                  InfoRow('Phone', '${lib['phone'] ?? ''}'),
                  if (lib['phone'] != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => callPhone(context, '${lib['phone']}'),
                        icon: const Icon(Icons.call, size: 18),
                        label: const Text('Call library'),
                      ),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One payment row with its receipt link.
class StudentPaymentTile extends StatelessWidget {
  final Map<String, dynamic> p;

  const StudentPaymentTile({super.key, required this.p});

  @override
  Widget build(BuildContext context) {
    final url = p['receipt_url']?.toString();
    return ListTile(
      leading: const Icon(Icons.receipt_long_outlined, color: AppColors.green),
      title: Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('${p['receipt_no'] ?? 'Waiting for confirmation'} • ${methodLabel('${p['method']}')} • ${niceDate(p['paid_on'])}'),
      trailing: url == null
          ? Pill.paymentStatus('${p['status']}')
          : IconButton(
              tooltip: 'Open receipt',
              icon: const Icon(Icons.open_in_new, color: AppColors.green),
              onPressed: () => openLink(context, url),
            ),
    );
  }
}
