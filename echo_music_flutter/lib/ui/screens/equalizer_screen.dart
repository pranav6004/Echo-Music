import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../services/dsp_service.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final _dsp = DspService.instance;

  @override
  void initState() {
    super.initState();
    _dsp.addListener(_onDspChanged);
  }

  @override
  void dispose() {
    _dsp.removeListener(_onDspChanged);
    super.dispose();
  }

  void _onDspChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = Settings.instance;

    final bands = s.equalizerBands;
    final enabled = s.enableEqualizer;
    final preamp = s.equalizerPreamp;
    final currentPreset = s.equalizerPreset;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer & Audio DSP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to Flat',
            onPressed: enabled ? () => _dsp.resetToFlat() : null,
          ),
          const SizedBox(width: 8),
          Switch(
            value: enabled,
            onChanged: (val) => _dsp.setEqualizerEnabled(val),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // 1. Interactive EQ Response Curve
          Card(
            clipBehavior: Clip.antiAlias,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: enabled
                    ? scheme.primary.withValues(alpha: 0.25)
                    : scheme.outlineVariant.withValues(alpha: 0.1),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'FREQUENCY RESPONSE',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        enabled ? currentPreset : 'Equalizer Bypassed',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _EqCurvePainter(
                        bands: bands,
                        enabled: enabled,
                        primaryColor: scheme.primary,
                        gridColor: scheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Preset Selection Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: DspService.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final preset = DspService.presets[idx];
                final isSelected = currentPreset == preset.name && enabled;
                return ChoiceChip(
                  label: Text(preset.name),
                  selected: isSelected,
                  onSelected: enabled
                      ? (_) => _dsp.applyPreset(preset)
                      : null,
                  selectedColor: scheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // 3. Graphic Equalizer Sliders (Preamp + 10 Bands)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '10-BAND GRAPHIC EQUALIZER',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 240,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Preamp Slider
                        _EqSlider(
                          label: 'Preamp',
                          value: preamp,
                          min: -10.0,
                          max: 10.0,
                          enabled: enabled,
                          accentColor: Colors.amber,
                          onChanged: (val) => _dsp.setPreamp(val),
                        ),
                        VerticalDivider(
                          width: 20,
                          thickness: 1,
                          color: scheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                        // 10 Frequency Bands
                        for (int i = 0; i < 10; i++)
                          _EqSlider(
                            label: DspService.bandFrequencies[i],
                            value: bands[i],
                            min: -12.0,
                            max: 12.0,
                            enabled: enabled,
                            accentColor: scheme.primary,
                            onChanged: (val) => _dsp.setBand(i, val),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Acoustic Enhancements (Bass Boost & Spatial Audio)
          Text(
            'ACOUSTIC ENHANCEMENTS',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Bass Boost
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.speaker_rounded, color: Colors.deepOrange),
                    ),
                    title: const Text('Bass Boost Enhancer'),
                    subtitle: const Text('Sub-bass harmonic resonance filter (100 Hz cutoff)'),
                    value: s.enableBassBoost,
                    onChanged: (v) => _dsp.setBassBoostEnabled(v),
                  ),
                  if (s.enableBassBoost) ...[
                    Row(
                      children: [
                        const Text('Gain: '),
                        Text(
                          '+${s.bassBoostGain.toStringAsFixed(1)} dB',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: s.bassBoostGain,
                            min: 0.0,
                            max: 12.0,
                            divisions: 24,
                            label: '+${s.bassBoostGain.toStringAsFixed(1)} dB',
                            onChanged: (v) => _dsp.setBassBoostGain(v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Spatial Audio & Stereo Widener
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.surround_sound_rounded, color: Colors.indigo),
                    ),
                    title: const Text('Spatial Audio (Stereo Widener)'),
                    subtitle: const Text('Mid-Side phase widening for expansive soundstage'),
                    value: s.enableSpatialAudio,
                    onChanged: (v) => _dsp.setSpatialAudioEnabled(v),
                  ),
                  if (s.enableSpatialAudio) ...[
                    Row(
                      children: [
                        const Text('Width: '),
                        Text(
                          '${((s.spatialAudioWidth - 1.0) * 100).toInt()}% widened',
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: s.spatialAudioWidth,
                            min: 1.0,
                            max: 2.0,
                            divisions: 20,
                            label: '${((s.spatialAudioWidth - 1.0) * 100).toInt()}%',
                            onChanged: (v) => _dsp.setSpatialAudioWidth(v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _EqSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final Color accentColor;
  final ValueChanged<double> onChanged;

  const _EqSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isZero = value.abs() < 0.1;
    final valStr = isZero
        ? '0.0'
        : value > 0
            ? '+${value.toStringAsFixed(1)}'
            : value.toStringAsFixed(1);

    return Column(
      children: [
        // Value text
        Text(
          valStr,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: isZero ? FontWeight.normal : FontWeight.bold,
            color: enabled
                ? (isZero ? theme.colorScheme.onSurfaceVariant : accentColor)
                : theme.disabledColor,
          ),
        ),
        const SizedBox(height: 4),
        // Vertical Slider
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: enabled ? accentColor : theme.disabledColor,
                inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                thumbColor: enabled ? accentColor : theme.disabledColor,
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Frequency label
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  final List<double> bands;
  final bool enabled;
  final Color primaryColor;
  final Color gridColor;

  _EqCurvePainter({
    required this.bands,
    required this.enabled,
    required this.primaryColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2.0;

    // Draw Grid Lines (+12, 0, -12)
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, 0), Offset(w, 0), gridPaint);
    canvas.drawLine(Offset(0, midY), Offset(w, midY), gridPaint);
    canvas.drawLine(Offset(0, h), Offset(w, h), gridPaint);

    if (bands.isEmpty) return;

    final points = <Offset>[];
    final stepX = w / (bands.length - 1);

    for (int i = 0; i < bands.length; i++) {
      final x = i * stepX;
      // map gain (-12 to +12) to y (h to 0)
      final gain = enabled ? bands[i] : 0.0;
      final y = midY - (gain / 12.0) * (midY - 4);
      points.add(Offset(x, y));
    }

    // Build smooth curve path
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final cx = (p0.dx + p1.dx) / 2.0;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    // Fill underneath the curve with gradient
    final fillPath = Path.from(path)
      ..lineTo(w, midY)
      ..lineTo(0, midY)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: enabled ? 0.25 : 0.05),
          primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(fillPath, fillPaint);

    // Draw curve line
    final linePaint = Paint()
      ..color = enabled ? primaryColor : primaryColor.withValues(alpha: 0.3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, linePaint);

    // Draw node dots
    final dotPaint = Paint()..color = enabled ? primaryColor : primaryColor.withValues(alpha: 0.3);
    for (final p in points) {
      canvas.drawCircle(p, 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    return oldDelegate.bands != bands ||
        oldDelegate.enabled != enabled ||
        oldDelegate.primaryColor != primaryColor;
  }
}
