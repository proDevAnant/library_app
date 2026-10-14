import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import 'library_form_screen.dart';

class LibraryDetailScreen extends StatefulWidget {
  final int libraryId;

  const LibraryDetailScreen({super.key, required this.libraryId});

  @override
  State<LibraryDetailScreen> createState() => _LibraryDetailScreenState();
}

class _LibraryDetailScreenState extends State<LibraryDetailScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();

  String get _base => '/admin/libraries/${widget.libraryId}';

  Future<Map<String, dynamic>> _load() async => (await Api.instance.get(_base)).map;

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _post(String path, Map<String, dynamic> body) async {
    try {
      final r = await Api.instance.post('$_base/$path', body);
      if (!mounted) return;
      showSnack(context, r.message);
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _setStatus(String status) async {
    String? reason;
    if (status != 'active') {
      reason = await askText(context,
          title: status == 'suspended' ? 'Suspend library?' : 'Deactivate library?',
          label: 'Reason (e.g. payment not received)',
          confirmText: status == 'suspended' ? 'Suspend' : 'Deactivate',
          danger: true);
      if (reason == null) return;
    }
    await _post('status', {'status': status, if (reason != null) 'reason': reason});
  }

  Future<void> _resetAdmin(Map<String, dynamic> lib) async {
    final ok = await confirmDialog(context,
        title: 'Reset admin password?', message: 'A new password will be made. The old one stops working.', confirmText: 'Reset');
    if (!ok) return;
    try {
      final r = await Api.instance.post('$_base/reset-admin-password');
      if (!mounted) return;
      final phone = '${r.map['phone']}';
      final pass = '${r.map['password']}';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('New admin password'),
          content: Row(children: [
            SelectableText(pass, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () => Clipboard.setData(ClipboardData(text: pass))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => openWhatsApp(ctx, phone,
                  '${lib['name']} admin login\nMobile: $phone\nNew password: $pass\nLibrary code: ${lib['code']}'),
              icon: const Icon(Icons.send),
              label: const Text('WhatsApp'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _logo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600, imageQuality: 85);
    if (file == null) return;
    try {
      await Api.instance.upload('$_base/logo', 'logo', file.path);
      if (!mounted) return;
      showSnack(context, 'Logo updated');
      await _reload();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _renew() async {
    final done = await showFormSheet<bool>(context, title: 'Renew / add plan', child: _RenewForm(base: _base));
    if (done == true) await _reload();
  }

  Future<void> _recordPayment() async {
    final done = await showFormSheet<bool>(context, title: 'Record payment received', child: _PaymentForm(base: _base));
    if (done == true) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final lib = (d['library'] as Map).cast<String, dynamic>();
          final admins = (d['admins'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final subs = (d['subscriptions'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final pays = (d['subscription_payments'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final counts = (d['student_counts'] as Map? ?? {}).cast<String, dynamic>();
          final status = '${lib['status']}';
          final expired = lib['plan_expired'] == true;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Panel(
                child: Column(children: [
                  Row(children: [
                    GestureDetector(onTap: _logo, child: Avatar(url: lib['logo_url']?.toString(), name: '${lib['name']}', radius: 30)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${lib['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('Code ${lib['code']} • ${lib['city'] ?? ''}', style: const TextStyle(color: AppColors.muted)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, children: [
                          Pill(status[0].toUpperCase() + status.substring(1),
                              color: status == 'suspended' ? AppColors.danger : (status == 'deactivated' ? AppColors.muted : AppColors.green)),
                          expired
                              ? const Pill('Plan expired', color: AppColors.danger)
                              : Pill('Plan till ${niceDate(lib['plan_end'])}', color: AppColors.blue),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  InfoRow('Students', '${counts['active'] ?? 0} active, ${counts['inactive'] ?? 0} inactive'),
                  InfoRow('Owner', '${lib['owner_name'] ?? ''} ${lib['owner_phone'] ?? ''}'.trim()),
                  InfoRow('Phone', '${lib['phone'] ?? ''}'),
                  InfoRow('Address', '${lib['address'] ?? ''}'),
                  InfoRow('Seats', '${lib['total_seats'] ?? 0}'),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _renew,
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Renew plan'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                    onPressed: _recordPayment,
                    icon: const Icon(Icons.currency_rupee),
                    label: const Text('Payment'),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit details'),
                    onTap: () async {
                      final r = await Navigator.of(context)
                          .push<int>(MaterialPageRoute(builder: (_) => LibraryFormScreen(library: lib)));
                      if (r != null) await _reload();
                    },
                  ),
                  ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Change logo'), onTap: _logo),
                  ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: const Text('Reset admin password'),
                    onTap: () => _resetAdmin(lib),
                  ),
                  if (status == 'suspended' || status == 'deactivated')
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline, color: AppColors.green),
                      title: const Text('Activate library'),
                      onTap: () => _setStatus('active'),
                    )
                  else
                    ListTile(
                      leading: const Icon(Icons.pause_circle_outline, color: AppColors.danger),
                      title: const Text('Suspend library', style: TextStyle(color: AppColors.danger)),
                      subtitle: const Text('Everyone in this library is logged out at once'),
                      onTap: () => _setStatus('suspended'),
                    ),
                  if (status != 'deactivated')
                    ListTile(
                      leading: const Icon(Icons.block, color: AppColors.danger),
                      title: const Text('Deactivate permanently', style: TextStyle(color: AppColors.danger)),
                      onTap: () => _setStatus('deactivated'),
                    ),
                ]),
              ),
              const SectionTitle('Admins'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final a in admins)
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: Text('${a['name']}'),
                      subtitle: Text('${a['phone']} • last login ${a['last_login_at'] == null ? 'never' : niceDateTime(a['last_login_at'])}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.call, color: AppColors.green),
                        onPressed: () => callPhone(context, '${a['phone']}'),
                      ),
                    ),
                ]),
              ),
              const SectionTitle('Plan history'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final s in subs)
                    ListTile(
                      dense: true,
                      leading: Icon(s['is_trial'] == 1 || s['is_trial'] == true ? Icons.card_giftcard : Icons.workspace_premium_outlined,
                          color: AppColors.green),
                      title: Text('${s['plan_name']} • ${money(s['price'])}'),
                      subtitle: Text('${niceDate(s['start_date'])} – ${niceDate(s['end_date'])}'),
                      trailing: s['status'] == 'cancelled' ? const Pill('Cancelled', color: AppColors.muted) : null,
                    ),
                ]),
              ),
              const SectionTitle('Payments from this library'),
              Panel(
                padding: EdgeInsets.zero,
                child: pays.isEmpty
                    ? const Padding(padding: EdgeInsets.all(14), child: Text('No payments yet', style: TextStyle(color: AppColors.muted)))
                    : Column(children: [
                        for (final p in pays)
                          ListTile(
                            dense: true,
                            title: Text('${money(p['amount'])} • ${methodLabel('${p['method']}')}'),
                            subtitle: Text('${niceDate(p['paid_on'])}${p['reference_no'] != null ? ' • ${p['reference_no']}' : ''}'),
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

// ---------------------------------------------------------------------------

class _RenewForm extends StatefulWidget {
  final String base;

  const _RenewForm({required this.base});

  @override
  State<_RenewForm> createState() => _RenewFormState();
}

class _RenewFormState extends State<_RenewForm> {
  List<Map<String, dynamic>> _plans = [];
  int? _plan;
  bool _withPayment = true;
  String _method = 'upi';
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.instance.get('/admin/plans').then((r) {
      if (!mounted) return;
      final list = r.list.where((p) => p['is_active'] == true && p['is_trial'] != true).toList();
      setState(() {
        _plans = list;
        if (list.isNotEmpty) _pick(toInt(list.first['id']));
      });
    }).catchError((Object e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    super.dispose();
  }

  void _pick(int id) {
    _plan = id;
    final p = _plans.firstWhere((x) => toInt(x['id']) == id);
    _amount.text = toNum(p['price']).toStringAsFixed(0);
  }

  Future<void> _save() async {
    if (_plan == null) return;
    if (_withPayment && V.amount(_amount.text) != null) {
      showSnack(context, 'Enter the amount received', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('${widget.base}/subscriptions', {
        'plan_id': _plan,
        if (_withPayment)
          'payment': {
            'amount': _amount.text.trim(),
            'method': _method,
            if (_ref.text.trim().isNotEmpty) 'reference_no': _ref.text.trim(),
            'paid_on': apiDate(DateTime.now()),
          },
      });
      if (!mounted) return;
      showSnack(context, r.message);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_plans.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('The new plan starts the day after the current plan ends (or today if it has expired).',
          style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      for (final p in _plans)
        ListTile(
          onTap: () => setState(() => _pick(toInt(p['id']))),
          leading: Icon(
            _plan == toInt(p['id']) ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            color: AppColors.green,
          ),
          title: Text('${p['name']}'),
          subtitle: Text('${p['duration_days']} days • ${money(p['price'])}'),
        ),
      SwitchListTile(
        value: _withPayment,
        onChanged: (v) => setState(() => _withPayment = v),
        title: const Text('I have received the payment'),
      ),
      if (_withPayment) ...[
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount received (₹)'),
        ),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'cash', label: Text('Cash')),
            ButtonSegment(value: 'upi', label: Text('UPI')),
            ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
          ],
          selected: {_method},
          onSelectionChanged: (s) => setState(() => _method = s.first),
        ),
        const SizedBox(height: 10),
        TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Transaction ID (optional)')),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Renew'),
      ),
    ]);
  }
}

class _PaymentForm extends StatefulWidget {
  final String base;

  const _PaymentForm({required this.base});

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'upi';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (V.amount(_amount.text) != null) {
      showSnack(context, 'Enter a valid amount', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.post('${widget.base}/subscription-payments', {
        'amount': _amount.text.trim(),
        'method': _method,
        if (_ref.text.trim().isNotEmpty) 'reference_no': _ref.text.trim(),
        'paid_on': apiDate(DateTime.now()),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, 'Payment recorded');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Only records the money. Use "Renew plan" to extend their plan.', style: TextStyle(color: AppColors.muted)),
      const SizedBox(height: 12),
      TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹)')),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'cash', label: Text('Cash')),
          ButtonSegment(value: 'upi', label: Text('UPI')),
          ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
        ],
        selected: {_method},
        onSelectionChanged: (s) => setState(() => _method = s.first),
      ),
      const SizedBox(height: 10),
      TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Transaction ID (optional)')),
      const SizedBox(height: 10),
      TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Note (optional)')),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Save payment'),
      ),
    ]);
  }
}
