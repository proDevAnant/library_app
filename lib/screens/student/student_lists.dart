import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import 'student_home_screen.dart';

class StudentPaymentsScreen extends StatelessWidget {
  const StudentPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My payments')),
      body: PagedList(
        fetch: (page) async => PageResult.from(await Api.instance.get('/student/payments', query: {'page': page})),
        empty: const EmptyView(icon: Icons.receipt_long_outlined, title: 'No payments yet'),
        itemBuilder: (context, p) => Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: StudentPaymentTile(p: p),
        ),
      ),
    );
  }
}

class StudentNoticesScreen extends StatelessWidget {
  const StudentNoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notices')),
      body: PagedList(
        fetch: (page) async => PageResult.from(await Api.instance.get('/student/notices', query: {'page': page})),
        empty: const EmptyView(icon: Icons.campaign_outlined, title: 'No notices yet'),
        itemBuilder: (context, n) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${n['title']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 6),
              Text('${n['body']}'),
              const SizedBox(height: 6),
              Text(niceDateTime(n['created_at']), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}
