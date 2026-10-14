import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/paged_list.dart';
import '../library/student_profile_screen.dart';
import 'payment_detail_screen.dart';

/// Fees tab: payments to verify, who owes money, and all payments.
class FeesScreen extends StatelessWidget {
  const FeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fees'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'To verify'),
              Tab(text: 'Dues'),
              Tab(text: 'Payments'),
            ],
          ),
        ),
        body: const TabBarView(children: [_VerifyTab(), _DuesTab(), _PaymentsTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _VerifyTab extends StatefulWidget {
  const _VerifyTab();

  @override
  State<_VerifyTab> createState() => _VerifyTabState();
}

class _VerifyTabState extends State<_VerifyTab> with AutomaticKeepAliveClientMixin {
  int _v = 0;

  @override
  bool get wantKeepAlive => true;

  Future<void> _review(Map<String, dynamic> p, bool verify) async {
    String? notes;
    if (verify) {
      final ok = await confirmDialog(context,
          title: 'Verify ${money(p['amount'])}?',
          message: 'Only if you can see transaction ${p['reference_no']} in your bank / UPI app.',
          confirmText: 'Verify');
      if (!ok) return;
    } else {
      notes = await askText(context,
          title: 'Reject payment', label: 'Why? (e.g. not received)', confirmText: 'Reject', danger: true);
      if (notes == null) return;
    }
    try {
      final r = await Api.instance.post('/library/payments/${p['id']}/review', {
        'action': verify ? 'verify' : 'reject',
        if (notes != null) 'notes': notes,
      });
      if (!mounted) return;
      showSnack(context, r.message);
      setState(() => _v++);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PagedList(
      key: ValueKey(_v),
      fetch: (page) async => PageResult.from(await Api.instance
          .get('/library/payments', query: {'status': 'pending_verification', 'page': page})),
      header: (meta) => toInt(meta['total']) == 0
          ? const SizedBox.shrink()
          : Banner2(
              icon: Icons.info_outline,
              color: AppColors.blue,
              background: const Color(0xFFE8F0FE),
              text: '${meta['total']} payment(s), ${money(meta['total_pending'])}. Check each transaction ID in your bank/UPI app first.',
            ),
      empty: const EmptyView(icon: Icons.verified_outlined, title: 'Nothing to verify', subtitle: 'All UPI/bank payments are checked.'),
      itemBuilder: (context, p) => Card(
        elevation: 0,
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text('${p['student_name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ]),
              const SizedBox(height: 4),
              Text('${methodLabel('${p['method']}')} • Txn ${p['reference_no']} • ${niceDate(p['paid_on'])}',
                  style: const TextStyle(color: AppColors.muted)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 42)),
                    onPressed: () => _review(p, false),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: () => _review(p, true),
                    child: const Text('Verify'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _DuesTab extends StatefulWidget {
  const _DuesTab();

  @override
  State<_DuesTab> createState() => _DuesTabState();
}

class _DuesTabState extends State<_DuesTab> with AutomaticKeepAliveClientMixin {
  final _loader = GlobalKey<AsyncLoaderState<ApiResponse>>();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AsyncLoader<ApiResponse>(
      key: _loader,
      load: () => Api.instance.get('/library/reports/dues'),
      builder: (context, r, reload) {
        final rows = r.list;
        if (rows.isEmpty) {
          return ListView(children: const [
            EmptyView(icon: Icons.celebration_outlined, title: 'No pending fees', subtitle: 'Every active student has paid.'),
          ]);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: rows.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Text('${r.meta['students']} student(s) owe ${money(r.meta['total_due'])}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger)),
              );
            }
            final d = rows[i - 1];
            final over = toInt(d['days_overdue']);
            return Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                onTap: () async {
                  await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => StudentProfileScreen(studentId: toInt(d['student_id']))));
                  await _loader.currentState?.reload();
                },
                title: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${d['student_code']} • ${over > 0 ? '$over days overdue' : 'due ${niceDate(d['oldest_due'])}'}',
                    style: TextStyle(color: over > 0 ? AppColors.danger : AppColors.muted)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(money(d['due']), style: const TextStyle(fontWeight: FontWeight.w800)),
                  IconButton(
                    tooltip: 'WhatsApp reminder',
                    icon: const Icon(Icons.chat, color: AppColors.green),
                    onPressed: () => openLink(context, '${d['whatsapp_url']}'),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _PaymentsTab extends StatefulWidget {
  const _PaymentsTab();

  @override
  State<_PaymentsTab> createState() => _PaymentsTabState();
}

class _PaymentsTabState extends State<_PaymentsTab> with AutomaticKeepAliveClientMixin {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _v = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search receipt, name, transaction ID',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400), () {
                if (mounted) setState(() => _query = v.trim());
              });
            },
          ),
        ),
        Expanded(
          child: PagedList(
            key: ValueKey('$_query|$_v'),
            fetch: (page) async =>
                PageResult.from(await Api.instance.get('/library/payments', query: {'search': _query, 'page': page})),
            header: (meta) => Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('Verified total ${money(meta['total_verified'])}',
                  style: const TextStyle(color: AppColors.muted)),
            ),
            empty: const EmptyView(icon: Icons.receipt_long_outlined, title: 'No payments found'),
            itemBuilder: (context, p) => Card(
              elevation: 0,
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                onTap: () async {
                  await Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => PaymentDetailScreen(paymentId: toInt(p['id']))));
                  if (mounted) setState(() => _v++);
                },
                title: Text('${p['student_name']} • ${money(p['amount'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p['receipt_no'] ?? 'No receipt yet'} • ${methodLabel('${p['method']}')} • ${niceDate(p['paid_on'])}'),
                trailing: Pill.paymentStatus('${p['status']}'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
