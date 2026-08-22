import 'package:flutter/material.dart';

/// Centralized semantic color tokens for JuanderQuest.
///
/// Palette identity: Warm, adventurous, local, trustworthy, optimistic.
/// Nature greens, sunlight gold, warm paper background, grounded wood brown.
abstract class AppColors {
  // Brand Core
  static const Color primary = Color(0xFF3F6653); // Tourism Green
  static const Color primaryDark = Color(0xFF274E3C);
  static const Color primaryContainer = Color(0xFFC1ECD4);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF002114);

  static const Color sunGold = Color(0xFFFFB703); // Sun Gold / Rewards
  static const Color secondary = Color(0xFF7D5800);
  static const Color secondaryContainer = Color(0xFFFFDEA9);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF6B4B00);

  // Background & Surfaces
  static const Color background = Color(0xFFFAF9F5); // Warm Paper
  static const Color surface = Color(0xFFFAF9F5);
  static const Color surfaceContainerLow = Color(0xFFF4F4F0);
  static const Color surfaceContainer = Color(0xFFEFEEEA);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E4);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0EEE6);

  // Text & Typography
  static const Color woodBrown = Color(0xFF582F0E); // Heritage Headings
  static const Color deepInk = Color(0xFF0D1B2A); // High contrast body text
  static const Color textPrimary = Color(0xFF0D1B2A);
  static const Color textSecondary = Color(0xFF414844);
  static const Color textMuted = Color(0xFF717973);

  // Borders & Outlines
  static const Color borderLowContrast = Color(0xFFE2E0D6);
  static const Color outlineVariant = Color(0xFFC1C8C2);
  static const Color outline = Color(0xFF717973);

  // Crowd Pressure Tokens
  static const Color crowdQuiet = Color(0xFF3F6653);
  static const Color crowdQuietBg = Color(0xFFE2F0E8);
  static const Color crowdModerate = Color(0xFF7D5800);
  static const Color crowdModerateBg = Color(0xFFFFF3D6);
  static const Color crowdBusy = Color(0xFFE67E22);
  static const Color crowdBusyBg = Color(0xFFFFECE0);
  static const Color crowdUnknown = Color(0xFF717973);
  static const Color crowdUnknownBg = Color(0xFFE9E8E4);

  // Trust & Provenance Tokens
  static const Color lguVerified = Color(0xFF1B4965);
  static const Color lguVerifiedBg = Color(0xFFE0F2FE);
  static const Color editorial = Color(0xFF3F6653);
  static const Color editorialBg = Color(0xFFE2F0E8);
  static const Color openData = Color(0xFF582F0E);
  static const Color openDataBg = Color(0xFFF7EBE1);

  // Status & Feedback
  static const Color success = Color(0xFF2D6A4F);
  static const Color successBg = Color(0xFFD8F3DC);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFBA1A1A);
  static const Color dangerBg = Color(0xFFFFDAD6);
  static const Color info = Color(0xFF1B4965);
  static const Color infoBg = Color(0xFFE0F2FE);
}
