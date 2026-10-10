import 'package:echo_music/innertube/youtube_client.dart';
import 'package:echo_music/ui/screens/charts_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YouTubeLocale & InnerTube Client Context', () {
    test('constructs valid YouTubeLocale', () {
      const loc = YouTubeLocale(gl: 'US', hl: 'en');
      expect(loc.gl, equals('US'));
      expect(loc.hl, equals('en'));
    });

    test('toContext includes gl, hl, and client metadata', () {
      const client = YouTubeClient.webRemix;
      const loc = YouTubeLocale(gl: 'IN', hl: 'hi');
      final ctx = client.toContext(loc, 'vis_123', null);

      expect(ctx, isNotNull);
      final clientMap = ctx['client'] as Map<String, dynamic>;
      expect(clientMap['gl'], equals('IN'));
      expect(clientMap['hl'], equals('hi'));
      expect(clientMap['clientName'], equals('WEB_REMIX'));
      expect(clientMap['visitorData'], equals('vis_123'));
    });
  });

  group('Charts Country Selection & Resolution', () {
    test('countryOptions contains Global and major regional markets', () {
      final opts = ChartsScreen.countryOptions;
      expect(opts.containsKey('GLOBAL'), isTrue);
      expect(opts.containsKey('US'), isTrue);
      expect(opts.containsKey('IN'), isTrue);
      expect(opts.containsKey('GB'), isTrue);
      expect(opts.containsKey('JP'), isTrue);
      expect(opts.containsKey('KR'), isTrue);
      expect(opts.containsKey('DE'), isTrue);
    });

    test('country code resolution resolves GLOBAL to US for worldwide charts', () {
      String resolveGl(String? country, String fallbackGl) {
        if (country == null || country == 'GLOBAL' || country == 'system') {
          return country == 'GLOBAL' ? 'US' : fallbackGl;
        }
        return country;
      }

      expect(resolveGl('GLOBAL', 'IN'), equals('US'));
      expect(resolveGl('system', 'IN'), equals('IN'));
      expect(resolveGl('GB', 'IN'), equals('GB'));
      expect(resolveGl('JP', 'IN'), equals('JP'));
      expect(resolveGl(null, 'IN'), equals('IN'));
    });
  });
}
