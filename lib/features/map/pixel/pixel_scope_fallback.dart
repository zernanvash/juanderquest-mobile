import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/pixel_grid.dart';

/// Wraps [child] in a fallback [PixelScope] if neither [PixelScope] nor
/// [ProviderScope] is present in the ancestor tree (e.g. in isolated widget tests).
class PixelScopeFallback extends StatelessWidget {
  const PixelScopeFallback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<PixelScope>() != null) {
      return child;
    }
    if (context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null) {
      return child;
    }
    return PixelScope(
      settings: const PixelSettings(),
      child: child,
    );
  }
}
