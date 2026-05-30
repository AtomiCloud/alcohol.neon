import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

/// Signed-in landing screen. For the foundation it proves the stack: Logto claims are
/// readable and a zinc-scoped access token can be minted. Real habit screens replace it.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

enum _ApiCheck { idle, checking, ok, failed }

class _HomeViewState extends State<HomeView> {
  _ApiCheck _check = _ApiCheck.idle;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('LazyTax'),
        actions: [TextButton(onPressed: auth.signOut, child: const Text('Sign out'))],
      ),
      body: FutureBuilder<UserClaims?>(
        future: auth.claims(),
        builder: (context, snapshot) {
          final claims = snapshot.data;
          return ListView(
            children: [
              _header('Signed in'),
              _row('Name', claims?.name ?? '—'),
              _row('Email', claims?.email ?? '—'),
              _row('Subject', claims?.sub ?? '—'),
              _header('Environment'),
              _row('Landscape', auth.config.landscape.name),
              _row('API', auth.config.zincBaseUrl.host),
              _header('API access'),
              _apiTile(auth),
            ],
          );
        },
      ),
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text.toUpperCase(),
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _row(String key, String value) =>
      ListTile(dense: true, title: Text(key), subtitle: Text(value));

  Widget _apiTile(AuthService auth) {
    switch (_check) {
      case _ApiCheck.checking:
        return const ListTile(
          leading: SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          title: Text('Minting access token…'),
        );
      case _ApiCheck.ok:
        return const ListTile(
          leading: Icon(Icons.verified, color: Colors.green),
          title: Text('Access token acquired for zinc'),
        );
      case _ApiCheck.failed:
        return ListTile(
          leading: const Icon(Icons.error_outline, color: Colors.red),
          title: const Text('Could not acquire zinc access token'),
          subtitle: const Text('No zinc resource configured for this tenant, or token unavailable.'),
          onTap: () => _runCheck(auth),
        );
      case _ApiCheck.idle:
        return ListTile(
          leading: const Icon(Icons.key_outlined),
          title: const Text('Check zinc API access'),
          onTap: () => _runCheck(auth),
        );
    }
  }

  Future<void> _runCheck(AuthService auth) async {
    setState(() => _check = _ApiCheck.checking);
    final token = await auth.zincAccessToken();
    if (!mounted) return;
    setState(() => _check = token != null ? _ApiCheck.ok : _ApiCheck.failed);
  }
}
