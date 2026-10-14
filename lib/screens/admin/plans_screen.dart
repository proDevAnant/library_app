import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';

/// Plans you sell to libraries.
class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final _loader = GlobalKey<AsyncLoaderState<List<Map<String, dynamic>>>>();

  Future<void> _edit([Map<String, dynamic>? plan]) async {
    final done = await showFormSheet<bool>(context, title: plan == null ? 'New plan' : 'Edit plan', child: _PlanForm(plan: plan));
    if (done == true) await _loader.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New plan'),
      ),
      body: AsyncLoader<List<Map<String, dynamic>>>(
        key: _loader,
        load: () async => (await Api.instance.get('/admin/plans')).list,
        builder: (context, plans, reload) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            const Text('Changing a price does not change plans already sold.', style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            for (final p in plans)
              Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  onTap: () => _edit(p),
                  title: Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${p['duration_days']} days • '
                      '${p['max_students'] == null ? 'unlimited students' : 'up to ${p['max_students']} students'} • '
                      'used ${p['times_used'] ?? 0} times'),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(money(p['price']), style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    if (p['is_active'] != true)
                      const Pill('Off', color: AppColors.muted)
                    else if (p['is_trial'] == true)
                      const Pill('Trial', color: AppColors.blue),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanForm extends StatefulWidget {
  final Map<String, dynamic>? plan;

  const _PlanForm({this.plan});

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _days, _price, _max;
  late bool _trial, _active;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan ?? {};
    _name = TextEditingController(text: '${p['name'] ?? ''}');
    _days = TextEditingController(text: '${p['duration_days'] ?? 30}');
    _price = TextEditingController(text: p['price'] == null ? '' : toNum(p['price']).toStringAsFixed(0));
    _max = TextEditingController(text: p['max_students'] == null ? '' : '${p['max_students']}');
    _trial = p['is_trial'] == true;
    _active = p['is_active'] != false;
  }

  @override
  void dispose() {
    _name.dispose();
    _days.dispose();
    _price.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      'duration_days': int.parse(_days.text.trim()),
      'price': _price.text.trim(),
      'max_students': _max.text.trim().isEmpty ? null : int.parse(_max.text.trim()),
      'is_trial': _trial,
      'is_active': _active,
    };
    try {
      if (widget.plan == null) {
        await Api.instance.post('/admin/plans', body);
      } else {
        await Api.instance.put('/admin/plans/${widget.plan!['id']}', body);
      }
      if (!mounted) return;
      showSnack(context, 'Plan saved');
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
    return Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Plan name'),
            validator: (v) => V.required(v, 'Name')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextFormField(
              controller: _days,
              keyboardType: TextInputType.number,
              inputFormatters: digits,
              decoration: const InputDecoration(labelText: 'Days'),
              validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'Enter days' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price (₹)'),
              validator: (v) => V.amount(v, allowZero: true),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: _max,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          decoration: const InputDecoration(labelText: 'Max active students (empty = unlimited)'),
        ),
        SwitchListTile(value: _trial, onChanged: (v) => setState(() => _trial = v), title: const Text('Free trial plan')),
        SwitchListTile(value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Available to sell')),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Save plan'),
        ),
      ]),
    );
  }
}
