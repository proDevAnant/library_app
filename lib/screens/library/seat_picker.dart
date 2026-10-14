import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

class SeatChoice {
  final int seatId;
  final String seatNo;
  final int shiftId;
  final String shiftName;

  SeatChoice(this.seatId, this.seatNo, this.shiftId, this.shiftName);

  String get label => '$seatNo • $shiftName';
}

/// Bottom sheet: choose a shift, then a free seat in it.
Future<SeatChoice?> pickSeat(BuildContext context, {int? shiftId}) {
  return showFormSheet<SeatChoice>(context, title: 'Choose seat', child: _SeatPicker(initialShift: shiftId));
}

class _SeatPicker extends StatefulWidget {
  final int? initialShift;

  const _SeatPicker({this.initialShift});

  @override
  State<_SeatPicker> createState() => _SeatPickerState();
}

class _SeatPickerState extends State<_SeatPicker> {
  List<Map<String, dynamic>> _shifts = [];
  List<Map<String, dynamic>> _seats = [];
  int? _shift;
  bool _loading = true;
  String? _error;

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
        _shift = widget.initialShift ?? (list.isNotEmpty ? toInt(list.first['id']) : null);
      });
      await _loadSeats();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSeats() async {
    if (_shift == null) return;
    setState(() => _loading = true);
    try {
      final r = await Api.instance.get('/library/seats', query: {'shift_id': _shift, 'status': 'available'});
      if (mounted) setState(() => _seats = r.list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Text(_error!, style: const TextStyle(color: AppColors.danger));
    if (_shifts.isEmpty && !_loading) {
      return const Text('No active shifts. Add a shift first.', style: TextStyle(color: AppColors.muted));
    }
    final shiftName = _shifts.firstWhere((s) => toInt(s['id']) == _shift, orElse: () => {})['name'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Shift', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final s in _shifts)
              ChoiceChip(
                label: Text('${s['name']} (${s['start_time']}–${s['end_time']})'),
                selected: toInt(s['id']) == _shift,
                onSelected: (_) {
                  setState(() => _shift = toInt(s['id']));
                  _loadSeats();
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Free seats${shiftName != null ? ' in $shiftName' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
        else if (_seats.isEmpty)
          const Text('No free seats in this shift.', style: TextStyle(color: AppColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seat in _seats)
                ActionChip(
                  avatar: const Icon(Icons.event_seat, size: 18, color: AppColors.green),
                  label: Text('${seat['seat_no']}'),
                  onPressed: () => Navigator.pop(
                    context,
                    SeatChoice(toInt(seat['id']), '${seat['seat_no']}', _shift!, '${shiftName ?? ''}'),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Small helper used on the profile to show any API error.
void showApiError(BuildContext context, Object e) {
  showSnack(context, e is ApiException ? e.message : 'Something went wrong', error: true);
}
