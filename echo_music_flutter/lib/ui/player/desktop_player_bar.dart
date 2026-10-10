import 'dart:async';
import '../../stream/stream_resolver.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/database.dart';
import '../../playback/media_metadata.dart';
import '../../playback/player_controller.dart';
import '../components/thumbnail.dart';
import '../shell/app_navigator.dart';

/// Full-width docked desktop player bar anchored to Spotify / Apple Music standards:
/// Track metadata & like on left, controls & seek slider in center,
/// volume slider and side-panel triggers on right.
class DesktopPlayerBar extends StatefulWidget {
  final double height;
  final bool isLyricsOpen;
  final bool isQueueOpen;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleQueue;

  const DesktopPlayerBar({
    super.key,
    this.height = 84,
    required this.isLyricsOpen,
    required this.isQueueOpen,
    required this.onToggleLyrics,
    required this.onToggleQueue,
  });

  @override
  State<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends State<DesktopPlayerBar> {
  double? _dragPos;
  double _lastVolume = 1.0;

  @override
  Widget build(BuildContext context) {
    final handler = player.handler;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ValueListenableBuilder<MediaMetadata?>(
        valueListenable: handler.currentMetadata,
        builder: (context, meta, _) {
          if (meta == null) {
            return Center(
              child: Text(
                'No music playing',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            );
          }

          final screenW = MediaQuery.sizeOf(context).width;
          final isCompact = screenW < 1080;
          final leftWidth = isCompact
              ? (screenW * 0.28).clamp(240.0, 320.0)
              : (screenW * 0.26).clamp(340.0, 480.0);
          final rightWidth = isCompact ? 220.0 : 280.0;

          return Row(
            children: [
              // LEFT SECTION: Artwork, Title, Artist, Like
              SizedBox(
                width: leftWidth,
                child: Row(
                  children: [
                    InkWell(
                      onTap: AppNavigator.openPlayer,
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: EchoImage(
                          url: meta.thumbnailUrl,
                          width: 52,
                          height: 52,
                          radius: 8,
                          resize: 128,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: meta.title,
                            waitDuration: const Duration(milliseconds: 500),
                            child: InkWell(
                              onTap: AppNavigator.openPlayer,
                              borderRadius: BorderRadius.circular(4),
                              child: Text(
                                meta.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            onTap: () {
                              final aid = meta.artists.isNotEmpty ? meta.artists.first.id : null;
                              if (aid != null && aid.isNotEmpty) {
                                AppNavigator.openArtist(aid);
                              }
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Text(
                              meta.artistsText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _LikeButton(meta: meta),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<ResolvedStream?>(
                      valueListenable: handler.currentStream,
                      builder: (context, stream, _) {
                        if (stream == null) return const SizedBox.shrink();
                        final isLossless = stream.mimeType.contains('flac');
                        final isOpus = stream.mimeType.contains('opus') || stream.mimeType.contains('webm');
                        final label = isLossless ? 'FLAC' : (isOpus ? 'OPUS' : 'AAC');
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isLossless
                                ? scheme.primary.withValues(alpha: 0.15)
                                : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isLossless
                                  ? scheme.primary.withValues(alpha: 0.4)
                                  : scheme.outlineVariant.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: isLossless ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // CENTER SECTION: Playback controls + Position Slider
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Top Row: Playback Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Shuffle
                          ValueListenableBuilder<bool>(
                            valueListenable: handler.shuffleEnabled,
                            builder: (context, shuffle, _) {
                              return IconButton(
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  size: 20,
                                  color: shuffle
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                                tooltip: shuffle ? 'Shuffle (On)' : 'Shuffle (Off)',
                                onPressed: () {
                                  handler.setShuffleMode(
                                    shuffle
                                        ? AudioServiceShuffleMode.none
                                        : AudioServiceShuffleMode.all,
                                  );
                                },
                              );
                            },
                          ),

                          // Previous
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded, size: 24),
                            tooltip: 'Previous',
                            onPressed: handler.skipToPrevious,
                          ),

                          const SizedBox(width: 4),

                          // Play / Pause Circle
                          StreamBuilder<bool>(
                            stream: handler.player.playingStream,
                            builder: (context, snap) {
                              final playing = snap.data ?? false;
                              return Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.onSurface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.onSurface.withValues(alpha: 0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 24,
                                    color: scheme.surface,
                                  ),
                                  tooltip: playing ? 'Pause' : 'Play',
                                  onPressed: () => playing ? handler.pause() : handler.play(),
                                ),
                              );
                            },
                          ),

                          const SizedBox(width: 4),

                          // Next
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded, size: 24),
                            tooltip: 'Next',
                            onPressed: handler.skipToNext,
                          ),

                          // Repeat
                          ValueListenableBuilder<AudioServiceRepeatMode>(
                            valueListenable: handler.repeatMode,
                            builder: (context, repeat, _) {
                              final isNone = repeat == AudioServiceRepeatMode.none;
                              final isOne = repeat == AudioServiceRepeatMode.one;
                              return IconButton(
                                icon: Icon(
                                  isOne ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                                  size: 20,
                                  color: isNone
                                      ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
                                      : scheme.primary,
                                ),
                                tooltip: isOne
                                    ? 'Repeat One'
                                    : (isNone ? 'Repeat (Off)' : 'Repeat All'),
                                onPressed: () {
                                  final nextMode = isNone
                                      ? AudioServiceRepeatMode.all
                                      : (isOne
                                          ? AudioServiceRepeatMode.none
                                          : AudioServiceRepeatMode.one);
                                  handler.setRepeatMode(nextMode);
                                },
                              );
                            },
                          ),
                        ],
                      ),

                      // Bottom Row: Timestamps + Timeline Scrubber
                      StreamBuilder<Duration>(
                        stream: handler.player.positionStream,
                        builder: (context, snap) {
                          final pos = snap.data ?? Duration.zero;
                          final dur = handler.effectiveDuration.value ??
                              Duration(seconds: meta.duration > 0 ? meta.duration : 1);
                          final durSec = dur.inSeconds > 0 ? dur.inSeconds.toDouble() : 1.0;
                          final currentSec = _dragPos ?? pos.inSeconds.toDouble().clamp(0.0, durSec);

                          return SizedBox(
                            height: 20,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    formatDuration(currentSec.toInt()),
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                        elevation: 2,
                                      ),
                                      overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 10,
                                      ),
                                      activeTrackColor: scheme.primary,
                                      inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.12),
                                      thumbColor: scheme.primary,
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: durSec,
                                      value: currentSec.clamp(0.0, durSec),
                                      onChangeStart: (v) => setState(() => _dragPos = v),
                                      onChanged: (v) => setState(() => _dragPos = v),
                                      onChangeEnd: (v) {
                                        handler.seek(Duration(seconds: v.toInt()));
                                        setState(() => _dragPos = null);
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    formatDuration(durSec.toInt()),
                                    textAlign: TextAlign.left,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // RIGHT SECTION: Lyrics, Queue, Volume, Fullscreen
              SizedBox(
                width: rightWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Lyrics side toggle
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        widget.isLyricsOpen
                            ? Icons.lyrics_rounded
                            : Icons.lyrics_outlined,
                        size: 20,
                        color: widget.isLyricsOpen ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      tooltip: 'Lyrics',
                      onPressed: widget.onToggleLyrics,
                    ),

                    // Equalizer & DSP button
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.tune_rounded,
                        size: 20,
                        color: scheme.onSurfaceVariant,
                      ),
                      tooltip: 'Equalizer & DSP',
                      onPressed: AppNavigator.openEqualizer,
                    ),
                    // Party Rooms button (only on wider screens)
                    if (!isCompact)
                      IconButton(
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.podcasts_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        tooltip: 'Party Rooms',
                        onPressed: AppNavigator.openPartyRooms,
                      ),
                    // Queue side toggle
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        widget.isQueueOpen
                            ? Icons.queue_music_rounded
                            : Icons.queue_music_outlined,
                        size: 20,
                        color: widget.isQueueOpen ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                      tooltip: 'Queue',
                      onPressed: widget.onToggleQueue,
                    ),

                    const SizedBox(width: 4),

                    // Volume cluster
                    StreamBuilder<double>(
                      stream: handler.player.volumeStream,
                      builder: (context, snap) {
                        final vol = snap.data ?? handler.player.volume;
                        final isMuted = vol <= 0.001;
                        final volIcon = isMuted
                            ? Icons.volume_off_rounded
                            : (vol < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded);

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(volIcon, size: 20, color: scheme.onSurfaceVariant),
                              tooltip: isMuted ? 'Unmute' : 'Mute',
                              onPressed: () {
                                if (isMuted) {
                                  handler.setMasterVolume(_lastVolume > 0 ? _lastVolume : 0.8);
                                } else {
                                  _lastVolume = vol;
                                  handler.setMasterVolume(0.0);
                                }
                              },
                            ),
                            SizedBox(
                              width: isCompact ? 60 : 80,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 4,
                                  ),
                                  overlayShape: SliderComponentShape.noOverlay,
                                  activeTrackColor: scheme.primary,
                                  inactiveTrackColor: scheme.onSurface.withValues(alpha: 0.12),
                                  thumbColor: scheme.primary,
                                ),
                                child: Slider(
                                  min: 0.0,
                                  max: 1.0,
                                  value: vol.clamp(0.0, 1.0),
                                  onChanged: (v) {
                                    if (v > 0) _lastVolume = v;
                                    handler.setMasterVolume(v);
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(width: 4),

                    // Full player expand
                    IconButton(
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      tooltip: 'Expand Player',
                      onPressed: AppNavigator.openPlayer,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LikeButton extends StatefulWidget {
  final MediaMetadata meta;
  const _LikeButton({required this.meta});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  bool _liked = false;
  StreamSubscription? _dbSub;

  @override
  void initState() {
    super.initState();
    _check();
    _dbSub = AppDatabase.instance.changes.listen((_) => _check());
  }

  @override
  void didUpdateWidget(covariant _LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.meta.id != widget.meta.id) _check();
  }

  @override
  void dispose() {
    _dbSub?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final l = await AppDatabase.instance.isLiked(widget.meta.id);
    if (mounted) setState(() => _liked = l);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(
        _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
        color: _liked ? Colors.redAccent : scheme.onSurfaceVariant,
      ),
      tooltip: _liked ? 'In Favorites' : 'Add to Favorites',
      onPressed: () async {
        final res = await player.toggleLike(widget.meta);
        if (mounted) {
          setState(() => _liked = res);
          showSnack(
            context,
            res ? 'Added to Liked Songs' : 'Removed from Liked Songs',
          );
        }
      },
    );
  }
}
