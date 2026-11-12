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
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              title!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: t.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          const SizedBox(height: 24),
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
  const GlassButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = GlassTokens.of(context);
    final enabled = onPressed != null && !busy;
    final fg = enabled || busy ? t.onAccent : t.muted;
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
            color: enabled || busy ? t.accent : t.track,
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
