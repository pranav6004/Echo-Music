import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

class AmbientGlowBackground extends StatefulWidget {
  final String? imageUrl;
  final Widget child;
  final double opacity;
  final double blurRadius;

  const AmbientGlowBackground({
    super.key,
    required this.imageUrl,
    required this.child,
    this.opacity = 0.28,
    this.blurRadius = 60.0,
  });

  @override
  State<AmbientGlowBackground> createState() => _AmbientGlowBackgroundState();
}

class _AmbientGlowBackgroundState extends State<AmbientGlowBackground>
    with SingleTickerProviderStateMixin {
  static final Map<String, List<Color>> _paletteCache = {};

  List<Color> _colors = const [
    Color(0xFF1E1B4B), // Deep indigo
    Color(0xFF311042), // Deep purple
  ];

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _extractPalette();
  }

  @override
  void didUpdateWidget(covariant AmbientGlowBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _extractPalette();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _extractPalette() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        setState(() {
          _colors = [
            Theme.of(context).colorScheme.primary.withOpacity(0.2),
            Theme.of(context).colorScheme.tertiary.withOpacity(0.15),
          ];
        });
      }
      return;
    }

    if (_paletteCache.containsKey(url)) {
      if (mounted) {
        setState(() {
          _colors = _paletteCache[url]!;
        });
      }
      return;
    }

    try {
      final imageProvider = CachedNetworkImageProvider(url);
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 8,
      );

      final c1 = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          const Color(0xFF1E1B4B);
      final c2 = palette.vibrantColor?.color ??
          palette.mutedColor?.color ??
          palette.lightVibrantColor?.color ??
          const Color(0xFF311042);

      final extracted = [c1, c2];
      _paletteCache[url] = extracted;

      if (mounted) {
        setState(() {
          _colors = extracted;
        });
      }
    } catch (_) {
      // Keep default smooth glow on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final t = _pulseController.value;
              return Stack(
                children: [
                  // Primary dynamic radial glow
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    top: -100 + (t * 40),
                    left: -80 + (t * 50),
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _colors[0].withOpacity(widget.opacity),
                            _colors[0].withOpacity(widget.opacity * 0.3),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Secondary dynamic radial glow
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    bottom: -120 + ((1 - t) * 60),
                    right: -100 + ((1 - t) * 40),
                    width: MediaQuery.of(context).size.width * 0.65,
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _colors[1].withOpacity(widget.opacity * 0.8),
                            _colors[1].withOpacity(widget.opacity * 0.25),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        widget.child,
      ],
    );
  }
}
