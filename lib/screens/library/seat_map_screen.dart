import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import 'student_profile_screen.dart';

/// Seat map for one shift: green = free, dark = taken, orange = reserved.
class SeatMapScreen extends StatefulWidget {
  const SeatMapScreen({super.key});

  @override
  State<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends State<SeatMapScreen> {
  List<Map<String, dynamic>> _shifts = [];
  int? _shift;
  String? _error;
  bool _loaded = false;
  int _v = 0;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    try {
      final r = await Api.instance.get('/library/shifts');
      final list = r.list.where((s) => s['is_active'] == true).toList();
      if (!mounted) return;
      setState(() {
        _shifts = list;
        _shift = list.isNotEmpty ? toInt(list.first['id']) : null;
        _error = null;
        _loaded = true;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _addSeats() async {
    final added = await showFormSheet<bool>(context, title: 'Add seats', child: const _BulkSeatsForm());
    if (added == true && mounted) setState(() => _v++);
  }

  void _tapSeat(Map<String, dynamic> seat) {
    final people = (seat['occupants'] as List? ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    showFormSheet<void>(
      context,
      title: 'Seat ${seat['seat_no']}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (seat['status'] == 'reserved') const Text('This seat is reserved.'),
          if (seat['status'] == 'available')
            const Text('Free in this shift. To give it, open a student and tap Seat → Add.',
                style: TextStyle(color: AppColors.muted)),
          for (final p in people)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person, color: AppColors.green),
              title: Text('${p['student_name']}'),
              subtitle: Text('${p['student_code']} • ${p['shift_name']}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StudentProfileScreen(studentId: toInt(p['student_id']))));
              },
            ),
        ],
      ),
    );
  }

  Color _color(String status) => switch (status) {
        'occupied' => AppColors.ink,
        'reserved' => AppColors.warn,
        'inactive' => AppColors.line,
        _ => AppColors.green,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seat map'),
        actions: [IconButton(tooltip: 'Add seats', onPressed: _addSeats, icon: const Icon(Icons.add))],
      ),
      body: _error != null
          ? ErrorView(message: _error!, onRetry: _loadShifts)
          : _shift == null
              ? (_loaded
                  ? const Center(child: EmptyView(icon: Icons.schedule, title: 'No active shifts'))
                  : const LoadingView())
              : Column(
                  children: [
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        children: [
                          for (final s in _shifts)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('${s['name']}'),
                                selected: toInt(s['id']) == _shift,
                                onSelected: (_) => setState(() => _shift = toInt(s['id'])),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: AsyncLoader<ApiResponse>(
                        key: ValueKey('$_shift|$_v'),
                        load: () => Api.instance.get('/library/seats', query: {'shift_id': _shift}),
                        builder: (context, r, reload) {
                          final seats = r.list;
                          final c = (r.meta['counts'] as Map? ?? {}).cast<String, dynamic>();
                          if (seats.isEmpty) {
                            return ListView(children: [
                              const EmptyView(icon: Icons.event_seat_outlined, title: 'No seats yet'),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 60),
                                child: FilledButton(onPressed: _addSeats, child: const Text('Add seats')),
                              ),
                            ]);
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            children: [
                              Wrap(spacing: 12, runSpacing: 4, children: [
                                _legend(AppColors.green, 'Free ${c['available'] ?? 0}'),
                                _legend(AppColors.ink, 'Taken ${c['occupied'] ?? 0}'),
                                _legend(AppColors.warn, 'Reserved ${c['reserved'] ?? 0}'),
                              ]),
                              const SizedBox(height: 12),
                              GridView.count(
                                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 10 : 5,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  for (final s in seats)
                                    Material(
                                      color: _color('${s['status']}').withAlpha(s['status'] == 'occupied' ? 230 : 40),
                                      borderRadius: BorderRadius.circular(10),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () => _tapSeat(s),
                                        child: Center(
                                          child: Text(
                                            '${s['seat_no']}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: s['status'] == 'occupied' ? Colors.white : _color('${s['status']}'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 13)),
      ]);
}

class _BulkSeatsForm extends StatefulWidget {
  const _BulkSeatsForm();

  @override
  State<_BulkSeatsForm> createState() => _BulkSeatsFormState();
}

class _BulkSeatsFormState extends State<_BulkSeatsForm> {
  final _prefix = TextEditingController(text: 'A');
  final _from = TextEditingController(text: '1');
  final _to = TextEditingController(text: '20');
  bool _busy = false;

  @override
  void dispose() {
    _prefix.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final r = await Api.instance.post('/library/seats/bulk', {
        'prefix': _prefix.text.trim(),
        'from': int.tryParse(_from.text.trim()) ?? 0,
        'to': int.tryParse(_to.text.trim()) ?? 0,
      });
      if (!mounted) return;
      showSnack(context, r.message);
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Seats will be named like A1, A2, A3 … Seats that already exist are skipped.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'Letter / prefix (optional)')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
                controller: _from, keyboardType: TextInputType.number, inputFormatters: digits,
                decoration: const InputDecoration(labelText: 'From number')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _to, keyboardType: TextInputType.number, inputFormatters: digits,
                decoration: const InputDecoration(labelText: 'To number')),
          ),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Add seats'),
        ),
      ],
    );
  }
}
