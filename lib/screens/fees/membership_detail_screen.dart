import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import 'fee_forms.dart';
import 'payment_detail_screen.dart';

class MembershipDetailScreen extends StatefulWidget {
  final int membershipId;

  const MembershipDetailScreen({super.key, required this.membershipId});

  @override
  State<MembershipDetailScreen> createState() => _MembershipDetailScreenState();
}

class _MembershipDetailScreenState extends State<MembershipDetailScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();

  String get _base => '/library/memberships/${widget.membershipId}';

  Future<Map<String, dynamic>> _load() async => (await Api.instance.get(_base)).map;

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _whatsapp() async {
    try {
      final r = await Api.instance.get('$_base/whatsapp');
      if (mounted) await openLink(context, '${r.map['url']}');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _cancel() async {
    final why = await askText(context,
        title: 'Cancel membership?', label: 'Reason', confirmText: 'Cancel membership', danger: true);
    if (why == null) return;
    try {
      await Api.instance.post('$_base/cancel', {'reason': why});
      if (!mounted) return;
      showSnack(context, 'Membership cancelled');
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _discount(Map<String, dynamic> m) async {
    final amount = TextEditingController(text: toNum(m['discount_amount']).toStringAsFixed(0));
    final reason = TextEditingController();
    final form = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change discount'),
        content: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Fee before discount: ${money(m['gross_amount'])}', style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            TextFormField(
              controller: amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Discount (₹)'),
              validator: (v) => num.tryParse((v ?? '').trim()) == null ? 'Enter a number' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason *'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Write a reason' : null,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.post('$_base/discount', {'discount_amount': amount.text.trim(), 'reason': reason.text.trim()});
      if (!mounted) return;
      showSnack(context, 'Discount updated');
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final m = (d['membership'] as Map).cast<String, dynamic>();
          final st = (d['student'] as Map).cast<String, dynamic>();
          final pays = (d['payments'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final active = m['status'] == 'active';
          final payable = toNum(m['payable_now']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Panel(
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Text(planLabel('${m['plan_type']}'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    Pill.feeStatus('${m['fee_status']}'),
                  ]),
                  const SizedBox(height: 8),
                  InfoRow('Student', '${st['name']} (${st['student_code']})'),
                  InfoRow('Period', '${niceDate(m['start_date'])} – ${niceDate(m['end_date'])}'),
                  InfoRow('Due date', niceDate(m['due_date'])),
                  InfoRow('Fee', money(m['gross_amount'])),
                  if (toNum(m['discount_amount']) > 0)
                    InfoRow('Discount', '− ${money(m['discount_amount'])}${m['discount_reason'] != null ? ' (${m['discount_reason']})' : ''}'),
                  InfoRow('To pay', money(m['net_amount']), bold: true),
                  InfoRow('Paid', money(toNum(m['paid_amount']) - toNum(m['refunded_amount']))),
                  if (toNum(m['pending_amount']) > 0) InfoRow('Waiting verification', money(m['pending_amount'])),
                  InfoRow('Balance', money(m['balance']), bold: true),
                ]),
              ),
              const SizedBox(height: 14),
              if (active && payable > 0) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final done = await showPaymentForm(context,
                        membershipId: toInt(m['id']),
                        payable: payable,
                        studentName: '${st['name']}',
                        studentPhone: '${st['phone']}');
                    if (done) await _reload();
                  },
                  icon: const Icon(Icons.currency_rupee),
                  label: Text('Take payment (${money(payable)})'),
                ),
                const SizedBox(height: 10),
              ],
              if (active)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: _whatsapp,
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text('Reminder'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                      onPressed: () => _discount(m),
                      icon: const Icon(Icons.discount_outlined, size: 18),
                      label: const Text('Discount'),
                    ),
                  ),
                ]),
              if (active && toNum(m['paid_amount']) - toNum(m['refunded_amount']) <= 0 && toNum(m['pending_amount']) <= 0)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: _cancel,
                  child: const Text('Cancel this membership'),
                ),
              const SectionTitle('Payments'),
              Panel(
                padding: EdgeInsets.zero,
                child: pays.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No payments yet', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(children: [
                        for (final p in pays)
                          ListTile(
                            onTap: () async {
                              await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => PaymentDetailScreen(paymentId: toInt(p['id']))));
                              await _reload();
                            },
                            title: Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${p['receipt_no'] ?? 'No receipt yet'} • ${methodLabel('${p['method']}')} • '
                                '${niceDate(p['paid_on'])}'),
                            trailing: Pill.paymentStatus('${p['status']}'),
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
