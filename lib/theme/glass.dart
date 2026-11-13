import 'dart:ui';

import 'package:flutter/material.dart';

/// The frosted-glass look shared by the Today screen and its chrome.
///
/// Two kinds of glass, so it stays smooth on older Android GPUs:
/// - [Glass] with `blur: false` (the default) is a translucent fill over the
///   static [AmbientBackdrop]. The backdrop never moves, so the fill reads as
///   frosted glass without a per-frame blur.
/// - [Glass] with `blur: true` samples and blurs whatever is behind it. Use it
///   only where content scrolls underneath: the top bar, the tab bar, sheets.
class GlassTokens {
  final Color fill;
  final Color strongFill;
  final Color highlight;
  final Color edge;
  final Color separator;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color track;

  const GlassTokens._({
    required this.fill,
    required this.strongFill,
    required this.highlight,
    required this.edge,
    required this.separator,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.track,
  });

  static const _dark = GlassTokens._(
    fill: Color(0x801C1C1E),
    strongFill: Color(0xB81C1C1E),
    highlight: Color(0x1AFFFFFF),
    edge: Color(0x1AFFFFFF),
    separator: Color(0x1AFFFFFF),
    muted: Color(0x9EEBEBF5),
    accent: Color(0xFF34D399),
    onAccent: Color(0xFF052E1B),
    track: Color(0x1FFFFFFF),
  );

  static const _light = GlassTokens._(
    fill: Color(0x8CFFFFFF),
    strongFill: Color(0xC7FFFFFF),
    highlight: Color(0xE6FFFFFF),
    edge: Color(0x0F000000),
    separator: Color(0x243C3C43),
    muted: Color(0x9E3C3C43),
    accent: Color(0xFF059669),
    onAccent: Colors.white,
    track: Color(0x14000000),
  );

  static GlassTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;
}

/// Shared motion: one spring-like curve and two durations, so every
/// transition on the screen feels the same.
class GlassMotion {
  static const curve = Cubic(0.22, 1, 0.36, 1);
  static const fast = Duration(milliseconds: 220);
  static const slow = Duration(milliseconds: 480);

  /// Honors the system Reduce Motion setting.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.of(context).disableAnimations ? Duration.zero : d;
}

/// Soft emerald, teal and violet glows behind the glass, taken from the brand.
/// Painted with radial gradients, so it costs no blur pass.
class AmbientBackdrop extends StatelessWidget {
  final Widget child;
  const AmbientBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0A0A0A) : const Color(0xFFF2F2F7),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: _GlowPainter(dark: dark)),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  final bool dark;
  const _GlowPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final o = dark ? 1.0 : 0.45;
    void glow(Offset c, double r, Color color, double a) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: a * o),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r));
      canvas.drawCircle(c, r, paint);
    }

    final w = size.width, h = size.height;
    glow(Offset(w * 0.15, h * 0.18), w * 0.85, const Color(0xFF059669), 0.75);
    glow(Offset(w * 0.95, h * 0.5), w * 0.8, const Color(0xFF1B5453), 0.9);
    glow(Offset(w * 0.3, h * 1.0), w * 0.8, const Color(0xFF7C3AED), 0.45);
    glow(Offset(w * 0.9, h * 0.02), w * 0.5, const Color(0xFF2DD4BF), 0.4);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.dark != dark;
}

/// A rounded glass surface. See [GlassTokens] for when to pass `blur: true`.
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius radius;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final bool strong;

  const Glass({
    super.key,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(22)),
    this.padding = EdgeInsets.zero,
    this.blur = false,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: strong ? t.strongFill : t.fill,
        borderRadius: radius,
        border: Border.all(color: t.edge, width: 0.5),
      ),
      child: Padding(padding: padding, child: child),
    );
    if (!blur) {
      return ClipRRect(borderRadius: radius, child: surface);
    }
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: surface,
      ),
    );
  }
}

/// A progress ring that animates to [value] (0 to 1) with [GlassMotion].
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Widget? child;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 40,
    this.stroke = 4,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1)),
      duration: GlassMotion.of(context, GlassMotion.slow),
      curve: GlassMotion.curve,
      builder: (context, v, _) => SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(v, stroke, t.track, t.accent),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final double stroke;
  final Color track;
  final Color fill;
  const _RingPainter(this.value, this.stroke, this.track, this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.2832, false, paint..color = track);
    if (value > 0) {
      canvas.drawArc(rect, -1.5708, 6.2832 * value, false, paint..color = fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.track != track || old.fill != fill;
}

/// Fades and lifts its child in once, [index] steps after the first, so a
/// screen's sections arrive one after another instead of all at once.
class Appear extends StatefulWidget {
  final int index;
  final Widget child;

  /// [child] is a sliver: it fades in without the slide.
  final bool sliver;
  const Appear({
    super.key,
    this.index = 0,
    this.sliver = false,
    required this.child,
  });

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  // The stagger is a lead-in inside one controller (no timers), capped so
  // long lists don't wait.
  late final int _lead = 50 * widget.index.clamp(0, 6);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: GlassMotion.slow + Duration(milliseconds: _lead),
  );
  late final Animation<double> _a = CurvedAnimation(
    parent: _c,
    curve: Interval(
      _lead / (_c.duration!.inMilliseconds),
      1,
      curve: GlassMotion.curve,
    ),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.sliver
      ? SliverFadeTransition(opacity: _a, sliver: widget.child)
      : FadeTransition(
          opacity: _a,
          child: AnimatedBuilder(
            animation: _a,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, 14 * (1 - _a.value)),
              child: child,
            ),
            child: widget.child,
          ),
        );
}

/// Shrinks slightly while pressed, the way iOS buttons and cards respond.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: GlassMotion.of(context, GlassMotion.fast),
        curve: GlassMotion.curve,
        child: widget.child,
      ),
    );
  }
}
