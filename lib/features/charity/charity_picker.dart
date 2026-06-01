import 'package:flutter/material.dart';

import '../../core/problem.dart';
import '../../data/charity_repository.dart';
import '../../generated/zinc/models/charity_principal_res.dart';

/// Read-only charity picker (M1). Loads charities once and filters by name
/// client-side; full server-side search/filters land in M4. Returns the selected
/// [CharityPrincipalRes] via `Navigator.pop`.
class CharityPicker extends StatefulWidget {
  final CharityRepository repository;
  const CharityPicker({super.key, required this.repository});

  @override
  State<CharityPicker> createState() => _CharityPickerState();
}

class _CharityPickerState extends State<CharityPicker> {
  List<CharityPrincipalRes>? _all;
  Problem? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final res = await widget.repository.list(limit: 100);
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        setState(() => _all = value);
      case Err(:final problem):
        setState(() => _error = problem);
    }
  }

  List<CharityPrincipalRes> get _filtered {
    final all = _all ?? const [];
    if (_query.trim().isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((c) => (c.name ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a charity')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search charities',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _ErrorRetry(problem: _error!, onRetry: _load);
    }
    if (_all == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _filtered;
    if (items.isEmpty) {
      return const Center(child: Text('No charities found'));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = items[i];
        final countries = (c.countries ?? const []).join(', ');
        return ListTile(
          leading: _logo(c),
          title: Text(c.name ?? 'Unnamed charity'),
          subtitle: countries.isEmpty ? null : Text(countries),
          onTap: c.id == null ? null : () => Navigator.pop(context, c),
        );
      },
    );
  }

  Widget _logo(CharityPrincipalRes c) {
    final url = c.logoUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.volunteer_activism));
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }
}

class _ErrorRetry extends StatelessWidget {
  final Problem problem;
  final VoidCallback onRetry;
  const _ErrorRetry({required this.problem, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(problem.title, style: Theme.of(context).textTheme.titleMedium),
            if (problem.detail != null) ...[
              const SizedBox(height: 8),
              Text(problem.detail!, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
