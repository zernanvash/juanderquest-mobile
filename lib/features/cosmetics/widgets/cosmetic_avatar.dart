import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_text.dart';

class CosmeticAvatar extends StatelessWidget {
  const CosmeticAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.frame,
    this.size = 48,
  });

  final String name;
  final String? imageUrl;
  final Map<String, dynamic>? frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ((frame?['colors'] as List?) ?? ['#ffd166']).map((v) {
      try {
        return Color(int.parse(v.toString().replaceFirst('#', '0xff')));
      } catch (_) {
        return PixelPalette.sun;
      }
    }).toList();
    final width = ((frame?['width'] as num?) ?? 0).toDouble();
    final borderColor = width > 0 ? colors.first : PixelPalette.wood;
    final borderWidth = width > 0 ? width : 2.0;

    return Container(
      width: size + borderWidth * 2,
      height: size + borderWidth * 2,
      decoration: BoxDecoration(
        color: PixelPalette.paper,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: width > 0 && colors.length > 1
            ? [
                BoxShadow(
                  color: colors[1].withValues(alpha: .6),
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ClipRect(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, _, ___) => _fallback(context),
              )
            : _fallback(context),
      ),
    );
  }

  Widget _fallback(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: DitherBackground(
          top: PixelPalette.greenMid,
          bottom: PixelPalette.greenDeep,
          child: Center(
            child: Text(
              name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
              style: PixelType.title(context, color: PixelPalette.paper),
            ),
          ),
        ),
      );
}
