import 'package:flutter/material.dart';

import '../core/api.dart';
import 'common.dart';
import 'decor.dart';

class PageResult {
  final List<Map<String, dynamic>> items;
  final int lastPage;
  final Map<String, dynamic> meta;

  PageResult(this.items, this.lastPage, this.meta);

  factory PageResult.from(ApiResponse r) =>
      PageResult(r.list, int.tryParse('${r.meta['last_page'] ?? 1}') ?? 1, r.meta);
}

/// A list that loads more rows as you scroll. Change its key to restart (e.g. new search).
class PagedList extends StatefulWidget {
  final Future<PageResult> Function(int page) fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> item) itemBuilder;
  final Widget empty;
  final Widget Function(Map<String, dynamic> meta)? header;
  final EdgeInsetsGeometry padding;

  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.header,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 96),
  });

  @override
  State<PagedList> createState() => PagedListState();
}

class PagedListState extends State<PagedList> {
  final _items = <Map<String, dynamic>>[];
  final _scroll = ScrollController();
  Map<String, dynamic> _meta = {};
  int _page = 0;
  int _last = 1;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
    // first page after the first frame (setState is not allowed inside initState's build)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _more();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _last = 1;
      _error = null;
    });
    await _more();
  }

  Future<void> _more() async {
    if (_loading || _page >= _last) return;
    setState(() => _loading = true);
    try {
      final r = await widget.fetch(_page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(r.items);
        _page++;
        _last = r.lastPage;
        _meta = r.meta;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && (_loading || (_page == 0 && _error == null))) return const SkeletonView();
    if (_items.isEmpty && _error != null) return ErrorView(message: _error!, onRetry: refresh);

    final head = widget.header?.call(_meta);
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: _items.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return head ?? const SizedBox.shrink();
          if (i == _items.length + 1) {
            if (_items.isEmpty) return widget.empty;
            if (_loading) {
              return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
            }
            if (_error != null) {
              return TextButton(onPressed: _more, child: const Text('Could not load more. Tap to retry.'));
            }
            return const SizedBox(height: 8);
          }
          return widget.itemBuilder(context, _items[i - 1]);
        },
      ),
    );
  }
}
