import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/dev/test_content.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';

UserModel _user(String seedId) => UserModel(
      id: 'a9ff511e-e63c-4000-8000-000000000000',
      seedId: seedId,
      email: 'x@juanderquest.app',
      displayName: 'KZO',
      avatarUrl: '',
      role: 'explorer',
      demoPoints: 0,
    );

void main() {
  test('publicHandle hides auto-generated ids and never doubles the @', () {
    expect(_user('usr-a9ff511e-e63').publicHandle, isNull);
    expect(_user('USR-A9FF511E-E63').publicHandle, isNull);
    expect(_user('').publicHandle, isNull);
    expect(_user('kaizero').publicHandle, '@kaizero');
    expect(_user('@kaizero').publicHandle, '@kaizero');
  });

  test('withoutTestContent hides test items unless the switch is on', () {
    final items = [('real', false), ('sim', true)];
    expect(
      withoutTestContent(items, (i) => i.$2, showTest: false).map((i) => i.$1),
      ['real'],
    );
    expect(withoutTestContent(items, (i) => i.$2, showTest: true).length, 2);
  });
}
