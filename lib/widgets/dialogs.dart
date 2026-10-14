import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/helpers.dart';
import '../core/theme.dart';

/// Asks for a short text (e.g. a reason). Returns null when cancelled.
Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String? hint,
  String confirmText = 'OK',
  int minLength = 3,
  bool danger = false,
}) {
  final c = TextEditingController();
  final form = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: form,
        child: TextFormField(
          controller: c,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(labelText: label, hintText: hint),
          validator: (v) => (v ?? '').trim().length < minLength ? 'Please write at least $minLength letters' : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(88, 44),
            backgroundColor: danger ? AppColors.danger : null,
          ),
          onPressed: () {
            if (form.currentState!.validate()) Navigator.pop(ctx, c.text.trim());
          },
          child: Text(confirmText),
        ),
      ],
    ),
  );
}

/// Shows a new/reset login password once, with copy and WhatsApp buttons.
Future<void> showLoginDetails(
  BuildContext context, {
  required String name,
  required String phone,
  required String libraryCode,
  required String password,
  required String libraryName,
}) {
  final message = 'Namaste $name ji,\n$libraryName app login:\n'
      'Mobile: $phone\nPassword: $password\n(Library code: $libraryCode)\n'
      'Login ke baad password badal lein.';
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Student login'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This password is shown only once. Share it with the student now.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 14),
          Text('Mobile: $phone'),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('Password: '),
              SelectableText(password, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => Clipboard.setData(ClipboardData(text: password)),
              ),
            ],
          ),
          Text('Library code: $libraryCode'),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
          onPressed: () => openWhatsApp(ctx, phone, message),
          icon: const Icon(Icons.send),
          label: const Text('WhatsApp'),
        ),
      ],
    ),
  );
}
