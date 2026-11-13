import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../session/session_controller.dart';
import '../dashboard/dashboard_view.dart';
import '../nfc/nfc_deep_links.dart';

/// Shown once the user is authenticated. Runs the session bootstrap, then shows
/// Today (or the bootstrap error).
class AuthedGate extends StatefulWidget {
  final Widget loadingScreen;
  const AuthedGate({
    super.key,
    this.loadingScreen = const GlassLoadingScreen(),
  });

  @override
  State<AuthedGate> createState() => _AuthedGateState();
}

class _AuthedGateState extends State<AuthedGate> {
  @override
  void initState() {
    super.initState();
    // Kick off after the first frame so the provider is safely readable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SessionController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    switch (session.phase) {
      case SessionPhase.idle:
      case SessionPhase.bootstrapping:
        return widget.loadingScreen;
      case SessionPhase.ready:
        // NfcTapListener consumes a pending /t/{tagId} link (NFC tap) once the
        // session is usable, pushing the tap-to-complete screen.
        return const NfcTapListener(child: DashboardView());
      case SessionPhase.error:
        return _BootstrapError(session: session);
    }
  }
}

class _BootstrapError extends StatelessWidget {
  final SessionController session;
  const _BootstrapError({required this.session});

  @override
  Widget build(BuildContext context) {
    final problem = session.error;
    return GlassMessageScreen(
      message: GlassMessage(
        icon: Icons.cloud_off_rounded,
        tint: Theme.of(context).colorScheme.error,
        title: problem?.title ?? 'Something went wrong',
        body: problem?.detail,
        actions: [
          GlassButton(label: 'Try again', onPressed: session.bootstrap),
          const SizedBox(height: 4),
          // Escape hatch when the failure is auth-related (e.g. an expired
          // token that "Try again" can't recover) — re-authenticate.
          GlassTextButton(
            label: 'Sign out',
            muted: true,
            onPressed: () => context.read<AuthService>().signOut(),
          ),
        ],
      ),
    );
  }
}
