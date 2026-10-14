import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/common.dart';

/// Opens a link outside the app (browser, WhatsApp, phone dialer).
Future<void> openLink(BuildContext context, String url) async {
  final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) showSnack(context, 'Could not open the link', error: true);
}

/// WhatsApp chat with a ready message. Nothing is sent until the user taps send.
Future<void> openWhatsApp(BuildContext context, String phone, String message) {
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.length == 10) d = '91$d';
  return openLink(context, 'https://wa.me/$d?text=${Uri.encodeComponent(message)}');
}

Future<void> callPhone(BuildContext context, String phone) => openLink(context, 'tel:$phone');

/// Unique key per "Save payment" form, so a double tap never saves twice.
String newIdempotencyKey() {
  final r = Random.secure();
  return List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
}

/// yyyy-mm-dd for the API.
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<DateTime?> pickDate(BuildContext context, {DateTime? initial, DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(now.year - 30),
    lastDate: last ?? DateTime(now.year + 3),
  );
}
