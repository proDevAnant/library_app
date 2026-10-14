import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/helpers.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/common.dart';

/// Create a library (with its admin login and first plan), or edit one when [library] is given.
/// Pops with the library id.
class LibraryFormScreen extends StatefulWidget {
  final Map<String, dynamic>? library;

  const LibraryFormScreen({super.key, this.library});

  @override
  State<LibraryFormScreen> createState() => _LibraryFormScreenState();
}

class _LibraryFormScreenState extends State<LibraryFormScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c;
  List<Map<String, dynamic>> _plans = [];
  int? _planId;
  bool _busy = false;
  Map<String, String> _errors = {};

  bool get _isEdit => widget.library != null;

  static const _libFields = ['name', 'code', 'address', 'city', 'state', 'pincode', 'phone', 'email', 'owner_name', 'owner_phone', 'receipt_prefix'];
  static const _adminFields = ['admin_name', 'admin_phone', 'admin_email'];

  @override
  void initState() {
    super.initState();
    final l = widget.library ?? {};
    _c = {for (final k in [..._libFields, ..._adminFields]) k: TextEditingController(text: l[k] == null ? '' : '${l[k]}')};
    if (!_isEdit) _loadPlans();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final r = await Api.instance.get('/admin/plans');
      final active = r.list.where((p) => p['is_active'] == true).toList();
      if (!mounted) return;
      setState(() {
        _plans = active;
        final trial = active.where((p) => p['is_trial'] == true).toList();
        _planId = trial.isNotEmpty ? toInt(trial.first['id']) : (active.isNotEmpty ? toInt(active.first['id']) : null);
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  String? _t(String k) => _c[k]!.text.trim().isEmpty ? null : _c[k]!.text.trim();

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      if (_isEdit) {
        final body = <String, dynamic>{
          for (final k in _libFields.where((k) => k != 'code')) k: _t(k),
        };
        if (body['phone'] != null) body['phone'] = V.digits(body['phone']);
        if (body['owner_phone'] != null) body['owner_phone'] = V.digits(body['owner_phone']);
        if (body['receipt_prefix'] == null) body.remove('receipt_prefix'); // can't be blank
        await Api.instance.put('/admin/libraries/${widget.library!['id']}', body);
        if (!mounted) return;
        showSnack(context, 'Saved');
        Navigator.of(context).pop(toInt(widget.library!['id']));
      } else {
        final body = <String, dynamic>{
          for (final k in [..._libFields, ..._adminFields]) k: _t(k),
          'plan_id': _planId,
        };
        for (final k in ['phone', 'owner_phone', 'admin_phone']) {
          if (body[k] != null) body[k] = V.digits(body[k]);
        }
        body.removeWhere((k, v) => v == null);
        final r = await Api.instance.post('/admin/libraries', body);
        if (!mounted) return;
        final login = (r.map['admin_login'] as Map).cast<String, dynamic>();
        final lib = (r.map['library'] as Map).cast<String, dynamic>();
        await _showLogin(lib, login);
        if (!mounted) return;
        Navigator.of(context).pop(toInt(lib['id']));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showLogin(Map<String, dynamic> lib, Map<String, dynamic> login) {
    final msg = 'Namaste ${_c['admin_name']!.text.trim()} ji,\n'
        'Aapki library "${lib['name']}" Library Manager app par shuru ho gayi hai.\n'
        'Mobile: ${login['phone']}\nPassword: ${login['password']}\nLibrary code: ${login['library_code']}\n'
        'Login ke baad password badal lein.';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Library created'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Share this admin login now. The password is shown only once.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          Text('Library code: ${login['library_code']}'),
          Text('Mobile: ${login['phone']}'),
          Row(children: [
            const Text('Password: '),
            SelectableText('${login['password']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () => Clipboard.setData(ClipboardData(text: '${login['password']}')),
            ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
            onPressed: () => openWhatsApp(ctx, '${login['phone']}', msg),
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp'),
          ),
        ],
      ),
    );
  }

  Widget _f(String key, String label, {TextInputType? type, String? Function(String?)? validator, bool caps = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _c[key],
        keyboardType: type,
        textCapitalization: caps ? TextCapitalization.characters : (type == null ? TextCapitalization.words : TextCapitalization.none),
        decoration: InputDecoration(labelText: label, errorText: _errors[key]),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit library' : 'New library')),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Library', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              _f('name', 'Library name *', validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 letters' : null),
              if (!_isEdit)
                _f('code', 'Library code (optional, e.g. LKO01)', caps: true,
                    validator: (v) => (v == null || v.isEmpty || RegExp(r'^[A-Za-z0-9]{3,10}$').hasMatch(v))
                        ? null
                        : '3–10 letters/numbers'),
              _f('city', 'City'),
              _f('address', 'Address', type: TextInputType.streetAddress),
              _f('state', 'State'),
              _f('pincode', 'Pincode', type: TextInputType.number,
                  validator: (v) => (v == null || v.isEmpty || RegExp(r'^\d{6}$').hasMatch(v)) ? null : '6 digits'),
              _f('phone', 'Library phone', type: TextInputType.phone, validator: V.optionalPhone),
              _f('email', 'Library email', type: TextInputType.emailAddress, validator: V.email),
              _f('owner_name', 'Owner name'),
              _f('owner_phone', 'Owner mobile', type: TextInputType.phone, validator: V.optionalPhone),
              _f('receipt_prefix', 'Receipt prefix (e.g. LSP)', caps: true,
                  validator: (v) => (v == null || v.isEmpty || RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(v)) ? null : '1–10 letters/numbers'),
              if (!_isEdit) ...[
                const Divider(height: 28),
                const Text('Library admin login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                _f('admin_name', 'Admin name *', validator: (v) => V.required(v, 'Admin name')),
                _f('admin_phone', 'Admin mobile *', type: TextInputType.phone, validator: V.phone),
                _f('admin_email', 'Admin email (for password reset)', type: TextInputType.emailAddress, validator: V.email),
                const SizedBox(height: 4),
                DropdownButtonFormField<int>(
                  initialValue: _planId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'First plan'),
                  items: [
                    for (final p in _plans)
                      DropdownMenuItem(
                        value: toInt(p['id']),
                        child: Text('${p['name']} • ${p['duration_days']} days • ${money(p['price'])}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _planId = v),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_isEdit ? 'Save changes' : 'Create library'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
