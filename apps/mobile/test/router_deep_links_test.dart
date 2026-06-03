import 'package:flutter_test/flutter_test.dart';
import 'package:unrecorded_mobile/router.dart';

void main() {
  test('playPreLaunchDeepLinks use custom scheme and host', () {
    expect(playPreLaunchDeepLinks, hasLength(3));
    for (final uri in playPreLaunchDeepLinks) {
      expect(uri, startsWith('$deepLinkScheme://$deepLinkHost/'));
    }
  });

  test('playPreLaunchDeepLinks match GoRouter paths', () {
    expect(playPreLaunchDeepLinks, [
      'unrecorded://open/help',
      'unrecorded://open/alert-info',
      'unrecorded://open/settings',
    ]);
    expect(playPreLaunchDeepLinks.map((u) => Uri.parse(u).path), [
      '/help',
      '/alert-info',
      '/settings',
    ]);
  });
}
