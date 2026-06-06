import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';

/// Signed-out screen. Kicks off Logto's browser-based sign-in.
class SignInView extends StatefulWidget {
  const SignInView({super.key});

  @override
  State<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<SignInView> {
  bool _signingIn = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final outline = Theme.of(context).colorScheme.outline;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Image.asset(
                'assets/brand/logo.png',
                height: 112,
                semanticLabel: 'LazyTax logo',
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
                ).textTheme.bodyLarge?.copyWith(color: outline),
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
              Text(
                'Environment: ${auth.config.landscape.name}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
