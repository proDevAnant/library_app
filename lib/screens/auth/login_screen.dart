import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../state/auth_state.dart';
import '../../widgets/common.dart';
import '../../widgets/decor.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  bool _showCode = false;
  bool _hide = true;
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notice = context.read<AuthState>().loginNotice;
      if (notice != null && mounted) showSnack(context, notice, error: true);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errors = {});
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().login(
            V.digits(_phone.text),
            _password.text,
            libraryCode: _showCode ? _code.text.trim().toUpperCase() : null,
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409 && e.errors.containsKey('library_code')) {
        setState(() => _showCode = true);
      }
      setState(() => _errors = e.errors);
      showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Reading-room header
            RoomPanel(
              radius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              padding: EdgeInsets.fromLTRB(24, top + 36, 24, 40),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.local_library_rounded, size: 34, color: AppColors.green),
                    ),
                    const SizedBox(height: 22),
                    Text('Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 4),
                    const Text('Log in with the mobile number your library registered.',
                        style: TextStyle(color: Colors.white70, fontSize: 15)),
                  ],
                ),
              ),
            ),
            Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(15)],
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Mobile number',
                          prefixIcon: const Icon(Icons.phone_iphone),
                          errorText: _errors['phone'],
                        ),
                        validator: V.phone,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: _showCode ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: (_) => _showCode ? null : _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _errors['password'],
                          suffixIcon: IconButton(
                            tooltip: _hide ? 'Show password' : 'Hide password',
                            icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                      if (_showCode) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Library code (e.g. LUC01)',
                            prefixIcon: const Icon(Icons.qr_code_2),
                            errorText: _errors['library_code'],
                            helperText: 'Ask your library if you don\'t know it',
                          ),
                          validator: (v) => V.required(v, 'Library code'),
                        ),
                      ],
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : const Text('Log in', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                            child: const Text('Forgot password?'),
                          ),
                          if (!_showCode)
                            TextButton(
                              onPressed: () => setState(() => _showCode = true),
                              child: const Text('Use library code'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }
}
