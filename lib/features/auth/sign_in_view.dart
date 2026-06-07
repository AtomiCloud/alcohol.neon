import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../config/landscape.dart';
import '../dev/dev_config_view.dart';

/// Signed-out screen. Kicks off Logto's browser-based sign-in.
class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  bool _signingIn = false;

  // Secret dev-menu entry: 7 taps on the logo (resets after a 2s pause).
  int _logoTaps = 0;
  Timer? _tapReset;

  void _onLogoTap() {
    _tapReset?.cancel();
    _tapReset = Timer(const Duration(seconds: 2), () => _logoTaps = 0);
    if (++_logoTaps >= 7) {
      _logoTaps = 0;
      _tapReset?.cancel();
      openDevConfig(context, requirePassword: false);
    }
  }

  @override
  void dispose() {
    _tapReset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    // onSurfaceVariant stays readable in dark mode; `outline` (~#333) vanishes.
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final isProd = auth.config.landscape == Landscape.raichu;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              GestureDetector(
                onTap: _onLogoTap,
                behavior: HitTestBehavior.opaque,
                child: Image.asset(
                  'assets/brand/logo.png',
                  height: 112,
                  semanticLabel: 'LazyTax logo',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'LazyTax',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Stake money on your habits.\nMiss one, it goes to charity.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: muted),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _signingIn
                      ? null
                      : () async {
                          setState(() => _signingIn = true);
                          await auth.signIn();
                          if (mounted) setState(() => _signingIn = false);
                        },
                  child: _signingIn
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 12),
              // Env label on every landscape except prod (raichu).
              if (!isProd)
                Text(
                  'Environment: ${auth.config.landscape.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
