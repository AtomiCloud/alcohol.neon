import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/problem.dart';
import '../../data/cause_repository.dart';
import '../../data/charity_repository.dart';
import '../../generated/zinc/models/cause_principal_res.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';
import 'charity_detail_view.dart';

/// Server-side charity search (M4), mirroring argon's `charities.tsx`: a
/// debounced name search plus Country and Cause filters, all driving
/// `CharityRepository.list(..., limit: 50, skip: 0)`. Supported countries and
/// the cause hierarchy load once on open, in parallel with the first search.
///
/// Two modes:
///  - **selection**: tapping a result returns the [CharityPrincipalRes] via
///    `Navigator.pop`, and its info button opens the detail with "Choose this
///    charity". Used by the habit editor and Settings.
///  - **browse**: tapping a result opens [CharityDetailView].
class CharityBrowse extends StatefulWidget {
  final CharityRepository repository;

  /// Optional: when supplied, the Cause filter is populated from
  /// `GET /Causes`. Absent (null) omits the cause filter.
  final CauseRepository? causeRepository;

  /// When true, tapping a result returns it via `Navigator.pop`. When false,
  /// tapping opens the charity detail screen.
  final bool selectionMode;

  /// The charity already chosen, marked "Selected" in the results.
  final String? selectedId;

  const CharityBrowse({
    super.key,
    required this.repository,
    this.causeRepository,
    this.selectionMode = true,
    this.selectedId,
  });

  @override
  State<CharityBrowse> createState() => _CharityBrowseState();
}

/// The selection picker. Call sites (habit editor, Settings) push
/// `CharityPicker(repository: ...)` and get a [CharityPrincipalRes] back via
/// `Navigator.pop`.
class CharityPicker extends CharityBrowse {
  const CharityPicker({
    super.key,
    required super.repository,
    super.causeRepository,
    super.selectedId,
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

  // Guards against out-of-order responses: each _search() bumps this and
  // discards its result if a newer search started since.
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

  /// Loads the Country + Cause filter options once. Failures are non-fatal:
  /// the search still works, the affected filter just offers only "Any".
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
        // Sort by full hierarchical name so parents group above children.
        final sorted = [...causesRes.value]
          ..sort(
            (a, b) => (a.name ?? a.key ?? '').compareTo(b.name ?? b.key ?? ''),
          );
        setState(() => _causes = sorted);
      }
    }
  }

  /// Debounced (300ms) name search. Filter changes call [_search] directly.
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
    await _openDetail(c);
  }

  /// Opens the detail. While picking, the detail offers "Choose this
  /// charity", which picks it here too.
  Future<void> _openDetail(CharityPrincipalRes c) async {
    final id = c.id;
    if (id == null) return;
    final chosen = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CharityDetailView(
          repository: widget.repository,
          charityId: id,
          choosable: widget.selectionMode,
        ),
      ),
    );
    if (chosen == true && mounted) Navigator.pop(context, c);
  }

  /// A filter sheet: "Any" plus each option, the current one checked.
  Future<void> _pickFilter({
    required String title,
    required String current,
    required List<(String, String, String?)> options,
    required ValueChanged<String> onPicked,
  }) async {
    final picked = await showGlassSheet<String>(
      context,
      (ctx) => _FilterSheet(title: title, current: current, options: options),
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => onPicked(picked));
    _search();
  }

  String get _causeLabel {
    if (_causeKey.isEmpty) return 'Any';
    final cause = _causes.where((c) => c.key == _causeKey).firstOrNull;
    return _leaf(cause?.name ?? _causeKey);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: widget.selectionMode ? 'Choose a charity' : 'Charities',
      children: [
        const SizedBox(height: 4),
        GlassSearchField(hint: 'Search by name', onChanged: _onNameChanged),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GlassPill(
              label: 'Country: ${_country.isEmpty ? 'Any' : _country}',
              icon: Icons.expand_more_rounded,
              on: _country.isNotEmpty,
              onTap: () => _pickFilter(
                title: 'Country',
                current: _country,
                options: [for (final code in _countries) (code, code, null)],
                onPicked: (v) => _country = v,
              ),
            ),
            if (widget.causeRepository != null)
              GlassPill(
                label: 'Cause: $_causeLabel',
                icon: Icons.expand_more_rounded,
                on: _causeKey.isNotEmpty,
                onTap: () => _pickFilter(
                  title: 'Cause',
                  current: _causeKey,
                  options: [
                    for (final cause in _causes)
                      if ((cause.key ?? '').isNotEmpty)
                        (
                          cause.key!,
                          _leaf(cause.name ?? cause.key!),
                          _parents(cause.name ?? ''),
                        ),
                  ],
                  onPicked: (v) => _causeKey = v,
                ),
              ),
          ],
        ),
        ..._body(),
      ],
    );
  }

  List<Widget> _body() {
    final t = GlassTokens.of(context);
    if (_error case final error?) {
      return [
        const SizedBox(height: 8),
        GlassBanner(
          icon: Icons.cloud_off_rounded,
          title: error.title,
          body: error.detail,
          error: true,
          action: GlassTextButton(label: 'Retry', onPressed: _search),
        ),
      ];
    }
    final items = _results;
    if (items == null) {
      return const [SizedBox(height: 240, child: AppLoader())];
    }
    if (items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Text(
            'No charities found',
            textAlign: TextAlign.center,
            style: TextStyle(color: t.muted),
          ),
        ),
      ];
    }
    return [
      GlassSection(
        title: 'Results',
        dividerIndent: 64,
        children: [
          for (final c in items)
            GlassRow(
              key: ValueKey(c.id),
              leading: CharityLogo(url: c.logoUrl, size: 34),
              title: c.name ?? 'Unnamed charity',
              subtitle: _subtitle(c),
              chevron: !widget.selectionMode,
              trailing: widget.selectionMode && c.id != null
                  ? IconButton(
                      tooltip: 'About ${c.name ?? 'this charity'}',
                      icon: Icon(Icons.info_outline_rounded, color: t.muted),
                      onPressed: () => _openDetail(c),
                    )
                  : null,
              onTap: c.id == null ? null : () => _onTap(c),
            ),
        ],
      ),
    ];
  }

  String? _subtitle(CharityPrincipalRes c) {
    final countries = (c.countries ?? const []).join(', ');
    final selected = c.id != null && c.id == widget.selectedId;
    if (selected) {
      return countries.isEmpty ? 'Selected' : 'Selected · $countries';
    }
    return countries.isEmpty ? null : countries;
  }
}

/// Causes are a flat list whose names encode the hierarchy as ' > '-joined
/// segments. [_leaf] is the last segment, [_parents] the ones before it.
List<String> _segments(String name) =>
    name.split(' > ').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

String _leaf(String name) {
  final s = _segments(name);
  return s.isEmpty ? name : s.last;
}

String? _parents(String name) {
  final s = _segments(name);
  return s.length < 2 ? null : s.sublist(0, s.length - 1).join(' › ');
}

/// A filter's options in a glass sheet. Options are (value, label, subtitle);
/// "Any" is the empty value.
class _FilterSheet extends StatelessWidget {
  final String title;
  final String current;
  final List<(String, String, String?)> options;
  const _FilterSheet({
    required this.title,
    required this.current,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final all = [('', 'Any', null), ...options];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Glass(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: all.length,
                  separatorBuilder: (_, _) => Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Divider(height: 0.5, color: t.separator),
                  ),
                  itemBuilder: (ctx, i) {
                    final (value, label, sub) = all[i];
                    return GlassRow(
                      title: label,
                      subtitle: sub,
                      chevron: false,
                      trailing: value == current
                          ? Icon(Icons.check_rounded, color: t.accent)
                          : null,
                      onTap: () => Navigator.pop(ctx, value),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
