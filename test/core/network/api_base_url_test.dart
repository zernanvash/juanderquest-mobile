import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_base_url.dart';

void main() {
  test('release builds default to the production API', () {
    expect(defaultApiBaseUrl(defined: '', release: true), productionApiBaseUrl);
  });

  test('debug and profile builds never default to production', () {
    expect(defaultApiBaseUrl(defined: '', release: false), localApiBaseUrl);
    expect(localApiBaseUrl, isNot(contains('juanderquest.app')));
  });

  test('an explicit dart-define wins in every build', () {
    const slot = 'http://127.0.0.1:4110/api/v1';
    expect(defaultApiBaseUrl(defined: slot, release: false), slot);
    expect(defaultApiBaseUrl(defined: slot, release: true), slot);
  });
}
