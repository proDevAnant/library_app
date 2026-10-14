import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

// =====================================================================
// New membership
// =====================================================================

/// Returns true when a membership was added.
Future<bool> showMembershipForm(BuildContext context, {required int studentId, required num monthlyFee}) async {
  final ok = await showFormSheet<bool>(
    context,
    title: 'New membership',
    child: _MembershipForm(studentId: studentId, monthlyFee: monthlyFee),
  );
  return ok ?? false;
}

class _MembershipForm extends StatefulWidget {
  final int studentId;
  final num monthlyFee;

  const _MembershipForm({required this.studentId, required this.monthlyFee});

  @override
  State<_MembershipForm> createState() => _MembershipFormState();
}

class _MembershipFormState extends State<_MembershipForm> {
  final _form = GlobalKey<FormState>();
  final _fee = TextEditingController();
  final _discount = TextEditingController();
  final _reason = TextEditingController();
  String _plan = 'monthly';
  bool _feeEdited = false;
  String? _start;
  String? _due;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _setDefaultFee();
  }

  @override
  void dispose() {
    _fee.dispose();
    _discount.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _setDefaultFee() {
    if (_feeEdited) return;
    final f = widget.monthlyFee * planMonths(_plan);
    _fee.text = f > 0 ? f.toStringAsFixed(0) : '';
  }

  num get _discountValue => num.tryParse(_discount.text.trim()) ?? 0;

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Api.instance.post('/library/students/${widget.studentId}/memberships', {
        'plan_type': _plan,
        'gross_amount': _fee.text.trim(),
        if (_discountValue > 0) 'discount_amount': _discount.text.trim(),
        if (_discountValue > 0) 'discount_reason': _reason.text.trim(),
        'start_date': _start,
        'due_date': _due,
      });
      if (!mounted) return;
      showSnack(context, 'Membership added');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = (num.tryParse(_fee.text.trim()) ?? 0) - _discountValue;
    final amountFmt = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _plan,
            decoration: const InputDecoration(labelText: 'Plan'),
            items: [
              for (final p in ['monthly', 'quarterly', 'half_yearly', 'yearly'])
                DropdownMenuItem(value: p, child: Text(planLabel(p))),
            ],
            onChanged: (v) => setState(() {
              _plan = v ?? 'monthly';
              _setDefaultFee();
            }),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fee,
            keyboardType: TextInputType.number,
            inputFormatters: amountFmt,
            decoration: InputDecoration(
              labelText: 'Fee (₹)',
              helperText: widget.monthlyFee > 0 ? 'Monthly fee ${money(widget.monthlyFee)} × ${planMonths(_plan)}' : null,
              errorText: _errors['gross_amount'],
            ),
            onChanged: (_) => setState(() => _feeEdited = true),
            validator: (v) => V.amount(v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _discount,
            keyboardType: TextInputType.number,
            inputFormatters: amountFmt,
            decoration: InputDecoration(labelText: 'Discount (₹, optional)', errorText: _errors['discount_amount']),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty) ? null : V.amount(v, allowZero: true),
          ),
          if (_discountValue > 0) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _reason,
              decoration: InputDecoration(labelText: 'Reason for discount *', errorText: _errors['discount_reason']),
              validator: (v) => V.required(v, 'Reason'),
            ),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () async {
                  final d = await pickDate(context);
                  if (d != null) setState(() => _start = apiDate(d));
                },
                child: Text(_start == null ? 'Start: auto' : 'Start: ${niceDate(_start)}'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                onPressed: () async {
                  final d = await pickDate(context);
                  if (d != null) setState(() => _due = apiDate(d));
                },
                child: Text(_due == null ? 'Due: start date' : 'Due: ${niceDate(_due)}'),
              ),
            ),
          ]),
          if (_errors['start_date'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_errors['start_date']!, style: const TextStyle(color: AppColors.danger)),
            ),
          const SizedBox(height: 6),
          const Text('"Auto" starts the day after the current membership ends (or today).',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          Panel(
            padding: const EdgeInsets.all(12),
            child: Text('Student pays: ${money(net < 0 ? 0 : net)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Add membership'),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Take payment
// =====================================================================

/// Returns true when a payment was saved.
Future<bool> showPaymentForm(
  BuildContext context, {
  required int membershipId,
  required num payable,
  required String studentName,
  required String studentPhone,
}) async {
  final result = await showFormSheet<Map<String, dynamic>>(
    context,
    title: 'Take payment',
    child: _PaymentForm(membershipId: membershipId, payable: payable),
  );
  if (result == null || !context.mounted) return false;

  final pay = (result['payment'] as Map).cast<String, dynamic>();
  final url = result['receipt_url']?.toString();
  if (pay['status'] == 'verified' && url != null) {
    await showReceiptActions(context,
        receiptNo: '${pay['receipt_no']}',
        amount: pay['amount'],
        url: url,
        studentName: studentName,
        studentPhone: studentPhone);
  } else {
    showSnack(context, 'Saved. Verify it after checking your bank/UPI app.');
  }
  return true;
}

/// "Receipt ready" box: open in browser or send on WhatsApp.
Future<void> showReceiptActions(
  BuildContext context, {
  required String receiptNo,
  required dynamic amount,
  required String url,
  required String studentName,
  required String studentPhone,
}) {
  final msg = 'Namaste $studentName ji,\n${money(amount)} fees mil gayi. Dhanyavaad!\nReceipt $receiptNo:\n$url';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.check_circle, color: AppColors.green, size: 44),
      title: Text('${money(amount)} received'),
      content: Text('Receipt $receiptNo is ready.', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton.icon(
          onPressed: () => openLink(ctx, url),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => openWhatsApp(ctx, studentPhone, msg),
          icon: const Icon(Icons.send),
          label: const Text('WhatsApp'),
        ),
      ],
    ),
  );
}

class _PaymentForm extends StatefulWidget {
  final int membershipId;
  final num payable;

  const _PaymentForm({required this.membershipId, required this.payable});

  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _ref = TextEditingController();
  final _notes = TextEditingController();
  final String _key = newIdempotencyKey(); // same key for retries of THIS form
  String _method = 'cash';
  String _paidOn = apiDate(DateTime.now());
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    _amount.text = widget.payable == widget.payable.roundToDouble()
        ? widget.payable.toStringAsFixed(0)
        : widget.payable.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amount.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save({bool confirmDuplicate = false}) async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/library/payments', {
        'membership_id': widget.membershipId,
        'amount': _amount.text.trim(),
        'method': _method,
        if (_method != 'cash') 'reference_no': _ref.text.trim(),
        'paid_on': _paidOn,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'idempotency_key': _key,
        if (confirmDuplicate) 'confirm_duplicate': true,
      });
      if (!mounted) return;
      Navigator.of(context).pop(r.map);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      if (e.status == 409 && e.errors.containsKey('confirm_duplicate')) {
        final again = await confirmDialog(context,
            title: 'Same payment again?', message: e.message, confirmText: 'Yes, save it');
        if (again && mounted) await _save(confirmDuplicate: true);
        return;
      }
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Payable now: ${money(widget.payable)}', style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(labelText: 'Amount (₹)', errorText: _errors['amount']),
            validator: (v) {
              final err = V.amount(v);
              if (err != null) return err;
              return num.parse(v!.trim()) > widget.payable ? 'Only ${money(widget.payable)} is payable' : null;
            },
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.payments_outlined)),
              ButtonSegment(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code_2)),
              ButtonSegment(value: 'bank_transfer', label: Text('Bank'), icon: Icon(Icons.account_balance)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          if (_method != 'cash') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _ref,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'UPI / bank transaction ID *',
                helperText: 'Saved as "waiting for verification" until you confirm the money arrived.',
                helperMaxLines: 2,
                errorText: _errors['reference_no'],
              ),
              validator: (v) => (v ?? '').trim().length < 6 ? 'Enter the transaction ID (at least 6 characters)' : null,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
            onPressed: () async {
              final d = await pickDate(context, last: DateTime.now());
              if (d != null) setState(() => _paidOn = apiDate(d));
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text('Paid on ${niceDate(_paidOn)}'),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : () => _save(),
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(_method == 'cash' ? 'Save cash payment' : 'Save (verify later)'),
          ),
        ],
      ),
    );
  }
}
