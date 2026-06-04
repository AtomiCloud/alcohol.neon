import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/problem.dart';
import '../../data/cause_repository.dart';
import '../../data/charity_repository.dart';
import '../../generated/zinc/models/cause_principal_res.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import 'charity_detail_view.dart';

/// Server-side charity search (M4), mirroring argon's `charities.tsx`: a debounced
/// name field plus Country and Cause filter dropdowns, all driving
/// `CharityRepository.list(..., limit: 50, skip: 0)`. Supported countries and the
/// cause hierarchy load once on open, in parallel with the first search.
///
/// Two modes:
///  - **selection** (the M1 picker behaviour): tapping a result returns the
///    [CharityPrincipalRes] via `Navigator.pop`. Used by onboarding + the habit
///    editor.
///  - **browse**: tapping a result opens [CharityDetailView] instead.
class CharityBrowse extends StatefulWidget {
  final CharityRepository repository;

  /// Optional — when supplied, the Cause filter dropdown is populated from
  /// `GET /Causes`. Absent (null) simply omits the cause filter.
  final CauseRepository? causeRepository;

  /// When true, tapping a result returns it via `Navigator.pop`. When false,
  /// tapping opens the charity detail screen.
  final bool selectionMode;

  const CharityBrowse({
    super.key,
    required this.repository,
    this.causeRepository,
    this.selectionMode = true,
  });

  @override
  State<CharityBrowse> createState() => _CharityBrowseState();
}

/// Backwards-compatible alias for the M1 selection picker. Existing call sites
/// (onboarding, habit editor) push `CharityPicker(repository: ...)` and expect a
/// [CharityPrincipalRes] back via `Navigator.pop` — that contract is preserved.
class CharityPicker extends CharityBrowse {
  const CharityPicker({
    super.key,
    required super.repository,
    super.causeRepository,
  }) : super(selectionMode: true);
}

class _CharityBrowseState extends State<CharityBrowse> {
  // Filter options, loaded once on open.
  List<String> _countries = const [];
  List<CausePrincipalRes> _causes = const [];

  // Current filter selections. Empty string == "Any".
  String _name = '';
  String _country = '';
  String _causeKey = '';

  // Search results / status.
  List<CharityPrincipalRes>? _results;
  Problem? _error;

  Timer? _debounce;

  // Guards against out-of-order responses: each _search() bumps this and discards
  // its result if a newer search (name debounce or a dropdown change) started since.
  int _searchGen = 0;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Loads the Country + Cause filter options once. Failures are non-fatal: the
  /// search still works, the affected dropdown just shows only "Any".
  Future<void> _loadFilterOptions() async {
    final countriesF = widget.repository.supportedCountries();
    // zinc caps Limit at 100 (Limit=200 → 400), so request the max allowed.
    final causesF = widget.causeRepository?.list(limit: 100);

    final countriesRes = await countriesF;
    if (mounted && countriesRes is Ok<List<String>>) {
      setState(() => _countries = countriesRes.value);
    }

    if (causesF != null) {
      final causesRes = await causesF;
      if (mounted && causesRes is Ok<List<CausePrincipalRes>>) {
        // Sort by full hierarchical name so parents group above their children.
        final sorted = [...causesRes.value]
          ..sort((a, b) =>
              (a.name ?? a.key ?? '').compareTo(b.name ?? b.key ?? ''));
        setState(() => _causes = sorted);
      }
    }
  }

  /// Debounced (300ms) name search. Filter-dropdown changes call [_search]
  /// directly (no debounce needed for discrete selections).
  void _onNameChanged(String value) {
    _name = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final gen = ++_searchGen;
    setState(() {
      _error = null;
      _results = null;
    });
    final res = await widget.repository.list(
      name: _name.trim().isEmpty ? null : _name.trim(),
      country: _country.isEmpty ? null : _country,
      causeKey: _causeKey.isEmpty ? null : _causeKey,
      limit: 50,
      skip: 0,
    );
    // Discard a stale response if a newer search has started meanwhile.
    if (!mounted || gen != _searchGen) return;
    switch (res) {
      case Ok(:final value):
        setState(() => _results = value);
      case Err(:final problem):
        setState(() => _error = problem);
    }
  }

  Future<void> _onTap(CharityPrincipalRes c) async {
    if (widget.selectionMode) {
      Navigator.pop(context, c);
      return;
    }
    final id = c.id;
    if (id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CharityDetailView(repository: widget.repository, charityId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Choose a charity' : 'Charities'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search charities by name',
                border: OutlineInputBorder(),
              ),
              onChanged: _onNameChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(child: _countryDropdown()),
                if (widget.causeRepository != null) ...[
                  const SizedBox(width: 8),
                  Expanded(child: _causeDropdown()),
                ],
              ],
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _countryDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _country,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Country',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any')),
        for (final code in _countries)
          DropdownMenuItem(value: code, child: Text(code)),
      ],
      onChanged: (v) {
        setState(() => _country = v ?? '');
        _search();
      },
    );
  }

  Widget _causeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _causeKey,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Cause',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem(value: '', child: Text('Any')),
        for (final cause in _causes)
          if ((cause.key ?? '').isNotEmpty)
            DropdownMenuItem(
              value: cause.key,
              // Causes are a flat list; hierarchy is encoded in the name as
              // ' > '-joined segments. Indent by depth, show only the leaf.
              child: _CauseLabel(name: cause.name ?? cause.key ?? ''),
            ),
      ],
      onChanged: (v) {
        setState(() => _causeKey = v ?? '');
        _search();
      },
    );
  }

  Widget _body() {
    if (_error != null) {
      return _ErrorRetry(problem: _error!, onRetry: _search);
    }
    if (_results == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = _results!;
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
          trailing: widget.selectionMode
              ? null
              : const Icon(Icons.chevron_right),
          onTap: c.id == null ? null : () => _onTap(c),
        );
      },
    );
  }

  Widget _logo(CharityPrincipalRes c) {
    final url = c.logoUrl;
    if (url == null || url.isEmpty) {
      return const CircleAvatar(child: Icon(Icons.volunteer_activism));
    }
    // Some logoUrls return non-image content (HTML/404) → "Invalid image data".
    // errorBuilder catches the decode failure and falls back to the placeholder.
    return CircleAvatar(
      backgroundColor: Colors.transparent,
      child: ClipOval(
        child: Image.network(
          url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.volunteer_activism),
        ),
      ),
    );
  }
}

/// One indented cause option: splits the ' > '-joined hierarchical name, indents
/// by depth (segments - 1) and renders only the leaf segment.
class _CauseLabel extends StatelessWidget {
  final String name;
  const _CauseLabel({required this.name});

  @override
  Widget build(BuildContext context) {
    final segments =
        name.split(' > ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final depth = segments.isEmpty ? 0 : segments.length - 1;
    final leaf = segments.isEmpty ? name : segments.last;
    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0),
      child: Text(leaf, overflow: TextOverflow.ellipsis),
    );
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
