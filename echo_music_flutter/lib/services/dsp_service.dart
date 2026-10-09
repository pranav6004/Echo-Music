import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../data/settings.dart';

class EqualizerPreset {
  final String name;
  final List<double> bands; // 10 values: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k
  final double preamp;

  const EqualizerPreset({
    required this.name,
    required this.bands,
    this.preamp = 0.0,
  });
}

class DspService extends ChangeNotifier {
  DspService._();
  static final instance = DspService._();

  Player? _player;

  static const bandFrequencies = [
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
  ];

  static const presets = <EqualizerPreset>[
    EqualizerPreset(
      name: 'Flat',
      bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: 0.0,
    ),
    EqualizerPreset(
      name: 'Bass Boost',
      bands: [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
      preamp: -1.0,
    ),
    EqualizerPreset(
      name: 'Rock',
      bands: [4.5, 3.0, -1.0, -2.5, -1.0, 1.5, 3.5, 5.0, 5.5, 6.0],
      preamp: -1.5,
    ),
    EqualizerPreset(
      name: 'Pop',
      bands: [-1.5, 1.0, 3.0, 4.5, 3.5, 0.5, -1.0, -1.5, 2.0, 3.0],
      preamp: -1.0,
    ),
    EqualizerPreset(
      name: 'Electronic',
      bands: [5.5, 4.5, 2.0, 0.0, -2.0, 2.0, 1.5, 3.0, 4.5, 5.0],
      preamp: -1.5,
    ),
    EqualizerPreset(
      name: 'Hip-Hop',
      bands: [6.0, 5.0, 3.0, 1.0, -1.0, -1.0, 1.0, 2.0, 3.5, 4.0],
      preamp: -1.5,
    ),
    EqualizerPreset(
      name: 'Vocal',
      bands: [-3.0, -2.0, 0.0, 3.0, 4.5, 4.0, 3.0, 1.0, -1.0, -2.0],
      preamp: 0.0,
    ),
    EqualizerPreset(
      name: 'Acoustic',
      bands: [3.5, 2.5, 1.0, 1.5, 2.5, 2.0, 3.0, 3.5, 3.0, 2.0],
      preamp: -0.5,
    ),
    EqualizerPreset(
      name: 'Classical',
      bands: [4.0, 3.0, 2.0, 1.5, -1.0, -1.0, 0.0, 2.0, 3.0, 3.5],
      preamp: -0.5,
    ),
    EqualizerPreset(
      name: 'Jazz',
      bands: [3.0, 2.0, 1.0, 1.5, -1.5, -1.5, 0.0, 1.5, 2.5, 3.0],
      preamp: -0.5,
    ),
  ];

  void registerPlayer(Player player) {
    _player = player;
    applyFilters();
  }

  Future<void> applyFilters() async {
    final player = _player;
    if (player == null) return;
    final s = Settings.instance;

    final filters = <String>[];

    // 1. Preamp & Equalizer (10 ISO Bands biquad peaking)
    if (s.enableEqualizer) {
      if (s.equalizerPreamp != 0.0) {
        final p = s.equalizerPreamp > 0
            ? '+${s.equalizerPreamp.toStringAsFixed(1)}'
            : s.equalizerPreamp.toStringAsFixed(1);
        filters.add('lavfi=[volume=volume=${p}dB]');
      }
      const freqs = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
      final bands = s.equalizerBands;
      for (var i = 0; i < 10 && i < bands.length; i++) {
        final gain = bands[i];
        if (gain.abs() > 0.05) {
          filters.add('lavfi=[equalizer=f=${freqs[i]}:width_type=o:width=1.0:g=${gain.toStringAsFixed(1)}]');
        }
      }
    }

    // 2. Bass Boost (lowshelf filter)
    if (s.enableBassBoost && s.bassBoostGain > 0) {
      filters.add('lavfi=[bass=g=${s.bassBoostGain.toStringAsFixed(1)}:f=100]');
    }

    // 3. Spatial Audio / Stereo Widener (Mid-Side widening via stereotools)
    if (s.enableSpatialAudio && s.spatialAudioWidth > 1.0) {
      filters.add('lavfi=[stereotools=slev=${s.spatialAudioWidth.toStringAsFixed(2)}]');
    }

    final afString = filters.join(',');
    try {
      if (player.platform is NativePlayer) {
        await (player.platform as NativePlayer).setProperty('af', afString);
      }
    } catch (e) {
      debugPrint('DSP filter error: $e');
      if (player.platform is NativePlayer) {
        try {
          await (player.platform as NativePlayer).setProperty('af', '');
        } catch (_) {}
      }
    }
  }

  Future<void> setWasapiExclusive(bool enabled) async {
    final s = Settings.instance;
    s.wasapiExclusive = enabled;
    if (_player?.platform is NativePlayer && Platform.isWindows) {
      final np = _player!.platform as NativePlayer;
      try {
        await np.setProperty('ao', 'wasapi');
        await np.setProperty('audio-exclusive', enabled ? 'yes' : 'no');
      } catch (e) {
        debugPrint('WASAPI exclusive toggle failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    final s = Settings.instance;
    s.enableEqualizer = enabled;
    await applyFilters();
    notifyListeners();
  }

  Future<void> setPreamp(double preamp) async {
    final s = Settings.instance;
    s.equalizerPreamp = preamp;
    await applyFilters();
    notifyListeners();
  }

  Future<void> setBand(int index, double gain) async {
    final s = Settings.instance;
    final bands = List<double>.from(s.equalizerBands);
    if (index >= 0 && index < bands.length) {
      bands[index] = gain;
      s.equalizerBands = bands;
      s.equalizerPreset = 'Custom';
      await applyFilters();
      notifyListeners();
    }
  }

  Future<void> applyPreset(EqualizerPreset preset) async {
    final s = Settings.instance;
    s.equalizerPreset = preset.name;
    s.equalizerBands = List.from(preset.bands);
    s.equalizerPreamp = preset.preamp;
    await applyFilters();
    notifyListeners();
  }

  Future<void> resetToFlat() async {
    final flat = presets.firstWhere((p) => p.name == 'Flat');
    await applyPreset(flat);
  }

  Future<void> setSpatialAudioEnabled(bool enabled) async {
    final s = Settings.instance;
    s.enableSpatialAudio = enabled;
    await applyFilters();
    notifyListeners();
  }

  Future<void> setSpatialAudioWidth(double width) async {
    final s = Settings.instance;
    s.spatialAudioWidth = width;
    await applyFilters();
    notifyListeners();
  }

  Future<void> setBassBoostEnabled(bool enabled) async {
    final s = Settings.instance;
    s.enableBassBoost = enabled;
    await applyFilters();
    notifyListeners();
  }

  Future<void> setBassBoostGain(double gain) async {
    final s = Settings.instance;
    s.bassBoostGain = gain;
    await applyFilters();
    notifyListeners();
  }
}
