import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../widgets/bits.dart';
import '../../widgets/common.dart';
import '../../widgets/paged_list.dart';
import 'student_form_screen.dart';
import 'student_profile_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  static const _filters = {
    'active': 'Active',
    'due': 'Fees due',
    'noseat': 'No seat',
    'inactive': 'Inactive',
    'all': 'All',
  };

  final _search = TextEditingController();
  String _query = '';
  String _filter = 'active';
  Timer? _debounce;
  int _version = 0; // bump to reload the list

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _params => {
        'search': _query,
        if (_filter == 'active' || _filter == 'due' || _filter == 'noseat') 'status': 'active',
        if (_filter == 'inactive') 'status': 'inactive',
        if (_filter == 'due') 'fee': 'due',
        if (_filter == 'noseat') 'seat': 'no',
      };

  Future<PageResult> _fetch(int page) async {
    final r = await Api.instance.get('/library/students', query: {..._params, 'page': page});
    return PageResult.from(r);
  }

  void _reload() => setState(() => _version++);

  Future<void> _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => StudentProfileScreen(studentId: id)));
    _reload();
  }

  Future<void> _add() async {
    final id = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => const StudentFormScreen()));
    if (id != null) {
      _reload();
      await _open(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Students'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(108),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search name, mobile or ID',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
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
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _filters.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.value),
                            selected: _filter == f.key,
                            onSelected: (_) => setState(() => _filter = f.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add student'),
      ),
      body: PagedList(
        key: ValueKey('$_query|$_filter|$_version'),
        fetch: _fetch,
        header: (meta) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text('${meta['total'] ?? 0} student(s)', style: const TextStyle(color: AppColors.muted)),
        ),
        empty: const EmptyView(
          icon: Icons.people_outline,
          title: 'No students found',
          subtitle: 'Change the filter or add a new student.',
        ),
        itemBuilder: (context, s) {
          final inactive = s['status'] == 'inactive';
          final seats = (s['seats'] ?? '').toString();
          return Card(
            elevation: 0,
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              onTap: () => _open(toInt(s['id'])),
              leading: Avatar(url: s['photo_url']?.toString(), name: '${s['name']}'),
              title: Text('${s['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${s['student_code']} • ${seats.isEmpty ? 'No seat' : seats}'
                '${s['membership_end'] != null ? '\nTill ${niceDate(s['membership_end'])}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: s['membership_end'] != null,
              trailing: inactive ? const Pill('Inactive', color: AppColors.muted) : DueText(s['balance_due']),
            ),
          );
        },
      ),
    );
  }
}
