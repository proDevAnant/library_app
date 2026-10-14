import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

/// Student edits only what the library allows (email, address, emergency contact).
class StudentProfileEditScreen extends StatefulWidget {
  const StudentProfileEditScreen({super.key});

  @override
  State<StudentProfileEditScreen> createState() => _StudentProfileEditScreenState();
}

class _StudentProfileEditScreenState extends State<StudentProfileEditScreen> {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  List<String> _editable = [];
  Map<String, dynamic> _s = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = {};

  static const _labels = {
    'email': 'Email',
    'address': 'Address',
    'emergency_name': 'Emergency contact name',
    'emergency_phone': 'Emergency contact mobile',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await Api.instance.get('/student/home');
      final s = (r.map['student'] as Map).cast<String, dynamic>();
      final ed = (r.map['editable'] as List? ?? []).map((e) => '$e').toList();
      if (!mounted) return;
      setState(() {
        _s = s;
        _editable = ed;
        for (final k in ed) {
          _c[k] = TextEditingController(text: s[k] == null ? '' : '${s[k]}');
        }
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        for (final k in _editable)
          k: _c[k]!.text.trim().isEmpty ? null : (k == 'emergency_phone' ? V.digits(_c[k]!.text) : _c[k]!.text.trim()),
      };
      await Api.instance.put('/student/profile', body);
      if (!mounted) return;
      showSnack(context, 'Profile updated');
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
    return Scaffold(
      appBar: AppBar(title: const Text('My profile')),
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!, onRetry: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _load();
                })
              : Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Panel(
                      child: Column(children: [
                        InfoRow('Name', '${_s['name']}'),
                        InfoRow('Student ID', '${_s['student_code']}'),
                        InfoRow('Mobile', '${_s['phone']}'),
                        InfoRow("Father's name", '${_s['father_name'] ?? ''}'),
                      ]),
                    ),
                    const SizedBox(height: 6),
                    const Text('To change these, ask the library.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 16),
                    if (_editable.isEmpty)
                      const Text('Your library does not allow profile changes from the app.',
                          style: TextStyle(color: AppColors.muted))
                    else ...[
                      for (final k in _editable)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextFormField(
                            controller: _c[k],
                            keyboardType: k == 'email'
                                ? TextInputType.emailAddress
                                : (k == 'emergency_phone' ? TextInputType.phone : TextInputType.text),
                            inputFormatters: k == 'emergency_phone' ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))] : null,
                            maxLines: k == 'address' ? 2 : 1,
                            decoration: InputDecoration(labelText: _labels[k] ?? k, errorText: _errors[k]),
                            validator: k == 'email' ? V.email : (k == 'emergency_phone' ? V.optionalPhone : null),
                          ),
                        ),
                      FilledButton(
                        onPressed: _busy ? null : _save,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Save'),
                      ),
                    ],
                  ]),
                ),
    );
  }
}
