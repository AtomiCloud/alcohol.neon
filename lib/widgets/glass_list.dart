import 'package:flutter/material.dart';

import '../theme/glass.dart';
import 'glass_page.dart';

/// A labelled glass group of rows, like Today's "Later today" list: a muted
/// [title] above, 0.5px separators between [children], and an optional muted
/// [footer] below that explains the group.
class GlassSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final String? footer;

  /// Where separators start, so they line up with the row text: 54 after an
  /// icon, 60 after an [IconTile], 16 with no leading.
  final double dividerIndent;

  const GlassSection({
    super.key,
    this.title,
    required this.children,
    this.footer,
    this.dividerIndent = 54,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) GlassHeading(title!) else const SizedBox(height: 24),
        Glass(
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: EdgeInsets.only(left: dividerIndent),
                    child: Divider(height: 0.5, color: t.separator),
                  ),
                children[i],
              ],
            ],
          ),
        ),
        if (footer != null) GlassFooter(footer!),
      ],
    );
  }
}

/// The muted label above a glass group.
class GlassHeading extends StatelessWidget {
  final String text;
  const GlassHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: GlassTokens.of(context).muted,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Small muted text under a [GlassSection].
class GlassFooter extends StatelessWidget {
  final String text;
  const GlassFooter(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: GlassTokens.of(context).muted),
    ),
  );
}

/// One row in a [GlassSection]: a [leading] icon or [IconTile], a title with
/// an optional one-line [subtitle], an optional muted [value] and a
/// [trailing] control. A tappable row shrinks a little while pressed, with no
/// ripple, on both platforms, and shows a chevron on iOS only.
class GlassRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool accent;

  /// Centers the title, for a lone action such as Sign out.
  final bool centered;

  /// Whether to show the iOS chevron; defaults to "tappable, without a
  /// trailing control".
  final bool? chevron;

  const GlassRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.accent = false,
    this.centered = false,
    this.chevron,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final color = destructive
        ? theme.colorScheme.error
        : accent
        ? t.accent
        : theme.colorScheme.onSurface;
    final showChevron =
        (chevron ?? (onTap != null && trailing == null)) &&
        isCupertino(context);
    final text = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(color: t.muted),
          ),
        ],
      ],
    );
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[
              IconTheme.merge(
                data: IconThemeData(
                  color: destructive ? theme.colorScheme.error : t.muted,
                  size: 22,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 24),
                  child: Center(widthFactor: 1, child: leading),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(child: text),
            if (value != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(color: t.muted),
                ),
              ),
            ],
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.muted),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return Semantics(container: true, child: row);
    return Semantics(
      button: true,
      child: Pressable(onTap: onTap, scale: 0.98, child: row),
    );
  }
}

/// A [Glass] card for Material list tiles, which paint on their own
/// transparent Material so they show over the glass fill.
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Glass(
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// A coloured rounded square behind a white icon, for launcher rows.
class IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const IconTile(this.icon, this.color, {super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
    ),
    child: SizedBox.square(
      dimension: 30,
      child: Icon(icon, size: 18, color: Colors.white),
    ),
  );
}

/// The emerald switch, in each platform's style.
class GlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const GlassSwitch({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    if (isCupertino(context)) {
      return Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: t.accent,
      );
    }
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.onAccent : t.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.accent : Colors.transparent,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.transparent : t.muted,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }
}

/// The emerald stadium button from Today's Next up card. It shrinks while
/// pressed instead of showing a ripple; [busy] swaps the label for a spinner.
class GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final bool compact;

  /// A quieter grey button for the second choice, such as Not now.
  final bool secondary;
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.compact = false,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final enabled = onPressed != null && !busy;
    final fg = !(enabled || busy)
        ? t.muted
        : secondary
        ? theme.colorScheme.onSurface
        : t.onAccent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        scale: 0.96,
        child: AnimatedContainer(
          duration: GlassMotion.of(context, GlassMotion.fast),
          height: compact ? 34 : 50,
          padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 20),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            color: (enabled || busy) && !secondary ? t.accent : t.track,
          ),
          child: busy
              ? SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: fg,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

/// A text-only action, such as Retry in a [GlassBanner] or Not now under a
/// [GlassButton]: emerald text ([muted] grey, [destructive] red) that shrinks
/// while pressed, with no ripple, on both platforms.
class GlassTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool muted;
  final bool destructive;
  const GlassTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.muted = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final enabled = onPressed != null;
    final color = destructive
        ? theme.colorScheme.error
        : muted
        ? t.muted
        : t.accent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onPressed,
        scale: 0.94,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              widthFactor: 1,
              child: Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Text(
                  label,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A centered glass card for a state that fills a screen, such as an empty
/// list, a load error or the result of an NFC tap: [visual] (an icon in a
/// tinted circle by default), a title, a muted [body] and its actions.
class GlassMessage extends StatelessWidget {
  final IconData icon;

  /// The circle's tint: emerald for success, red for an error, grey when null.
  final Color? tint;

  /// Replaces the icon, such as a spinner while working.
  final Widget? visual;
  final String title;
  final String? body;

  /// Usually one [GlassButton], then an optional [GlassTextButton].
  final List<Widget> actions;
  const GlassMessage({
    super.key,
    required this.icon,
    required this.title,
    this.tint,
    this.visual,
    this.body,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final color = tint ?? t.muted;
    return Glass(
      radius: const BorderRadius.all(Radius.circular(28)),
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.14),
              ),
              child: visual ?? Icon(icon, size: 36, color: color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: t.muted),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            for (final a in actions) Center(child: a),
          ],
        ],
      ),
    );
  }
}

/// A whole screen holding one [GlassMessage] on the glass backdrop, such as
/// the sign-in or session error with Try again.
class GlassMessageScreen extends StatelessWidget {
  final GlassMessage message;
  const GlassMessageScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) => AmbientBackdrop(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: message,
          ),
        ),
      ),
    ),
  );
}

/// A glass notice at the top of a page's content, such as an error with a
/// retry. The same banner Today uses.
class GlassBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  final bool error;
  const GlassBanner({
    super.key,
    required this.icon,
    required this.title,
    this.action,
    this.body,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final tint = error ? theme.colorScheme.error : t.muted;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Glass(
        strong: true,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(icon, color: tint),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: error ? theme.colorScheme.error : null,
                    ),
                  ),
                  if (body != null)
                    Text(
                      body!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: t.muted,
                      ),
                    ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A glass search bar under a page title: a rounded rectangle on iOS and a
/// Material 3 pill on Android.
class GlassSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final bool autofocus;
  const GlassSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Glass(
      radius: BorderRadius.circular(isCupertino(context) ? 14 : 28),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: t.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              autofocus: autofocus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: t.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small glass pill, such as a stake amount or a search filter. [on]
/// fills it emerald; [icon] sits after the label.
class GlassPill extends StatelessWidget {
  final String label;
  final bool on;
  final IconData? icon;
  final VoidCallback onTap;
  const GlassPill({
    super.key,
    required this.label,
    required this.onTap,
    this.on = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    final fg = on ? t.onAccent : Theme.of(context).colorScheme.onSurface;
    return Semantics(
      button: true,
      selected: on,
      child: Pressable(
        onTap: onTap,
        scale: 0.94,
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 8, icon == null ? 16 : 10, 8),
          decoration: ShapeDecoration(
            shape: StadiumBorder(side: BorderSide(color: t.separator)),
            color: on ? t.accent : t.fill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, color: fg),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 4),
                Icon(icon, size: 18, color: on ? fg : t.muted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
