import 'package:flutter/material.dart';
import '../pixel/pixel_theme.dart';
import 'app_colors.dart';

/// Centralized typography tokens. Owner 2026-11-05: Silkscreen everywhere, Monocraft for missing symbols
/// (was Epilogue headings + Plus Jakarta Sans body).
abstract class AppTypography {
  // Headings — Epilogue
  static TextStyle displayLarge = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.woodBrown,
  );

  static TextStyle displayMedium = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: AppColors.woodBrown,
  );

  static TextStyle displaySmall = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.woodBrown,
  );

  static TextStyle headlineLarge = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.deepInk,
  );

  static TextStyle headlineMedium = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.deepInk,
  );

  static TextStyle headlineSmall = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.deepInk,
  );

  // Body & Labels — Plus Jakarta Sans
  static TextStyle bodyLarge = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.deepInk,
  );

  static TextStyle bodyMedium = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static TextStyle bodySmall = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textMuted,
  );

  static TextStyle labelLarge = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.deepInk,
  );

  static TextStyle labelMedium = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: AppColors.deepInk,
  );

  static TextStyle labelSmall = const TextStyle(fontFamily: 'Silkscreen', fontFamilyFallback: PixelFonts.fallback, 
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );
}
