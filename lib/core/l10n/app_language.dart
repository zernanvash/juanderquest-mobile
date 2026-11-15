import 'package:flutter/widgets.dart';

import '../pixel/pixel_grid.dart';

export '../pixel/pixel_grid.dart' show AppLanguage;

/// Plan 93b WP-8: picks the English or Tagalog string for the traveler's
/// chosen language (Settings -> Language).
String tr(BuildContext context, {required String en, required String tl}) =>
    PixelScope.of(context).language == AppLanguage.tagalog ? tl : en;
