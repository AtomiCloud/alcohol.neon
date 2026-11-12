import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../config/dev_overrides.dart';
import '../../config/landscape.dart';
import '../../services/notification_service.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
import '../../widgets/glass_modal.dart';
import '../../widgets/glass_page.dart';

/// Prompts for the dev password ("iitm") then opens [DevConfigView]. Pass
/// [requirePassword] = false to skip the prompt (the pre-login logo path).
Future<void> openDevConfig(
  BuildContext context, {
  bool requirePassword = true,
}) async {
  if (requirePassword) {
    final ok = await _promptPassword(context);
    if (ok != true) return;
    if (!context.mounted) return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const DevConfigView()));
}

Future<bool?> _promptPassword(BuildContext context) =>
    showGlassSheet<bool>(context, (_) => const _PasswordSheet());

/// Pops true for the right password, false for a wrong one, and null when
/// dismissed.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_ctrl.text == 'iitm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Developer access',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _GlassField(
              controller: _ctrl,
              hint: 'Password',
              obscure: true,
              autofocus: true,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            GlassButton(label: 'Enter', onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

/// A borderless text field on a rounded glass fill.
class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  const _GlassField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Glass(
      radius: BorderRadius.circular(14),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        autofocus: autofocus,
        autocorrect: false,
        enableSuggestions: false,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: t.muted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// Hidden developer screen: view the active config and override the landscape or
/// individual fields at runtime. Overrides persist to a JSON file (see
/// [DevOverrides]) and apply on the next app start. Reached via secret gestures —
/// 7 taps on the sign-in logo, or 7 taps on the profile name + the dev password.
class DevConfigView extends StatefulWidget {
  const DevConfigView({super.key});

  @override
  State<DevConfigView> createState() => _DevConfigViewState();
}

class _DevConfigViewState extends State<DevConfigView> {
  // null = "Auto (from bundle id)".
  Landscape? _landscape;
  bool _loaded = false;
  String? _restartNotice;

  // Field key (matches the YAML keys) -> human label. Empty controller means
  // "no override — use the landscape default".
  static const _fieldLabels = <String, String>{
    'logtoEndpoint': 'Logto endpoint',
    'logtoAppId': 'Logto app id',
    'zincBaseUrl': 'Zinc base URL',
    'zincResource': 'Zinc API resource',
    'airwallexEnv': 'Airwallex env',
    'redirectUri': 'Redirect URI',
  };
  final _controllers = {
    for (final k in _fieldLabels.keys) k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final ov = await DevOverrides.load();
    if (!mounted) return;
    setState(() {
      _landscape = ov.landscape == null
          ? null
          : Landscape.values.firstWhere(
              (l) => l.name == ov.landscape,
              orElse: () => Landscape.pichu,
            );
      for (final e in ov.fields.entries) {
        _controllers[e.key]?.text = e.value;
      }
      _loaded = true;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The active value, shown as the placeholder for a blank override field.
  String _activeValue(String key) {
    final c = AppConfig.current;
    switch (key) {
      case 'logtoEndpoint':
        return c.logtoEndpoint;
      case 'logtoAppId':
        return c.logtoAppId;
      case 'zincBaseUrl':
        return c.zincBaseUrl.toString();
      case 'zincResource':
        return c.zincResource;
      case 'airwallexEnv':
        return c.airwallexEnv.name;
      case 'redirectUri':
        return c.redirectUri;
      default:
        return '';
    }
  }

  Future<void> _save() async {
    final fields = <String, String>{};
    for (final e in _controllers.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) fields[e.key] = v;
    }
    await DevOverrides(landscape: _landscape?.name, fields: fields).save();
    if (!mounted) return;
    _showRestart('Saved. Restart the app to apply.');
  }

  Future<void> _reset() async {
    final ok = await showGlassConfirm(
      context,
      title: 'Reset overrides?',
      message:
          'Every override is cleared, and the app goes back to the config '
          'from its bundle id after a restart.',
      confirmLabel: 'Reset',
    );
    if (!ok) return;
    await DevOverrides.clear();
    for (final c in _controllers.values) {
      c.clear();
    }
    if (!mounted) return;
    setState(() => _landscape = null);
    _showRestart('Overrides cleared. Restart the app to apply.');
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.instance.showNow();
    if (!mounted) return;
    showGlassToast(context, 'Test notification sent');
  }

  /// Saved overrides only apply on the next start, so the page keeps saying
  /// so, with a way to close the app.
  void _showRestart(String msg) => setState(() => _restartNotice = msg);

  Future<void> _pickLandscape() async {
    final picked = await showGlassSheet<(Landscape?,)>(
      context,
      (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Landscape',
                  style: Theme.of(
                    ctx,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              GlassSection(
                title: null,
                dividerIndent: 16,
                children: [
                  for (final l in <Landscape?>[null, ...Landscape.values])
                    GlassRow(
                      title: l?.name ?? 'Auto (bundle id)',
                      chevron: false,
                      trailing: l == _landscape
                          ? Icon(
                              Icons.check_rounded,
                              color: GlassTokens.of(ctx).accent,
                            )
                          : null,
                      onTap: () => Navigator.of(ctx).pop((l,)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _landscape = picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const GlassLoadingScreen();
    final c = AppConfig.current;
    return GlassPage(
      title: 'Developer',
      dock: GlassButton(label: 'Save', onPressed: _save),
      children: [
        if (_restartNotice case final notice?)
          GlassBanner(
            icon: Icons.restart_alt_rounded,
            title: notice,
            action: GlassTextButton(
              label: 'Close app',
              onPressed: () => SystemNavigator.pop(),
            ),
          ),
        GlassSection(
          title: 'Active',
          dividerIndent: 16,
          children: [
            _Value('Landscape', c.landscape.name),
            _Value('Logto endpoint', c.logtoEndpoint),
            _Value('Logto app id', c.logtoAppId),
            _Value('Zinc base URL', c.zincBaseUrl.toString()),
            _Value(
              'Zinc resource',
              c.zincResource.isEmpty ? '(none)' : c.zincResource,
            ),
            _Value('Airwallex env', c.airwallexEnv.name),
            _Value('Redirect URI', c.redirectUri),
            _Value('Scopes', c.scopes.join(' ')),
          ],
        ),
        GlassSection(
          title: 'Overrides',
          footer:
              'Restart the app to apply. A blank field uses the landscape '
              'default, shown greyed out.',
          dividerIndent: 16,
          children: [
            GlassRow(
              title: 'Landscape',
              value: _landscape?.name ?? 'Auto (bundle id)',
              chevron: true,
              onTap: _pickLandscape,
            ),
            for (final e in _fieldLabels.entries)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.value,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: GlassTokens.of(context).muted,
                      ),
                    ),
                    TextField(
                      controller: _controllers[e.key],
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        hintText: _activeValue(e.key),
                        hintStyle: TextStyle(
                          color: GlassTokens.of(context).muted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        GlassSection(
          title: 'Tools',
          children: [
            GlassRow(
              leading: const Icon(Icons.notifications_active_outlined),
              title: 'Send test notification',
              onTap: _sendTestNotification,
            ),
          ],
        ),
        GlassSection(
          children: [
            GlassRow(
              title: 'Reset overrides',
              destructive: true,
              centered: true,
              onTap: _reset,
            ),
          ],
        ),
      ],
    );
  }
}

/// A read-only config value: a muted label over selectable text.
class _Value extends StatelessWidget {
  final String label;
  final String value;
  const _Value(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: GlassTokens.of(context).muted,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
