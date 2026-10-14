import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/common.dart';

/// Step 1: send a 6-digit code to the account's email.
/// Step 2: enter the code and a new password.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _otp = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    for (final c in [_phone, _code, _otp, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _who => {
        'phone': V.digits(_phone.text),
        if (_code.text.trim().isNotEmpty) 'library_code': _code.text.trim().toUpperCase(),
      };

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await job();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() => _run(() async {
        final r = await Api.instance.post('/auth/forgot-password', _who);
        if (!mounted) return;
        setState(() => _sent = true);
        showSnack(context, r.message);
      });

  Future<void> _reset() => _run(() async {
        final r = await Api.instance.post('/auth/reset-password', {
          ..._who,
          'otp': _otp.text.trim(),
          'new_password': _pass.text,
        });
        if (!mounted) return;
        showSnack(context, r.message);
        Navigator.of(context).pop();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Banner2(
                  icon: Icons.mail_outline,
                  color: AppColors.green,
                  background: AppColors.greenSoft,
                  text: 'A 6-digit code is sent to the email saved in your account. '
                      'No email saved? Ask your library admin to reset your password.',
                ),
                TextFormField(
                  controller: _phone,
                  enabled: !_sent,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]'))],
                  decoration: InputDecoration(labelText: 'Mobile number', errorText: _errors['phone']),
                  validator: V.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  enabled: !_sent,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Library code (only if you use more than one library)',
                  ),
                ),
                if (_sent) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(labelText: '6-digit code', errorText: _errors['otp']),
                    validator: (v) => (v ?? '').length == 6 ? null : 'Enter the 6-digit code',
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _pass,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'New password', errorText: _errors['new_password']),
                    validator: V.password,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass2,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirm new password'),
                    validator: (v) => v == _pass.text ? null : 'Passwords do not match',
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : (_sent ? _reset : _send),
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_sent ? 'Set new password' : 'Send code'),
                ),
                if (_sent)
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _sent = false),
                    child: const Text('Change number / send again'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
