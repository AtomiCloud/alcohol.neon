import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/problem.dart';
import '../../data/charity_repository.dart';
import '../../generated/zinc/models/charity_principal_res.dart';

/// Read-only charity detail (M4), reached by tapping a result in browse mode.
/// Loads `GET /Charity/{id}` → `CharityRes.principal` and shows the mission,
/// countries, registration info and — only when the scheme is http/https — a
/// tappable website link (mirroring argon's website-scheme guard).
class CharityDetailView extends StatefulWidget {
  final CharityRepository repository;
  final String charityId;

  const CharityDetailView({
    super.key,
    required this.repository,
    required this.charityId,
  });

  @override
  State<CharityDetailView> createState() => _CharityDetailViewState();
}

class _CharityDetailViewState extends State<CharityDetailView> {
  CharityPrincipalRes? _charity;
  Problem? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _charity = null;
    });
    final res = await widget.repository.byId(widget.charityId);
    if (!mounted) return;
    switch (res) {
      case Ok(:final value):
        setState(() => _charity = value.principal);
      case Err(:final problem):
        setState(() => _error = problem);
    }
  }

  /// Parses [raw] and returns it only if it's an http/https URL — otherwise null
  /// (guards against `javascript:` and other unsafe schemes, like argon).
  Uri? _safeWebsite(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  Future<void> _openWebsite(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open website')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_charity?.name ?? 'Charity')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _ErrorRetry(problem: _error!, onRetry: _load);
    }
    final c = _charity;
    if (c == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final countries = (c.countries ?? const []).join(', ');
    final website = _safeWebsite(c.websiteUrl);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(c.name ?? 'Unnamed charity', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        if ((c.mission ?? '').isNotEmpty) ...[
          Text(c.mission!, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],
        if (countries.isNotEmpty)
          _DetailRow(icon: Icons.public, label: 'Countries', value: countries),
        if ((c.primaryRegistrationNumber ?? '').isNotEmpty)
          _DetailRow(
            icon: Icons.badge_outlined,
            label: 'Registration number',
            value: c.primaryRegistrationNumber!,
          ),
        if ((c.primaryRegistrationCountry ?? '').isNotEmpty)
          _DetailRow(
            icon: Icons.flag_outlined,
            label: 'Registration country',
            value: c.primaryRegistrationCountry!,
          ),
        if (website != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Visit website'),
            onPressed: () => _openWebsite(website),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
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
