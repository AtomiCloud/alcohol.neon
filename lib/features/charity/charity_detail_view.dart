import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/problem.dart';
import '../../data/charity_repository.dart';
import '../../generated/zinc/models/charity_principal_res.dart';
import '../../theme/glass.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';

/// Charity detail (M4): the mission, countries, registration and, only when
/// the scheme is http/https, a website link (argon's website-scheme guard).
/// Loads `GET /Charity/{id}` → `CharityRes.principal`.
///
/// With [choosable] (opened from the picker), a "Choose this charity" button
/// sits at the bottom and pops `true`.
class CharityDetailView extends StatefulWidget {
  final CharityRepository repository;
  final String charityId;
  final bool choosable;

  const CharityDetailView({
    super.key,
    required this.repository,
    required this.charityId,
    this.choosable = false,
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

  /// Parses [raw] and returns it only if it's an http/https URL, otherwise
  /// null (guards against `javascript:` and other unsafe schemes, like argon).
  Uri? _safeWebsite(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }

  Future<void> _openWebsite(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showGlassToast(context, 'Could not open the website');
  }

  @override
  Widget build(BuildContext context) {
    final c = _charity;
    // The card carries the full name, which may wrap; a long one would be cut
    // off in the one-line title.
    return GlassPage(
      title: 'Charity',
      dock: widget.choosable && c != null
          ? GlassButton(
              label: 'Choose this charity',
              onPressed: () => Navigator.pop(context, true),
            )
          : null,
      children: _body(c),
    );
  }

  List<Widget> _body(CharityPrincipalRes? c) {
    if (_error case final error?) {
      return [
        GlassBanner(
          icon: Icons.cloud_off_rounded,
          title: error.title,
          body: error.detail,
          error: true,
          action: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      ];
    }
    if (c == null) return const [SizedBox(height: 320, child: AppLoader())];

    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final countries = (c.countries ?? const []).join(', ');
    final website = _safeWebsite(c.websiteUrl);
    final facts = [
      if (countries.isNotEmpty) (Icons.public_rounded, 'Countries', countries),
      if ((c.primaryRegistrationNumber ?? '').isNotEmpty)
        (
          Icons.badge_outlined,
          'Registration number',
          c.primaryRegistrationNumber!,
        ),
      if ((c.primaryRegistrationCountry ?? '').isNotEmpty)
        (Icons.flag_outlined, 'Registered in', c.primaryRegistrationCountry!),
    ];

    return [
      const SizedBox(height: 4),
      Glass(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CharityLogo(url: c.logoUrl, size: 56),
            const SizedBox(height: 14),
            Text(
              c.name ?? 'Unnamed charity',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((c.mission ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                c.mission!,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
      if (facts.isNotEmpty)
        GlassSection(
          title: 'About',
          children: [
            for (final (icon, label, value) in facts)
              GlassRow(leading: Icon(icon), title: label, subtitle: value),
          ],
        ),
      if (website != null) ...[
        const SizedBox(height: 16),
        Glass(
          child: GlassRow(
            leading: Icon(Icons.open_in_new_rounded, color: t.accent),
            title: 'Visit website',
            accent: true,
            chevron: false,
            onTap: () => _openWebsite(website),
          ),
        ),
      ],
    ];
  }
}

/// A charity's round logo, or a heart when it has none or it fails to load
/// (some logoUrls return HTML or a 404).
class CharityLogo extends StatelessWidget {
  final String? url;
  final double size;
  const CharityLogo({super.key, required this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(color: t.track, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.volunteer_activism_rounded,
          size: size * 0.5,
          color: t.muted,
        ),
      ),
    );
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return ClipOval(
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: Image.network(
          u,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
