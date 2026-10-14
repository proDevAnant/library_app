import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/paged_list.dart';

/// Money libraries paid you. "To verify" = libraries said "I paid by UPI".
class AdminPaymentsScreen extends StatefulWidget {
  const AdminPaymentsScreen({super.key});

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen> {
  bool _pendingOnly = true;
  int _v = 0;
  List<Map<String, dynamic>> _plans = [];

  @override
  void initState() {
    super.initState();
    Api.instance.get('/admin/plans').then((r) {
      if (mounted) setState(() => _plans = r.list.where((p) => p['is_trial'] != true && p['is_active'] == true).toList());
    }).catchError((Object _) {});
  }

  /// Library payments carry a note like "Plan requested: Monthly (id 2)".
  int? _requestedPlan(String? notes) {
    final m = RegExp(r'\(id (\d+)\)').firstMatch(notes ?? '');
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  Future<void> _verify(Map<String, dynamic> p) async {
    int? plan = p['subscription_id'] == null ? _requestedPlan(p['notes']?.toString()) : null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Verify ${money(p['amount'])}?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${p['library_name']} • ${methodLabel('${p['method']}')} • ${p['reference_no'] ?? ''}'),
            const SizedBox(height: 8),
            const Text('Only if this money is in your bank / UPI app.', style: TextStyle(color: AppColors.muted)),
            if (p['subscription_id'] == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: plan,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Also renew plan'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('No, only record money')),
                  for (final x in _plans)
                    DropdownMenuItem<int?>(value: toInt(x['id']), child: Text('${x['name']} (${money(x['price'])})')),
                ],
                onChanged: (v) => setD(() => plan = v),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _review(p, {'action': 'verify', if (plan != null) 'plan_id': plan});
  }

  Future<void> _reject(Map<String, dynamic> p) async {
    final why = await askText(context, title: 'Reject payment', label: 'Why?', confirmText: 'Reject', danger: true);
    if (why != null) await _review(p, {'action': 'reject', 'notes': why});
  }

  Future<void> _review(Map<String, dynamic> p, Map<String, dynamic> body) async {
    try {
      final r = await Api.instance.post('/admin/subscription-payments/${p['id']}/review', body);
      if (!mounted) return;
      showSnack(context, r.message);
      setState(() => _v++);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('To verify')),
                ButtonSegment(value: false, label: Text('All')),
              ],
              selected: {_pendingOnly},
              onSelectionChanged: (s) => setState(() => _pendingOnly = s.first),
            ),
          ),
        ),
      ),
      body: PagedList(
        key: ValueKey('$_pendingOnly|$_v'),
        fetch: (page) async => PageResult.from(await Api.instance.get('/admin/subscription-payments',
            query: {if (_pendingOnly) 'status': 'pending_verification', 'page': page})),
        header: (meta) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('${meta['total'] ?? 0} payment(s) • ${money(meta['total_amount'])}',
              style: const TextStyle(color: AppColors.muted)),
        ),
        empty: EmptyView(
          icon: Icons.verified_outlined,
          title: _pendingOnly ? 'Nothing to verify' : 'No payments yet',
        ),
        itemBuilder: (context, p) {
          final pending = p['status'] == 'pending_verification';
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text('${p['library_name']} (${p['library_code']})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Text('${methodLabel('${p['method']}')}${p['reference_no'] != null ? ' • ${p['reference_no']}' : ''} • ${niceDate(p['paid_on'])}',
                    style: const TextStyle(color: AppColors.muted)),
                if (p['notes'] != null && '${p['notes']}'.isNotEmpty)
                  Text('${p['notes']}', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                if (pending)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 42)),
                        onPressed: () => _reject(p),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                        onPressed: () => _verify(p),
                        child: const Text('Verify'),
                      ),
                    ),
                  ])
                else
                  Pill.paymentStatus('${p['status']}'),
              ]),
            ),
          );
        },
      ),
    );
  }
}
