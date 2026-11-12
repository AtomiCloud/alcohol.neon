import 'package:flutter/material.dart';
import '../../widgets/glass_modal.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../theme/glass.dart';
import '../../widgets/glass_list.dart';

/// Bottom-sheet stake entry, mirroring argon's StakeSheet: a big USD amount,
/// quick-pick chips and a numeric keypad working in cents (so there's no decimal
/// typing). Returns the chosen amount as a decimal string ("10.50"), or null if
/// cancelled.
Future<String?> showStakeSheet(BuildContext context, {String? initial}) {
  return showGlassSheet<String>(context, (_) => _StakeSheet(initial: initial));
}

class _StakeSheet extends StatefulWidget {
  final String? initial;
  const _StakeSheet({this.initial});

  @override
  State<_StakeSheet> createState() => _StakeSheetState();
}

class _StakeSheetState extends State<_StakeSheet> {
  late int _cents = ((double.tryParse(widget.initial ?? '') ?? 0) * 100)
      .round();

  String get _decimal => (_cents / 100).toStringAsFixed(2);

  void _append(String k) {
    setState(() {
      switch (k) {
        case 'C':
          _cents = 0;
        case '⌫': // ⌫
          _cents ~/= 10;
        default:
          final next = _cents * 10 + int.parse(k);
          if (next <= 9999999) _cents = next; // cap $99,999.99
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set your stake', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Charged to your charity if you miss a day',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            RichText(
              text: TextSpan(
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.money,
                ),
                children: [
                  const TextSpan(text: '\$'),
                  TextSpan(text: _decimal),
                  TextSpan(
                    text: '  USD',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final v in const [1, 5, 10, 20])
                  _Chip(
                    label: '\$$v',
                    on: _cents == v * 100,
                    onTap: () => setState(() => _cents = v * 100),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                for (final k in const [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  '⌫',
                  '0',
                  'C',
                ])
                  _key(theme, k),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: GlassTokens.of(context).muted,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassButton(
                    label: 'Set stake',
                    onPressed: () => Navigator.pop(context, _decimal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _key(ThemeData theme, String k) {
    return Pressable(
      onTap: () => _append(k),
      scale: 0.94,
      child: Glass(
        radius: const BorderRadius.all(Radius.circular(14)),
        child: Center(
          child: Text(
            k,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// A quick-pick amount, filled when it's the current stake.
class _Chip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = GlassTokens.of(context);
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: ShapeDecoration(
          shape: StadiumBorder(side: BorderSide(color: t.separator)),
          color: on ? t.accent : t.fill,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: on ? t.onAccent : null,
          ),
        ),
      ),
    );
  }
}
