/// Strong-password rules for new passwords (sign-up and password reset; owner
/// 2026-11-06: "add a strong password checking system").
///
/// A new password must pass every rule. Existing passwords are never checked
/// here (signing in, or linking a wallet to an existing account), so older
/// accounts still get in.
library;

enum PasswordStrength { empty, weak, fair, good, strong }

class PasswordRule {
  const PasswordRule(this.label, this.passed);
  final String label;
  final bool passed;
}

/// Passwords people pick first. Matched case-insensitively, also inside the
/// password ("Password123!" fails).
const _common = <String>[
  'password',
  'passw0rd',
  'qwerty',
  'abc123',
  '123456',
  '12345678',
  '11111111',
  'iloveyou',
  'admin',
  'welcome',
  'letmein',
  'juanderquest',
  'pangasinan',
];

class PasswordCheck {
  PasswordCheck._(this.rules, this.strength);

  final List<PasswordRule> rules;
  final PasswordStrength strength;

  bool get isStrongEnough => rules.every((rule) => rule.passed);

  /// [email] and [name] are used to reject passwords built from them.
  factory PasswordCheck.of(String password, {String email = '', String name = ''}) {
    final lower = password.toLowerCase();
    final personal = <String>{
      ...email.split('@').first.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
      ...name.toLowerCase().split(RegExp(r'\s+')),
    }.where((part) => part.length >= 3);

    final rules = <PasswordRule>[
      PasswordRule('At least 10 characters', password.length >= 10),
      PasswordRule('An uppercase letter (A-Z)', RegExp(r'[A-Z]').hasMatch(password)),
      PasswordRule('A lowercase letter (a-z)', RegExp(r'[a-z]').hasMatch(password)),
      PasswordRule('A number (0-9)', RegExp(r'[0-9]').hasMatch(password)),
      PasswordRule('A symbol (! @ # ? …)', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
      PasswordRule(
        'Not a common word, your name or email',
        password.isNotEmpty &&
            !_common.any(lower.contains) &&
            !personal.any(lower.contains) &&
            !RegExp(r'(.)\1\1\1').hasMatch(password),
      ),
    ];

    final passed = rules.where((rule) => rule.passed).length;
    final PasswordStrength strength;
    if (password.isEmpty) {
      strength = PasswordStrength.empty;
    } else if (passed == rules.length) {
      strength = password.length >= 14 ? PasswordStrength.strong : PasswordStrength.good;
    } else if (passed >= 4) {
      strength = PasswordStrength.fair;
    } else {
      strength = PasswordStrength.weak;
    }
    return PasswordCheck._(rules, strength);
  }
}
