import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/validators.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/dialogs.dart';
import 'seat_picker.dart';

/// Add a new student, or edit one when [student] is given.
/// Pops with the student id after saving.
class StudentFormScreen extends StatefulWidget {
  final Map<String, dynamic>? student;

  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  String? _gender;
  String _admission = apiDate(DateTime.now());
  String? _dob;
  SeatChoice? _seat;
  bool _busy = false;
  Map<String, String> _errors = {};

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student ?? {};
    String v(String k) => s[k] == null ? '' : '${s[k]}';
    _c = {
      for (final k in ['name', 'father_name', 'phone', 'email', 'address', 'emergency_name', 'emergency_phone', 'notes'])
        k: TextEditingController(text: v(k)),
      'monthly_fee': TextEditingController(
          text: s['monthly_fee'] == null ? '' : toNum(s['monthly_fee']).toStringAsFixed(0)),
    };
    _gender = s['gender']?.toString();
    if (s['admission_date'] != null) _admission = '${s['admission_date']}';
    _dob = s['date_of_birth']?.toString();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    String? t(String k) => _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();
    final body = <String, dynamic>{
      'name': t('name'),
      'father_name': t('father_name'),
      'phone': V.digits(_c['phone']!.text),
      'email': t('email'),
      'address': t('address'),
      'emergency_name': t('emergency_name'),
      'emergency_phone': t('emergency_phone') == null ? null : V.digits(_c['emergency_phone']!.text),
      'notes': t('notes'),
      'monthly_fee': t('monthly_fee') ?? '0',
      'gender': _gender,
      'admission_date': _admission,
      'date_of_birth': _dob,
      if (!_isEdit && _seat != null) 'seat_id': _seat!.seatId,
      if (!_isEdit && _seat != null) 'shift_id': _seat!.shiftId,
    };

    try {
      if (_isEdit) {
        await Api.instance.put('/library/students/${widget.student!['id']}', body);
        if (!mounted) return;
        showSnack(context, 'Saved');
        Navigator.of(context).pop(toInt(widget.student!['id']));
      } else {
        final r = await Api.instance.post('/library/students', body);
        if (!mounted) return;
        final st = (r.map['student'] as Map).cast<String, dynamic>();
        final login = (r.map['login'] as Map).cast<String, dynamic>();
        await showLoginDetails(
          context,
          name: '${st['name']}',
          phone: '${login['phone']}',
          libraryCode: '${login['library_code']}',
          password: '${login['password']}',
          libraryName: context.read<AuthState>().user?.library?.name ?? 'Library',
        );
        if (!mounted) return;
        Navigator.of(context).pop(toInt(st['id']));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label,
      {TextInputType? type, String? Function(String?)? validator, int maxLines = 1, List<TextInputFormatter>? fmt}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        keyboardType: type,
        maxLines: maxLines,
        inputFormatters: fmt,
        textCapitalization: type == null ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(labelText: label, errorText: _errors[key]),
        validator: validator,
      ),
    );
  }

  Widget _dateTile(String label, String? value, VoidCallback onTap, {VoidCallback? onClear}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: value != null && onClear != null
                ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
                : const Icon(Icons.calendar_today_outlined),
          ),
          child: Text(value == null ? 'Choose date' : niceDate(value)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))];
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit student' : 'Add student')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _field('name', 'Full name *', validator: (v) => V.required(v, 'Name')),
              _field('father_name', "Father's name"),
              _field('phone', 'Mobile number *', type: TextInputType.phone, validator: V.phone, fmt: digits),
              _field('monthly_fee', 'Monthly fee (₹)',
                  type: TextInputType.number,
                  fmt: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) => (v == null || v.isEmpty) ? null : V.amount(v, allowZero: true)),
              _dateTile('Admission date', _admission, () async {
                final d = await pickDate(context, initial: DateTime.tryParse(_admission));
                if (d != null) setState(() => _admission = apiDate(d));
              }),
              if (!_isEdit)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final s = await pickSeat(context);
                      if (s != null) setState(() => _seat = s);
                    },
                    icon: const Icon(Icons.event_seat_outlined),
                    label: Text(_seat == null ? 'Give a seat now (optional)' : 'Seat: ${_seat!.label}'),
                  ),
                ),
              const Divider(height: 28),
              const Text('More details (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
              _dateTile('Date of birth', _dob, () async {
                final d = await pickDate(context,
                    initial: _dob == null ? DateTime(2005) : DateTime.tryParse(_dob!), last: DateTime.now());
                if (d != null) setState(() => _dob = apiDate(d));
              }, onClear: () => setState(() => _dob = null)),
              _field('email', 'Email', type: TextInputType.emailAddress, validator: V.email),
              _field('address', 'Address', type: TextInputType.streetAddress, maxLines: 2),
              _field('emergency_name', 'Emergency contact name'),
              _field('emergency_phone', 'Emergency contact mobile',
                  type: TextInputType.phone, validator: V.optionalPhone, fmt: digits),
              _field('notes', 'Notes', type: TextInputType.multiline, maxLines: 2),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? 'Save changes' : 'Add student'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
