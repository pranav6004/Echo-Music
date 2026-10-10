import 'package:echo_music/services/dsp_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DspService Presets & Configuration', () {
    test('contains 10 standard presets', () {
      expect(DspService.presets.length, equals(10));
      final names = DspService.presets.map((p) => p.name).toList();
      expect(names, containsAll([
        'Flat',
        'Bass Boost',
        'Rock',
        'Pop',
        'Electronic',
        'Hip-Hop',
        'Vocal',
        'Acoustic',
        'Classical',
        'Jazz',
      ]));
    });

    test('each preset defines exactly 10 ISO octave frequency bands', () {
      for (final preset in DspService.presets) {
        expect(preset.bands.length, equals(10), reason: '${preset.name} must have 10 bands');
      }
    });

    test('frequency labels match ISO standards', () {
      expect(DspService.bandFrequencies, equals([
        '31 Hz',
        '62 Hz',
        '125 Hz',
        '250 Hz',
        '500 Hz',
        '1 kHz',
        '2 kHz',
        '4 kHz',
        '8 kHz',
        '16 kHz',
      ]));
    });

    test('preamp values are within safe acoustic range (-12 dB to +12 dB)', () {
      for (final preset in DspService.presets) {
        expect(preset.preamp, greaterThanOrEqualTo(-12.0));
        expect(preset.preamp, lessThanOrEqualTo(12.0));
      }
    });

    test('flat preset has 0.0 gain on all bands', () {
      final flat = DspService.presets.firstWhere((p) => p.name == 'Flat');
      expect(flat.bands, everyElement(equals(0.0)));
      expect(flat.preamp, equals(0.0));
    });

    test('bass boost preset provides low-frequency emphasis', () {
      final bb = DspService.presets.firstWhere((p) => p.name == 'Bass Boost');
      expect(bb.bands[0], greaterThan(4.0));
      expect(bb.bands[1], greaterThan(3.0));
      expect(bb.preamp, lessThan(0.0));
    });
  });

  group('Filter String Assembly Simulation', () {
    test('assembles unified lavfi graph with stereo layout negotiation', () {
      final subFilters = <String>[];
      subFilters.add('volume=volume=-1.0dB');
      subFilters.add('equalizer=f=31:width_type=o:width=1.0:g=6.0');
      subFilters.add('bass=g=5.0:f=100');
      subFilters.add('aformat=channel_layouts=stereo');
      subFilters.add('stereotools=slev=1.50');

      final afString = subFilters.isEmpty ? '' : 'lavfi=[${subFilters.join(',')}]';

      expect(afString, startsWith('lavfi=['));
      expect(afString, endsWith(']'));
      expect(afString, contains('aformat=channel_layouts=stereo'));
      expect(afString, contains('stereotools=slev=1.50'));
      expect(afString, contains('bass=g=5.0:f=100'));
      expect(afString, contains('volume=volume=-1.0dB'));
    });

    test('empty subfilters yield empty string to clear mpv audio filter chain', () {
      final subFilters = <String>[];
      final afString = subFilters.isEmpty ? '' : 'lavfi=[${subFilters.join(',')}]';
      expect(afString, equals(''));
    });
  });
}
