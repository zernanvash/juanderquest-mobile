import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'generated/pixel_palette.g.dart';

abstract final class PixelFonts {
  static const families = <String>[
    'Silkscreen',
    'Monocraft',
    'PixelifySans',
    'VT323',
    'PressStart2P',
  ];

  static const _licences = <String, String>{
    'Silkscreen': 'assets/licenses/ofl-silkscreen.txt',
    'Monocraft': 'assets/licenses/ofl-monocraft.txt',
    'PixelifySans': 'assets/licenses/ofl-pixelifysans.txt',
    'VT323': 'assets/licenses/ofl-vt323.txt',
    'PressStart2P': 'assets/licenses/ofl-pressstart2p.txt',
  };

  static void registerLicences() {
    LicenseRegistry.addLicense(() async* {
      for (final entry in _licences.entries) {
        try {
          final text = await rootBundle.loadString(entry.value);
          yield LicenseEntryWithLineBreaks([entry.key], text);
        } catch (_) {
          continue;
        }
      }
    });
  }
}

abstract final class PixelTheme {
  static final transparent = PixelPalette.ink.withValues(alpha: 0);

  static TextStyle _text(
    double size, {
    Color color = PixelPalette.ink,
    bool bold = false,
  }) =>
      TextStyle(
        fontFamily: 'Monocraft',
        fontSize: size,
        height: 1.25,
        letterSpacing: 0,
        color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      );

  static ThemeData build() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Monocraft',
      scaffoldBackgroundColor: PixelPalette.paper,
      primaryColor: PixelPalette.green,
      colorScheme: const ColorScheme.light(
        primary: PixelPalette.green,
        onPrimary: PixelPalette.white,
        primaryContainer: PixelPalette.greenLight,
        onPrimaryContainer: PixelPalette.greenDeep,
        secondary: PixelPalette.sun,
        onSecondary: PixelPalette.ink,
        secondaryContainer: PixelPalette.sunLight,
        onSecondaryContainer: PixelPalette.goldDeep,
        surface: PixelPalette.paper,
        onSurface: PixelPalette.ink,
        surfaceContainer: PixelPalette.paperDim,
        surfaceContainerHigh: PixelPalette.paperDim,
        surfaceContainerHighest: PixelPalette.paperDim,
        surfaceContainerLowest: PixelPalette.white,
        error: PixelPalette.red,
        onError: PixelPalette.white,
        errorContainer: PixelPalette.redLight,
        onErrorContainer: PixelPalette.redDeep,
        outline: PixelPalette.slate,
        outlineVariant: PixelPalette.mist,
      ),
      splashFactory: NoSplash.splashFactory,
      splashColor: transparent,
      highlightColor: transparent,
      hoverColor: transparent,
      focusColor: PixelPalette.greenLight,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: PixelPalette.ink,
        selectionColor: PixelPalette.greenLight,
        selectionHandleColor: PixelPalette.green,
      ),
      textTheme: TextTheme(
        displayLarge: _text(32, bold: true),
        displayMedium: _text(28, bold: true),
        displaySmall: _text(24, bold: true),
        headlineLarge: _text(24, bold: true),
        headlineMedium: _text(22, bold: true),
        headlineSmall: _text(20, bold: true),
        titleLarge: _text(20, bold: true),
        titleMedium: _text(16, bold: true),
        titleSmall: _text(16, bold: true),
        bodyLarge: _text(16),
        bodyMedium: _text(16),
        bodySmall: _text(8),
        labelLarge: _text(16, bold: true),
        labelMedium: _text(16),
        labelSmall: _text(8),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: PixelPalette.ink,
        foregroundColor: PixelPalette.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: PixelPalette.paper),
        titleTextStyle: _text(24, color: PixelPalette.paper, bold: true),
      ),
      iconTheme: const IconThemeData(color: PixelPalette.ink),
      dividerTheme: const DividerThemeData(
        color: PixelPalette.mist,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: PixelPalette.parchment,
        surfaceTintColor: transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PixelPalette.parchment,
        surfaceTintColor: transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        titleTextStyle: _text(24, bold: true),
        contentTextStyle: _text(16, color: PixelPalette.slate),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        contentTextStyle: _text(16, color: PixelPalette.paper),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PixelPalette.green,
          foregroundColor: PixelPalette.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _text(16, color: PixelPalette.white, bold: true),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PixelPalette.green,
          foregroundColor: PixelPalette.white,
          elevation: 0,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _text(16, color: PixelPalette.white, bold: true),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PixelPalette.ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: PixelPalette.ink, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _text(16, bold: true),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PixelPalette.greenDark,
          minimumSize: const Size(0, 48),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: _text(16, bold: true),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PixelPalette.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: PixelPalette.ink, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: PixelPalette.ink, width: 1),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: PixelPalette.green, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: PixelPalette.alert, width: 1),
        ),
        hintStyle: _text(16, color: PixelPalette.stone),
        labelStyle: _text(16, color: PixelPalette.slate),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: PixelPalette.ink,
        selectedItemColor: PixelPalette.sun,
        unselectedItemColor: PixelPalette.paper,
        selectedLabelStyle: _text(16, color: PixelPalette.sun, bold: true),
        unselectedLabelStyle: _text(16, color: PixelPalette.paper),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: PixelPalette.ink,
          border: Border.all(color: PixelPalette.paper, width: 1),
        ),
        textStyle: _text(8, color: PixelPalette.paper),
      ),
    );
  }
}
