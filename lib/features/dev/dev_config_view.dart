import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';
import '../../config/dev_overrides.dart';
import '../../config/landscape.dart';

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

Future<bool?> _promptPassword(BuildContext context) {
  final ctrl = TextEditingController();
  bool check() => ctrl.text == 'iitm';
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Developer access'),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
        onSubmitted: (_) => Navigator.of(ctx).pop(check()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(check()),
          child: const Text('Enter'),
        ),
      ],
    ),
  );
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
    await DevOverrides.clear();
    for (final c in _controllers.values) {
      c.clear();
    }
    if (!mounted) return;
    setState(() => _landscape = null);
    _showRestart('Overrides cleared. Restart the app to apply.');
  }

  void _showRestart(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Close app',
          onPressed: () => SystemNavigator.pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_loaded) {
      return const Scaffold(body: AppLoader());
    }
    final c = AppConfig.current;
    return Scaffold(
      appBar: AppBar(title: const Text('Developer · Config')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('ACTIVE', style: theme.textTheme.labelSmall),
          const SizedBox(height: 8),
          _kv('Landscape', c.landscape.name),
          _kv('Logto endpoint', c.logtoEndpoint),
          _kv('Logto app id', c.logtoAppId),
          _kv('Zinc base URL', c.zincBaseUrl.toString()),
          _kv(
            'Zinc resource',
            c.zincResource.isEmpty ? '(none)' : c.zincResource,
          ),
          _kv('Airwallex env', c.airwallexEnv.name),
          _kv('Redirect URI', c.redirectUri),
          _kv('Scopes', c.scopes.join(' ')),
          const Divider(height: 32),
          Text(
            'OVERRIDES — restart to apply',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<Landscape?>(
            initialValue: _landscape,
            decoration: const InputDecoration(
              labelText: 'Landscape',
              helperText: 'Switch the whole config to another landscape',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Auto (bundle id)'),
              ),
              for (final l in Landscape.values)
                DropdownMenuItem(value: l, child: Text(l.name)),
            ],
            onChanged: (v) => setState(() => _landscape = v),
          ),
          const SizedBox(height: 16),
          for (final e in _fieldLabels.entries) ...[
            TextField(
              controller: _controllers[e.key],
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: e.value,
                hintText: _activeValue(e.key),
                helperText: 'Blank = use the landscape default',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _reset,
            icon: const Icon(Icons.restore),
            label: const Text('Reset overrides'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(k, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(child: SelectableText(v, style: theme.textTheme.bodySmall)),
      ],
    ),
  );

  ThemeData get theme => Theme.of(context);
}
