import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/app/auth_redirect.dart';

void main(){
  test('JuanChoice campaign remains publicly deep-linkable',(){
    expect(resolveAuthRedirect(loggedIn:false,matchedLocation:'/choice/campaign-id',
      uri:Uri.parse('/choice/campaign-id')),isNull);
  });
  test('protected quest deep link survives authentication',(){
    final redirect=resolveAuthRedirect(loggedIn:false,matchedLocation:'/quests/quest-id',
      uri:Uri.parse('/quests/quest-id'));
    expect(redirect,'/?redirect=%2Fquests%2Fquest-id');
    expect(resolveAuthRedirect(loggedIn:true,matchedLocation:'/',uri:Uri.parse(redirect!)),
      '/quests/quest-id');
  });
  test('external and scheme-relative redirects fail closed',(){
    expect(resolveAuthRedirect(loggedIn:true,matchedLocation:'/',
      uri:Uri.parse('/?redirect=https%3A%2F%2Fevil.test')),'/explore');
    expect(resolveAuthRedirect(loggedIn:true,matchedLocation:'/',
      uri:Uri.parse('/?redirect=%2F%2Fevil.test')),'/explore');
  });
}
