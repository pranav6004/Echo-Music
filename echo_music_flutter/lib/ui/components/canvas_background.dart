import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/canvas_service.dart';
import 'ambient_glow_background.dart';

class CanvasBackground extends StatelessWidget {
  final String? fallbackArtworkUrl;
  final Widget child;
  final double opacity;

  const CanvasBackground({
    super.key,
    required this.fallbackArtworkUrl,
    required this.child,
    this.opacity = 0.35,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CanvasService.instance,
      builder: (context, _) {
        final canvasUrl = CanvasService.instance.currentUrl;

        return Stack(
          children: [
            // Ambient glow base layer
            Positioned.fill(
              child: AmbientGlowBackground(
                imageUrl: fallbackArtworkUrl,
                opacity: opacity * 0.8,
                child: const SizedBox.expand(),
              ),
            ),

            // Canvas animated layer if active
            if (canvasUrl != null && !canvasUrl.endsWith('.mp4'))
              Positioned.fill(
                child: Opacity(
                  opacity: opacity,
                  child: CachedNetworkImage(
                    imageUrl: canvasUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // Dark gradient overlay for readability
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.75),
                      Colors.black.withOpacity(0.92),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),

            child,
          ],
        );
      },
    );
  }
}
