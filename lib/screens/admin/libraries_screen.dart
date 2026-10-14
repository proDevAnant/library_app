import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import 'library_detail_screen.dart';
import 'library_form_screen.dart';

class LibrariesScreen extends StatefulWidget {
  const LibrariesScreen({super.key});

  @override
  State<LibrariesScreen> createState() => _LibrariesScreenState();
}

class _LibrariesScreenState extends State<LibrariesScreen> {
  static const _filters = {
    'all': 'All',
    'trial': 'Trial',
    'active': 'Active',
    'expiring': 'Plan ending',
    'expired': 'Plan expired',
    'suspended': 'Suspended',
  };

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _filter = 'all';
  int _v = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _params => {
        'search': _query,
        if (['trial', 'active', 'suspended'].contains(_filter)) 'status': _filter,
        if (_filter == 'expiring' || _filter == 'expired') 'plan': _filter,
      };

  Future<void> _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => LibraryDetailScreen(libraryId: id)));
    if (mounted) setState(() => _v++);
  }

  Future<void> _add() async {
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const LibraryFormScreen()));
    if (id != null && mounted) {
      setState(() => _v++);
      await _open(id);
    }
  }

  Pill _statusPill(Map<String, dynamic> l) {
    if (l['status'] == 'suspended') return const Pill('Suspended', color: AppColors.danger);
    if (l['status'] == 'deactivated') return const Pill('Deactivated', color: AppColors.muted);
    if (l['plan_expired'] == true) return const Pill('Plan expired', color: AppColors.danger);
    final left = l['plan_days_left'];
    if (left != null && toInt(left) <= 7) return Pill('${toInt(left)}d left', color: AppColors.warn);
    return l['status'] == 'trial' ? const Pill('Trial', color: AppColors.blue) : const Pill('Active');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Libraries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(children: [
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                    hintText: 'Search name, code, city, owner', prefixIcon: Icon(Icons.search), isDense: true),
                onChanged: (v) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), () {
                    if (mounted) setState(() => _query = v.trim());
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final f in _filters.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.value),
                        selected: _filter == f.key,
                        onSelected: (_) => setState(() => _filter = f.key),
                      ),
                    ),
                ]),
              ),
            ]),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_business),
        label: const Text('New library'),
      ),
      body: PagedList(
        key: ValueKey('$_query|$_filter|$_v'),
        fetch: (page) async =>
            PageResult.from(await Api.instance.get('/admin/libraries', query: {..._params, 'page': page})),
        header: (meta) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('${meta['total'] ?? 0} library(s)', style: const TextStyle(color: AppColors.muted)),
        ),
        empty: const EmptyView(icon: Icons.store_outlined, title: 'No libraries found'),
        itemBuilder: (context, l) => Card(
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            onTap: () => _open(toInt(l['id'])),
            leading: Avatar(url: l['logo_url']?.toString(), name: '${l['name']}'),
            title: Text('${l['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${l['code']} • ${l['city'] ?? ''}\n'
                '${l['active_students'] ?? 0} students • plan till ${l['plan_end'] == null ? '-' : niceDate(l['plan_end'])}'),
            isThreeLine: true,
            trailing: _statusPill(l),
          ),
        ),
      ),
    );
  }
}
