import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import 'fee_forms.dart';

class PaymentDetailScreen extends StatefulWidget {
  final int paymentId;

  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();

  String get _base => '/library/payments/${widget.paymentId}';

  Future<Map<String, dynamic>> _load() async => (await Api.instance.get(_base)).map;

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await Api.instance.post('$_base/$path', body);
      if (!mounted) return;
      showSnack(context, r.message);
      await _loader.currentState?.reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _verify() async {
    final ok = await confirmDialog(context,
        title: 'Money received?',
        message: 'Verify only after you see this amount in your bank / UPI app. A receipt will be made.',
        confirmText: 'Yes, verify');
    if (ok) await _post('review', {'action': 'verify'});
  }

  Future<void> _reject() async {
    final why = await askText(context,
        title: 'Reject payment', label: 'Why? (e.g. not received in bank)', confirmText: 'Reject', danger: true);
    if (why != null) await _post('review', {'action': 'reject', 'notes': why});
  }

  Future<void> _void() async {
    final why = await askText(context,
        title: 'Void this payment?',
        label: 'Reason (e.g. entered by mistake)',
        hint: 'The receipt number stays used and will show VOID',
        confirmText: 'Void',
        minLength: 5,
        danger: true);
    if (why != null) await _post('void', {'reason': why});
  }

  Future<void> _refund(num maxAmount) async {
    final done = await showFormSheet<bool>(context, title: 'Refund', child: _RefundForm(base: _base, max: maxAmount));
    if (done == true) await _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final p = (d['payment'] as Map).cast<String, dynamic>();
          final st = (d['student'] as Map).cast<String, dynamic>();
          final m = (d['membership'] as Map).cast<String, dynamic>();
          final refunds = (d['refunds'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final hist = (d['history'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final status = '${p['status']}';
          final url = d['receipt_url']?.toString();
          final refundable = toNum(p['amount']) - toNum(p['refunded']);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Panel(
                child: Column(
                  children: [
                    Text(money(p['amount']), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    Pill.paymentStatus(status),
                    const SizedBox(height: 12),
                    InfoRow('Student', '${st['name']} (${st['code']})'),
                    InfoRow('Receipt no.', '${p['receipt_no'] ?? '-'}'),
                    InfoRow('Method', methodLabel('${p['method']}')),
                    if (p['reference_no'] != null) InfoRow('Transaction ID', '${p['reference_no']}'),
                    InfoRow('Paid on', niceDate(p['paid_on'])),
                    InfoRow('Membership', '${planLabel('${m['plan_type']}')}, ${niceDate(m['start_date'])}'),
                    if (toNum(p['refunded']) > 0) InfoRow('Refunded', money(p['refunded'])),
                    if (p['notes'] != null && '${p['notes']}'.isNotEmpty) InfoRow('Note', '${p['notes']}'),
                    if (p['void_reason'] != null) InfoRow('Void reason', '${p['void_reason']}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (status == 'pending_verification') ...[
                const Banner2(
                  icon: Icons.info_outline,
                  color: AppColors.blue,
                  background: Color(0xFFE8F0FE),
                  text: 'Open your bank or UPI app and check this transaction ID. Verify only if the money has arrived.',
                ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 48)),
                      onPressed: _reject,
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                      onPressed: _verify,
                      icon: const Icon(Icons.verified),
                      label: const Text('Verify'),
                    ),
                  ),
                ]),
              ],

              if (url != null && (status == 'verified' || status == 'void')) ...[
                FilledButton.icon(
                  onPressed: () => showReceiptActions(context,
                      receiptNo: '${p['receipt_no']}',
                      amount: p['amount'],
                      url: url,
                      studentName: '${st['name']}',
                      studentPhone: '${st['phone']}'),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Receipt: open / WhatsApp'),
                ),
                const SizedBox(height: 10),
              ],

              if (status == 'verified')
                Row(children: [
                  if (refundable > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                        onPressed: () => _refund(refundable),
                        icon: const Icon(Icons.undo),
                        label: const Text('Refund'),
                      ),
                    ),
                  if (refundable > 0 && refunds.isEmpty) const SizedBox(width: 10),
                  if (refunds.isEmpty)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 46)),
                        onPressed: _void,
                        icon: const Icon(Icons.block),
                        label: const Text('Void (mistake)'),
                      ),
                    ),
                ]),

              if (refunds.isNotEmpty) ...[
                const SectionTitle('Refunds'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final r in refunds)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.undo, color: AppColors.warn),
                        title: Text('${money(r['amount'])} • ${methodLabel('${r['method']}')}'),
                        subtitle: Text('${niceDate(r['refunded_on'])} • ${r['reason']}'),
                      ),
                  ]),
                ),
              ],

              const SectionTitle('History'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final h in hist)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 20),
                      title: Text(_actionLabel('${h['action']}')),
                      subtitle: Text('${niceDateTime(h['at'])}${h['by'] != null ? ' • ${h['by']}' : ''}'),
                    ),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  String _actionLabel(String a) => switch (a) {
        'payment.create' => 'Payment recorded',
        'payment.verify' => 'Verified',
        'payment.reject' => 'Rejected',
        'payment.void' => 'Voided',
        'payment.refund' => 'Refund given',
        _ => a,
      };
}

class _RefundForm extends StatefulWidget {
  final String base;
  final num max;

  const _RefundForm({required this.base, required this.max});

  @override
  State<_RefundForm> createState() => _RefundFormState();
}

class _RefundFormState extends State<_RefundForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  String _method = 'cash';
  String _effect = 'reduce_fee';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.post('${widget.base}/refund', {
        'amount': _amount.text.trim(),
        'method': _method,
        'reason': _reason.text.trim(),
        'effect': _effect,
      });
      if (!mounted) return;
      showSnack(context, 'Refund recorded');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Up to ${money(widget.max)} can be refunded.', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: const InputDecoration(labelText: 'Refund amount (₹)'),
            validator: (v) {
              final e = V.amount(v);
              if (e != null) return e;
              return num.parse(v!.trim()) > widget.max ? 'Max ${money(widget.max)}' : null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Given back by'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank transfer')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _effect,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'What happens to the fee?'),
            items: const [
              DropdownMenuItem(value: 'reduce_fee', child: Text('Lower the fee (student stays)')),
              DropdownMenuItem(value: 'cancel_membership', child: Text('Cancel membership (full refund)')),
              DropdownMenuItem(value: 'keep_due', child: Text('Keep fee same (student owes again)')),
            ],
            onChanged: (v) => setState(() => _effect = v ?? 'reduce_fee'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reason,
            decoration: const InputDecoration(labelText: 'Reason *'),
            validator: (v) => (v ?? '').trim().length < 3 ? 'Write a reason' : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Save refund'),
          ),
        ],
      ),
    );
  }
}
