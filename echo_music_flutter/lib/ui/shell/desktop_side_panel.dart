import 'package:flutter/material.dart';

import '../../playback/media_metadata.dart';
import '../../playback/player_controller.dart';
import '../player/lyrics_view.dart';
import '../player/queue_sheet.dart';

enum DesktopPanelType { lyrics, queue }

/// Collapsible desktop side panel docked to the right of the content area.
/// Allows viewing live synced lyrics or managing the playback queue side-by-side
/// with browsing without modal takeover (Spotify / Apple Music paradigm).
class DesktopSidePanel extends StatelessWidget {
  final DesktopPanelType type;
  final VoidCallback onClose;

  const DesktopSidePanel({
    super.key,
    required this.type,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLyrics = type == DesktopPanelType.lyrics;

    final screenW = MediaQuery.sizeOf(context).width;
    final panelWidth = (screenW * 0.28).clamp(280.0, 360.0);

    return Container(
      width: panelWidth,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          left: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Icon(
                  isLyrics ? Icons.lyrics_rounded : Icons.queue_music_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLyrics ? 'Lyrics' : 'Playing Queue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close panel',
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          Divider(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
            height: 1,
          ),

          // Content Area
          Expanded(
            child: isLyrics
                ? ValueListenableBuilder<MediaMetadata?>(
                    valueListenable: player.handler.currentMetadata,
                    builder: (context, meta, _) {
                      if (meta == null) {
                        return Center(
                          child: Text(
                            'No song playing',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }
                      return LyricsView(
                        key: ValueKey('lyrics-${meta.id}'),
                        meta: meta,
                        textColor: scheme.onSurface,
                      );
                    },
                  )
                : const QueueBody(),
          ),
        ],
      ),
    );
  }
}
