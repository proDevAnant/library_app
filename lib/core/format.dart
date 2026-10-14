import 'package:intl/intl.dart';

final NumberFormat _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final NumberFormat _rupee2 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// ₹1,25,000  (paise shown only when there are any)
String money(dynamic v) {
  final n = num.tryParse('${v ?? 0}') ?? 0;
  return n == n.roundToDouble() ? _rupee.format(n) : _rupee2.format(n);
}

/// 2026-10-14 → 14 Oct 2026
String niceDate(dynamic v) {
  if (v == null || '$v'.isEmpty) return '-';
  final d = DateTime.tryParse('$v');
  return d == null ? '$v' : DateFormat('dd MMM yyyy').format(d);
}

/// 2026-10-14 21:10:00 → 14 Oct, 9:10 PM
String niceDateTime(dynamic v) {
  if (v == null || '$v'.isEmpty) return '-';
  final d = DateTime.tryParse('$v'.replaceFirst(' ', 'T'));
  return d == null ? '$v' : DateFormat('dd MMM, h:mm a').format(d);
}

int toInt(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

num toNum(dynamic v) => num.tryParse('${v ?? 0}') ?? 0;
