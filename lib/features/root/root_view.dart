import 'package:flutter/material.dart';
import '../../widgets/app_loader.dart';
import '../../widgets/glass_list.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_service.dart';
import '../../session/session_controller.dart';
import '../../theme/glass.dart';
import '../auth/sign_in_view.dart';
import 'authed_gate.dart';

/// Switches between signed-in and signed-out experiences based on auth state.
class RootView extends StatefulWidget {
  const RootView({super.key});

  @override
  State<RootView> createState() => _RootViewState();
}

class _RootViewState extends State<RootView>
    with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  bool _started = false;
  bool _finished = false;
  bool _holdingFirstFrame = false;
  Brightness? _launchBrightness;

  void _releaseFirstFrame() {
    if (!_holdingFirstFrame) return;
    _holdingFirstFrame = false;
    WidgetsBinding.instance.allowFirstFrame();
  }

  @override
  void dispose() {
    _releaseFirstFrame();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthService>().status;
    final phase = status == AuthStatus.authenticated
        ? context.watch<SessionController>().phase
        : null;
    final loading =
        status == AuthStatus.loading ||
        phase == SessionPhase.idle ||
        phase == SessionPhase.bootstrapping;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _launchBrightness ??= MediaQuery.platformBrightnessOf(context);
    if (!loading || reducedMotion) {
      // Content always wins, including a cache hit during the fade. Never
      // replay branding after sign-in, retries, warm resumes or navigation.
      _finished = true;
      _fade.stop();
      _releaseFirstFrame();
    } else if (!_started && !_finished) {
      _started = true;
      // Decode before releasing a loading frame, otherwise Image.asset can
      // briefly paint only the base colour. This waits for local pixels, not
      // bootstrap or a minimum splash duration; ready content bypasses it.
      _holdingFirstFrame = true;
      WidgetsBinding.instance.deferFirstFrame();
      precacheImage(
        const AssetImage('assets/brand/logo.png'),
        context,
      ).whenComplete(() {
        _releaseFirstFrame();
        if (mounted && !_finished) _fade.forward();
      });
    }
    final child = switch (status) {
      AuthStatus.loading => const SizedBox.expand(),
      AuthStatus.unauthenticated => const SignInView(),
      AuthStatus.authenticated => const AuthedGate(
        loadingScreen: SizedBox.expand(),
      ),
      AuthStatus.failed => const _AuthFailedView(),
    };
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: loading, child: child),
        if (loading)
          Semantics(
            label: 'Loading LazyTax',
            child: ExcludeSemantics(
              child: AnimatedBuilder(
                animation: _fade,
                child: const AppLoader(),
                builder: (context, loader) {
                  final bridging = !_finished && _fade.value < 1;
                  final progress = bridging ? _fade.value : 1.0;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (bridging)
                        ColoredBox(
                          color: _launchBrightness == Brightness.dark
                              ? const Color(0xFF0A0A0A)
                              : const Color(0xFFF2F2F7),
                        ),
                      Opacity(
                        key: const ValueKey('launch-backdrop'),
                        opacity: progress,
                        child: const AmbientBackdrop(child: SizedBox.expand()),
                      ),
                      Opacity(
                        key: const ValueKey('launch-loader'),
                        // Fade through the backdrop, never overlapping the
                        // differently drawn native mark and Lottie mascot.
                        opacity: (progress * 2 - 1).clamp(0.0, 1.0),
                        child: loader,
                      ),
                      if (bridging)
                        Opacity(
                          opacity: (1 - progress * 2).clamp(0.0, 1.0),
                          child: Center(
                            child: Image.asset(
                              'assets/brand/logo.png',
                              width: 128,
                              height: 128,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
      ],
    );
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
