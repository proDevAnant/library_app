import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';

/// Support requests from libraries, newest open first.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  int _v = 0;

  Future<void> _reply(Map<String, dynamic> s) async {
    final done = await showFormSheet<bool>(context, title: '${s['subject']}', child: _ReplyForm(request: s));
    if (done == true && mounted) setState(() => _v++);
  }

  Pill _pill(String status) => switch (status) {
        'open' => const Pill('Open', color: AppColors.danger),
        'in_progress' => const Pill('In progress', color: AppColors.blue),
        'resolved' => const Pill('Resolved'),
        _ => const Pill('Closed', color: AppColors.muted),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support requests')),
      body: PagedList(
        key: ValueKey(_v),
        fetch: (page) async => PageResult.from(await Api.instance.get('/admin/support', query: {'page': page})),
        empty: const EmptyView(icon: Icons.support_agent, title: 'No support requests'),
        itemBuilder: (context, s) => Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => _reply(s),
            title: Text('${s['subject']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${s['library_name']} • ${niceDateTime(s['created_at'])}\n${s['message']}',
                maxLines: 3, overflow: TextOverflow.ellipsis),
            isThreeLine: true,
            trailing: _pill('${s['status']}'),
          ),
        ),
      ),
    );
  }
}

class _ReplyForm extends StatefulWidget {
  final Map<String, dynamic> request;

  const _ReplyForm({required this.request});

  @override
  State<_ReplyForm> createState() => _ReplyFormState();
}

class _ReplyFormState extends State<_ReplyForm> {
  late final TextEditingController _reply;
  late String _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reply = TextEditingController(text: '${widget.request['reply'] ?? ''}');
    _status = widget.request['status'] == 'open' ? 'resolved' : '${widget.request['status']}';
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await Api.instance.post('/admin/support/${widget.request['id']}/reply', {
        if (_reply.text.trim().isNotEmpty) 'reply': _reply.text.trim(),
        'status': _status,
      });
      if (!mounted) return;
      showSnack(context, 'Sent to the library');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${r['library_name']} (${r['library_code']})', style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 8),
      Panel(child: Text('${r['message']}')),
      const SizedBox(height: 12),
      TextField(controller: _reply, maxLines: 4, decoration: const InputDecoration(labelText: 'Your reply')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _status,
        decoration: const InputDecoration(labelText: 'Status'),
        items: const [
          DropdownMenuItem(value: 'open', child: Text('Open')),
          DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
          DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
          DropdownMenuItem(value: 'closed', child: Text('Closed')),
        ],
        onChanged: (v) => setState(() => _status = v ?? 'resolved'),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: _busy
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
            : const Text('Send'),
      ),
    ]);
  }
}
