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

    // 1. Preamp & Equalizer
    if (s.enableEqualizer) {
      if (s.equalizerPreamp != 0.0) {
        final p = s.equalizerPreamp > 0
            ? '+${s.equalizerPreamp.toStringAsFixed(1)}'
            : s.equalizerPreamp.toStringAsFixed(1);
        filters.add('volume=volume=${p}dB');
      }
      final bands = s.equalizerBands;
      final gains = bands.map((b) => b.toStringAsFixed(1)).join(':');
      filters.add('equalizer=$gains');
    }

    // 2. Bass Boost
    if (s.enableBassBoost && s.bassBoostGain > 0) {
      filters.add('bass=g=${s.bassBoostGain.toStringAsFixed(1)}:f=100');
    }

    // 3. Spatial Audio / Stereo Widener (Mid-Side Widening)
    if (s.enableSpatialAudio && s.spatialAudioWidth > 1.0) {
      filters.add('extrastereo=m=${s.spatialAudioWidth.toStringAsFixed(2)}');
    }

    final afString = filters.join(',');
    try {
      if (player.platform is NativePlayer) {
        await (player.platform as NativePlayer).setProperty('af', afString);
      }
    } catch (e) {
      debugPrint('DSP filter error: $e');
    }
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
