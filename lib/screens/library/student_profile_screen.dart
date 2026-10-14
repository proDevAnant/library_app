import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../state/auth_state.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import '../fees/fee_forms.dart';
import '../fees/membership_detail_screen.dart';
import '../fees/payment_detail_screen.dart';
import 'seat_picker.dart';
import 'student_form_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final int studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  final _loader = GlobalKey<AsyncLoaderState<Map<String, dynamic>>>();
  Map<String, dynamic>? _last;

  int get _id => widget.studentId;

  Future<Map<String, dynamic>> _load() async {
    final r = await Api.instance.get('/library/students/$_id');
    if (mounted) setState(() => _last = r.map); // keeps the top-right menu up to date
    return r.map;
  }

  Future<void> _reload() async => _loader.currentState?.reload();

  Future<void> _run(Future<ApiResponse> Function() job, {String? ok}) async {
    try {
      final r = await job();
      if (!mounted) return;
      showSnack(context, ok ?? r.message);
      await _reload();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  // ---------------------------------------------------------------- actions

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take photo'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (file == null || !mounted) return;
    showSnack(context, 'Uploading photo...');
    await _run(() => Api.instance.upload('/library/students/$_id/photo', 'photo', file.path), ok: 'Photo updated');
  }

  Future<void> _edit(Map<String, dynamic> student) async {
    final saved = await Navigator.of(context)
        .push<int>(MaterialPageRoute(builder: (_) => StudentFormScreen(student: student)));
    if (saved != null) await _reload();
  }

  Future<void> _giveSeat({int? shiftId, bool change = false}) async {
    final choice = await pickSeat(context, shiftId: shiftId);
    if (choice == null || !mounted) return;
    await _run(() => Api.instance.post('/library/students/$_id/seat', {
          'seat_id': choice.seatId,
          'shift_id': choice.shiftId,
          'reason': change ? 'seat change' : 'seat given',
        }), ok: 'Seat ${choice.label} saved');
  }

  Future<void> _releaseSeat(Map<String, dynamic> seat) async {
    final ok = await confirmDialog(context,
        title: 'Free seat ${seat['seat_no']}?',
        message: 'The student will no longer have this seat in the ${seat['shift_name']} shift.',
        confirmText: 'Free seat',
        danger: true);
    if (!ok) return;
    await _run(() => Api.instance.post('/library/students/$_id/seat/release', {
          'shift_id': seat['shift_id'],
          'reason': 'released by admin',
        }));
  }

  Future<void> _resetPassword(Map<String, dynamic> s) async {
    final ok = await confirmDialog(context,
        title: 'Reset password?', message: 'A new password will be made and the old one will stop working.', confirmText: 'Reset');
    if (!ok) return;
    try {
      final r = await Api.instance.post('/library/students/$_id/reset-password');
      if (!mounted) return;
      await showLoginDetails(
        context,
        name: '${s['name']}',
        phone: '${r.map['phone']}',
        libraryCode: '${r.map['library_code']}',
        password: '${r.map['password']}',
        libraryName: context.read<AuthState>().user?.library?.name ?? 'Library',
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> s) async {
    if (s['status'] == 'active') {
      final reason = await askText(context,
          title: 'Deactivate ${s['name']}?',
          label: 'Reason (e.g. left the library)',
          confirmText: 'Deactivate',
          danger: true);
      if (reason == null) return;
      await _run(() => Api.instance.post('/library/students/$_id/status', {'status': 'inactive', 'reason': reason}));
    } else {
      await _run(() => Api.instance.post('/library/students/$_id/status', {'status': 'active'}));
    }
  }

  Future<void> _idCard() async {
    try {
      final r = await Api.instance.get('/library/students/$_id/id-card');
      if (mounted) await openLink(context, '${r.map['print_url']}');
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  Future<void> _takePayment(Map<String, dynamic> s, List<Map<String, dynamic>> memberships) async {
    final payable = memberships.where((m) => m['status'] == 'active' && toNum(m['balance']) > 0).toList();
    if (payable.isEmpty) {
      final add = await confirmDialog(context,
          title: 'No fees due', message: 'There is nothing to pay. Add a new membership first?', confirmText: 'Add membership');
      if (add && mounted) await _addMembership(s);
      return;
    }
    final m = payable.length == 1 ? payable.first : await _chooseMembership(payable);
    if (m == null || !mounted) return;
    final done = await showPaymentForm(
      context,
      membershipId: toInt(m['id']),
      payable: toNum(m['balance']),
      studentName: '${s['name']}',
      studentPhone: '${s['phone']}',
    );
    if (done) await _reload();
  }

  Future<Map<String, dynamic>?> _chooseMembership(List<Map<String, dynamic>> list) {
    return showFormSheet<Map<String, dynamic>>(
      context,
      title: 'Which membership?',
      child: Column(
        children: [
          for (final m in list)
            ListTile(
              title: Text('${planLabel('${m['plan_type']}')} • ${niceDate(m['start_date'])}'),
              subtitle: Text('Balance ${money(m['balance'])}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
  }

  Future<void> _addMembership(Map<String, dynamic> s) async {
    final done = await showMembershipForm(context, studentId: _id, monthlyFee: toNum(s['monthly_fee']));
    if (done) await _reload();
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final s = (_last?['student'] as Map?)?.cast<String, dynamic>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student'),
        actions: [
          if (s != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _edit(s);
                    break;
                  case 'idcard':
                    _idCard();
                    break;
                  case 'password':
                    _resetPassword(s);
                    break;
                  case 'status':
                    _toggleStatus(s);
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit details')),
                const PopupMenuItem(value: 'idcard', child: Text('ID card (print)')),
                const PopupMenuItem(value: 'password', child: Text('Reset password')),
                PopupMenuItem(value: 'status', child: Text(s['status'] == 'active' ? 'Deactivate' : 'Activate')),
              ],
            ),
        ],
      ),
      body: AsyncLoader<Map<String, dynamic>>(
        key: _loader,
        load: _load,
        builder: (context, d, reload) {
          final st = (d['student'] as Map).cast<String, dynamic>();
          final seats = (d['current_seats'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final mems = (d['memberships'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final pays = (d['payments'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final hist = (d['seat_history'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
          final active = st['status'] == 'active';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              // ---- header
              Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _changePhoto,
                          child: Stack(
                            children: [
                              Avatar(url: st['photo_url']?.toString(), name: '${st['name']}', radius: 36),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${st['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${st['student_code']}', style: const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Row(children: [
                                active ? const Pill('Active') : const Pill('Inactive', color: AppColors.muted),
                                const SizedBox(width: 8),
                                DueText(d['balance_due']),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: () => callPhone(context, '${st['phone']}'),
                            icon: const Icon(Icons.call, size: 18),
                            label: const Text('Call'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                            onPressed: () => openWhatsApp(context, '${st['phone']}', 'Namaste ${st['name']} ji, '),
                            icon: const Icon(Icons.chat, size: 18),
                            label: const Text('WhatsApp'),
                          ),
                        ),
                      ],
                    ),
                    if (active) ...[
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        onPressed: () => _takePayment(st, mems),
                        icon: const Icon(Icons.currency_rupee),
                        label: const Text('Take payment'),
                      ),
                    ],
                  ],
                ),
              ),

              // ---- seats
              SectionTitle('Seat',
                  trailing: active
                      ? TextButton.icon(onPressed: () => _giveSeat(), icon: const Icon(Icons.add, size: 18), label: const Text('Add'))
                      : null),
              Panel(
                padding: EdgeInsets.zero,
                child: seats.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No seat given', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (final seat in seats)
                            ListTile(
                              leading: const Icon(Icons.event_seat, color: AppColors.green),
                              title: Text('Seat ${seat['seat_no']}'),
                              subtitle: Text('${seat['shift_name']} • ${seat['start_time']}–${seat['end_time']}'),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) => v == 'change'
                                    ? _giveSeat(shiftId: toInt(seat['shift_id']), change: true)
                                    : _releaseSeat(seat),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'change', child: Text('Change seat')),
                                  PopupMenuItem(value: 'release', child: Text('Free this seat')),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),

              // ---- memberships
              SectionTitle('Memberships',
                  trailing: active
                      ? TextButton.icon(
                          onPressed: () => _addMembership(st), icon: const Icon(Icons.add, size: 18), label: const Text('New'))
                      : null),
              if (mems.isEmpty)
                const Panel(child: Text('No membership yet. Tap "New" to add one.', style: TextStyle(color: AppColors.muted)))
              else
                for (final m in mems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => MembershipDetailScreen(membershipId: toInt(m['id']))));
                          await _reload();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(planLabel('${m['plan_type']}'),
                                      style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Pill.feeStatus(_feeStatus(m)),
                              ]),
                              const SizedBox(height: 4),
                              Text('${niceDate(m['start_date'])} – ${niceDate(m['end_date'])}',
                                  style: const TextStyle(color: AppColors.muted)),
                              const SizedBox(height: 6),
                              Text('Fee ${money(m['net_amount'])} • Paid ${money(toNum(m['paid_amount']) - toNum(m['refunded_amount']))}'
                                  '${toNum(m['balance']) > 0 ? ' • Due ${money(m['balance'])}' : ''}'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

              // ---- payments
              const SectionTitle('Payments'),
              Panel(
                padding: EdgeInsets.zero,
                child: pays.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: Text('No payments yet', style: TextStyle(color: AppColors.muted)),
                      )
                    : Column(
                        children: [
                          for (final p in pays)
                            ListTile(
                              onTap: () async {
                                await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => PaymentDetailScreen(paymentId: toInt(p['id']))));
                                await _reload();
                              },
                              leading: const Icon(Icons.receipt_long_outlined, color: AppColors.green),
                              title: Text(money(p['amount']), style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${p['receipt_no'] ?? 'No receipt yet'} • ${methodLabel('${p['method']}')} • ${niceDate(p['paid_on'])}'),
                              trailing: Pill.paymentStatus('${p['status']}'),
                            ),
                        ],
                      ),
              ),

              // ---- details
              const SectionTitle('Details'),
              Panel(
                child: Column(children: [
                  InfoRow('Mobile', '${st['phone']}'),
                  InfoRow("Father's name", '${st['father_name'] ?? ''}'),
                  InfoRow('Monthly fee', money(st['monthly_fee'])),
                  InfoRow('Admission', niceDate(st['admission_date'])),
                  InfoRow('Email', '${st['email'] ?? ''}'),
                  InfoRow('Address', '${st['address'] ?? ''}'),
                  InfoRow('Emergency', '${st['emergency_name'] ?? ''} ${st['emergency_phone'] ?? ''}'.trim()),
                  if ((st['notes'] ?? '').toString().isNotEmpty) InfoRow('Notes', '${st['notes']}'),
                ]),
              ),

              // ---- seat history
              if (hist.isNotEmpty) ...[
                const SectionTitle('Seat history'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final h in hist)
                        ListTile(
                          dense: true,
                          title: Text('Seat ${h['seat_no']} • ${h['shift_name']}'),
                          subtitle: Text('${niceDateTime(h['started_at'])} → '
                              '${h['ended_at'] == null ? 'now' : niceDateTime(h['ended_at'])}'
                              '${h['end_reason'] != null ? ' (${h['end_reason']})' : ''}'),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// The profile's membership rows come from the balance view; work out the label here.
  String _feeStatus(Map<String, dynamic> m) {
    if (m['status'] == 'cancelled') return 'cancelled';
    final paid = toNum(m['paid_amount']) - toNum(m['refunded_amount']);
    if (paid >= toNum(m['net_amount']) - 0.001) return 'paid';
    if (paid > 0) return 'partial';
    final due = DateTime.tryParse('${m['due_date']}');
    final now = DateTime.now();
    return due != null && due.isBefore(DateTime(now.year, now.month, now.day)) ? 'overdue' : 'pending';
  }
}
