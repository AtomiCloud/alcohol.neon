import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../session/session_controller.dart';
import '../dashboard/dashboard_view.dart';
import '../nfc/nfc_deep_links.dart';
import '../onboarding/onboarding_view.dart';

/// Shown once the user is authenticated. Runs the session bootstrap and routes to
/// onboarding or home based on its outcome.
class AuthedGate extends StatefulWidget {
  const AuthedGate({super.key});

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
        return const Scaffold(body: AppLoader());
      case SessionPhase.needsOnboarding:
        return const OnboardingView();
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                problem?.title ?? 'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (problem?.detail != null) ...[
                const SizedBox(height: 8),
                Text(problem!.detail!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: session.bootstrap,
                child: const Text('Try again'),
              ),
              const SizedBox(height: 4),
              // Escape hatch when the failure is auth-related (e.g. an expired
              // token that "Try again" can't recover) — re-authenticate.
              TextButton(
                onPressed: () => context.read<AuthService>().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
