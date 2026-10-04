import 'package:flutter_test/flutter_test.dart';

Uri normalizeRecoveryUrl(String rawUrl) {
  if (rawUrl.contains('access_token=')) {
    final tokenIndex = rawUrl.indexOf('access_token=');
    final firstHashIndex = rawUrl.indexOf('#');
    if (firstHashIndex != -1 && tokenIndex > firstHashIndex) {
      final origin = Uri.parse(rawUrl).origin;
      final fragment = rawUrl.substring(tokenIndex);
      return Uri.parse('$origin/#$fragment');
    }
  } else if (rawUrl.contains('code=')) {
    final codeIndex = rawUrl.indexOf('code=');
    final origin = Uri.parse(rawUrl).origin;
    final queryOrFragment = rawUrl.substring(codeIndex);
    return Uri.parse('$origin/?$queryOrFragment');
  }
  return Uri.parse(rawUrl);
}

void main() {
  group('Password Recovery URL Normalization Tests', () {
    test('Standard single-hash recovery URL is preserved', () {
      const url = 'http://localhost:50091/#access_token=test_access_token&refresh_token=test_refresh&type=recovery&expires_in=3600';
      final uri = normalizeRecoveryUrl(url);
      final params = Uri.splitQueryString(uri.fragment);

      expect(params.containsKey('access_token'), isTrue);
      expect(params['access_token'], equals('test_access_token'));
      expect(params['type'], equals('recovery'));
    });

    test('Double-hash recovery URL from /#/update-password redirect is normalized correctly', () {
      const doubleHashUrl = 'http://localhost:50091/#/update-password#access_token=my_secret_token&refresh_token=my_refresh_token&type=recovery&expires_at=1700000000';
      
      final normalized = normalizeRecoveryUrl(doubleHashUrl);
      expect(normalized.toString(), startsWith('http://localhost:50091/#access_token='));
      final params = Uri.splitQueryString(normalized.fragment);
      expect(params.containsKey('access_token'), isTrue);
      expect(params['access_token'], equals('my_secret_token'));
      expect(params['type'], equals('recovery'));
    });

    test('PKCE code URL format is normalized correctly', () {
      const pkceUrl = 'http://localhost:50091/#/update-password?code=3b29ac5b-4395-46b2-a429';
      
      final normalized = normalizeRecoveryUrl(pkceUrl);
      expect(normalized.queryParameters.containsKey('code'), isTrue);
      expect(normalized.queryParameters['code'], equals('3b29ac5b-4395-46b2-a429'));
    });
  });
}
