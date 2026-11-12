import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
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
        return const GlassLoadingScreen();
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
    return GlassMessageScreen(
      message: GlassMessage(
        icon: Icons.lock_outline_rounded,
        tint: Theme.of(context).colorScheme.error,
        title: problem?.title ?? 'Sign-in failed',
        body: problem?.detail,
        actions: [GlassButton(label: 'Try again', onPressed: auth.signIn)],
      ),
    );
  }
}
