import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../config/landscape.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';
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
    final theme = Theme.of(context);
    final muted = GlassTokens.of(context).muted;
    final isProd = auth.config.landscape == Landscape.raichu;
    return AmbientBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Stake money on your habits.\nMiss one, it goes to charity.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(color: muted),
                ),
                const Spacer(),
                GlassButton(
                  label: 'Sign in',
                  busy: _signingIn,
                  onPressed: () async {
                    setState(() => _signingIn = true);
                    await auth.signIn();
                    if (mounted) setState(() => _signingIn = false);
                  },
                ),
                const SizedBox(height: 12),
                // Env label on every landscape except prod (raichu).
                if (!isProd)
                  Text(
                    'Environment: ${auth.config.landscape.name}',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
