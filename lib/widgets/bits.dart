import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';

/// Round photo, or the first letter when there's no photo.
class Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final double radius;

  const Avatar({super.key, required this.url, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final letter = Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w700, fontSize: radius * 0.8));
    if (url == null || url!.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: AppColors.greenSoft, child: letter);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.greenSoft,
      child: ClipOval(
        child: Image.network(
          url!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => letter,
        ),
      ),
    );
  }
}

/// Small coloured label: "Paid", "Pending", "Overdue" ...
class Pill extends StatelessWidget {
  final String text;
  final Color color;

  const Pill(this.text, {super.key, this.color = AppColors.green});

  factory Pill.feeStatus(String status) {
    switch (status) {
      case 'paid':
        return const Pill('Paid');
      case 'partial':
        return const Pill('Partly paid', color: AppColors.blue);
      case 'overdue':
        return const Pill('Overdue', color: AppColors.danger);
      case 'cancelled':
        return const Pill('Cancelled', color: AppColors.muted);
      default:
        return const Pill('Pending', color: AppColors.warn);
    }
  }

  factory Pill.paymentStatus(String status) {
    switch (status) {
      case 'verified':
        return const Pill('Verified');
      case 'pending_verification':
        return const Pill('To verify', color: AppColors.blue);
      case 'rejected':
        return const Pill('Rejected', color: AppColors.danger);
      default:
        return const Pill('Void', color: AppColors.muted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// "Label ........ value" row.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const InfoRow(this.label, this.value, {super.key, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                textAlign: TextAlign.right,
                style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

String planLabel(String p) => switch (p) {
      'monthly' => 'Monthly',
      'quarterly' => 'Quarterly (3 months)',
      'half_yearly' => 'Half-yearly (6 months)',
      'yearly' => 'Yearly',
      _ => p,
    };

String methodLabel(String m) => switch (m) {
      'cash' => 'Cash',
      'upi' => 'UPI',
      'bank_transfer' => 'Bank transfer',
      _ => m,
    };

int planMonths(String p) => switch (p) {
      'quarterly' => 3,
      'half_yearly' => 6,
      'yearly' => 12,
      _ => 1,
    };

/// Bottom-sheet scaffold with a title, used by the small forms.
Future<T?> showFormSheet<T>(BuildContext context, {required String title, required Widget child}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Money text that turns red when something is owed.
class DueText extends StatelessWidget {
  final dynamic amount;

  const DueText(this.amount, {super.key});

  @override
  Widget build(BuildContext context) {
    final n = toNum(amount);
    return Text(n > 0 ? '${money(n)} due' : 'No dues',
        style: TextStyle(color: n > 0 ? AppColors.danger : AppColors.green, fontWeight: FontWeight.w600, fontSize: 13));
  }
}
