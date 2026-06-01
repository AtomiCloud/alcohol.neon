import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../auth/sign_in_view.dart';
import 'authed_gate.dart';

/// Switches between signed-in and signed-out experiences based on auth state.
class RootView extends StatelessWidget {
  const RootView({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthService>().status;
    switch (status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.unauthenticated:
        return const SignInView();
      case AuthStatus.authenticated:
        return const AuthedGate();
      case AuthStatus.failed:
        return const _AuthFailedView();
    }
  }
}

class _AuthFailedView extends StatelessWidget {
  const _AuthFailedView();

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final problem = auth.lastError;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(problem?.title ?? 'Sign-in failed',
                  style: Theme.of(context).textTheme.titleMedium),
              if (problem?.detail != null) ...[
                const SizedBox(height: 8),
                Text(problem!.detail!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: auth.signIn, child: const Text('Try again')),
            ],
          ),
        ),
      ),
    );
  }
}
