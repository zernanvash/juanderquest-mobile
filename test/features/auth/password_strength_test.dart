import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/pixel_input.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/utils/password_strength.dart';

// Owner 2026-11-06: "add a strong password checking system" and "the password
// is auto capslock" (Silkscreen has no real lowercase).
void main() {
  group('PasswordCheck', () {
    test('a long mixed password passes every rule', () {
      final check = PasswordCheck.of('Tr4vel-Bolinao!');
      expect(check.isStrongEnough, isTrue);
      expect(check.strength, PasswordStrength.strong);
    });

    test('10+ characters with all kinds is good, 14+ is strong', () {
      expect(PasswordCheck.of('Sunset#2026').strength, PasswordStrength.good);
      expect(PasswordCheck.of('Sunset#2026-Hundred').strength, PasswordStrength.strong);
    });

    test('each missing kind fails', () {
      for (final pw in ['short1!A', 'nouppercase1!', 'NOLOWERCASE1!', 'NoNumbersHere!', 'NoSymbols12345']) {
        expect(PasswordCheck.of(pw).isStrongEnough, isFalse, reason: pw);
      }
    });

    test('common words, the name, the email and repeats are refused', () {
      expect(PasswordCheck.of('Password123!!').isStrongEnough, isFalse);
      expect(PasswordCheck.of('JuanderQuest#1').isStrongEnough, isFalse);
      expect(PasswordCheck.of('Cruz#2026xyz', name: 'Juan Dela Cruz').isStrongEnough, isFalse);
      expect(PasswordCheck.of('Mariaz#2026x', email: 'mariaz@example.com').isStrongEnough, isFalse);
      expect(PasswordCheck.of('Zaaaa#2026xy').isStrongEnough, isFalse);
    });

    test('empty and weak strengths', () {
      expect(PasswordCheck.of('').strength, PasswordStrength.empty);
      expect(PasswordCheck.of('abc').strength, PasswordStrength.weak);
      expect(PasswordCheck.of('securepass123').strength, PasswordStrength.fair);
    });
  });

  testWidgets('plainFont fields type in the normal font, not Silkscreen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: const Scaffold(
        body: Column(children: [
          PixelTextField(key: ValueKey('plain'), plainFont: true),
          PixelTextField(key: ValueKey('pixel')),
        ]),
      ),
    ));
    TextStyle styleOf(String key) => tester
        .widget<TextField>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextField)))
        .style!;
    expect(styleOf('plain').fontFamily, 'Roboto');
    expect(styleOf('pixel').fontFamily, isNot('Roboto'));
  });
}
