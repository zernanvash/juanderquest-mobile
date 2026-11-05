import '../../../core/pixel/pixel_rpg.dart';
import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';

/// The compact, bordered label:value row from Pixel lab layout B.
///
/// The whole slot is the tap target and the minimum height lives inside the
/// border, so rows stay tight without an invisible tap area.
class HomeStatSlot extends StatelessWidget {
  const HomeStatSlot({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.valueColor,
    this.trailing,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.body(context),
            ),
          ),
          SizedBox(width: grid.px(1)),
          Flexible(
            child: Text(
              value,
              maxLines: 2,
              textAlign: TextAlign.end,
              style: PixelType.numbers(
                context,
                color: valueColor ?? PixelPalette.greenDark,
              ),
            ),
          ),
          if (trailing != null) ...[SizedBox(width: grid.px(1)), trailing!],
        ],
      ),
    );
    // Plan 75k: tappable stat rows press like inventory slots.
    return PixelTappableSlot(
      style: PixelBoxStyle.parchment,
      padding: 1,
      semanticLabel: '$label: $value',
      onTap: onTap,
      child: ExcludeSemantics(child: content),
    );
  }
}

class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(
                    context,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(width: grid.px(1)),
                Flexible(
                  // Right edge of the header, not the middle of the row.
                  child: Align(
                    alignment: Alignment.topRight,
                    child: PixelChip(
                      actionLabel!,
                      style: PixelBoxStyle.slot,
                      textColor: PixelPalette.greenDark,
                      onTap: onAction,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
          SizedBox(height: grid.px(2)),
          child,
        ],
      ),
    );
  }
}

class HomeInlineLoading extends StatelessWidget {
  const HomeInlineLoading({super.key, this.label = 'Loading'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Row(
      children: [
        const PixelLoader(artPx: 6),
        SizedBox(width: grid.px(2)),
        Expanded(
          child: Text(
            label,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ),
      ],
    );
  }
}

class HomeErrorPanel extends StatelessWidget {
  const HomeErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryKey,
  });

  final String message;
  final VoidCallback onRetry;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.slot,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelButton(
            key: retryKey,
            label: 'Retry',
            variant: PixelButtonVariant.secondary,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class HomeEmptyText extends StatelessWidget {
  const HomeEmptyText(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: PixelType.small(context, color: PixelPalette.slate));
}

String homeNumber(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$buffer';
}
