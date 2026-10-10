import 'dart:io';
import 'dart:ui';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/download_manager.dart';
import '../../data/settings.dart';
import '../../playback/media_metadata.dart';
import '../../playback/player_controller.dart';
import '../../stream/stream_resolver.dart';
import '../components/canvas_background.dart';
import '../components/menus.dart';
import '../components/thumbnail.dart';
import '../components/watch_builder.dart';
import '../screens/equalizer_screen.dart';
import '../shell/app_navigator.dart';
import 'lyrics_view.dart';
import 'player_palette.dart';
import 'queue_sheet.dart';

/// Full-screen now-playing view - Premium desktop studio layout with responsive
/// 2-column split (Hero artwork on left, real-time synced lyrics/queue on right).
class FullPlayer extends StatefulWidget {
  const FullPlayer({super.key});

  @override
  State<FullPlayer> createState() => _FullPlayerState();
}

class _FullPlayerState extends State<FullPlayer> {
  bool _showLyrics = true;
  bool _showQueue = false;
  List<Color>? _colors;
  String? _paletteFor;
  double? _dragValue;
  bool _depsReady = false;

  @override
  void initState() {
    super.initState();
    _showLyrics = Settings.instance.showLyricsOnPlayer;
    AppNavigator.queueRequested.addListener(_openQueue);
    player.handler.currentMetadata.addListener(_onMeta);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_depsReady) {
      _depsReady = true;
      _onMeta();
    }
  }

  @override
  void dispose() {
    AppNavigator.queueRequested.removeListener(_openQueue);
    player.handler.currentMetadata.removeListener(_onMeta);
    super.dispose();
  }

  void _openQueue() {
    if (mounted) setState(() => _showQueue = true);
  }

  Future<void> _onMeta() async {
    if (!mounted || !_depsReady) return;
    final meta = player.handler.currentMetadata.value;
    final url = meta?.thumbnailUrl;
    if (url == _paletteFor) return;
    _paletteFor = url;
    final scheme = Theme.of(context).colorScheme;
    final colors = await PlayerPalette.extract(url, scheme: scheme);
    if (mounted && _paletteFor == url) setState(() => _colors = colors);
  }

  @override
  Widget build(BuildContext context) {
    final handler = player.handler;
    final scheme = Theme.of(context).colorScheme;
    final settings = Settings.instance;

    return ValueListenableBuilder<MediaMetadata?>(
      valueListenable: handler.currentMetadata,
      builder: (context, meta, _) {
        if (meta == null) return const SizedBox.shrink();
        final colors = _colors ?? PlayerPalette.fallback(scheme);
        final onBg = Colors.white;

        return Material(
          color: const Color(0xFF0F0E13),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Ambient mesh backdrop
              _AtmosphericBackdrop(
                url: meta.thumbnailUrl,
                colors: colors,
                style: settings.playerBackground,
              ),

              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWidescreen = constraints.maxWidth >= 860;
                    return Column(
                      children: [
                        // Top Bar Navigation
                        _TopBar(
                          onBg: onBg,
                          meta: meta,
                          onSleepTimer: () => _showSleepTimer(context),
                        ),

                        // Center Content
                        Expanded(
                          child: isWidescreen
                              ? _WidescreenStage(
                                  meta: meta,
                                  onBg: onBg,
                                  colors: colors,
                                  showQueue: _showQueue,
                                  onToggleView: (queue) =>
                                      setState(() => _showQueue = queue),
                                )
                              : _CompactStage(
                                  meta: meta,
                                  onBg: onBg,
                                  colors: colors,
                                  showLyrics: _showLyrics,
                                  onToggleLyrics: () => setState(
                                    () => _showLyrics = !_showLyrics,
                                  ),
                                ),
                        ),

                        // Bottom Playback Deck
                        _BottomDeck(
                          meta: meta,
                          onBg: onBg,
                          dragValue: _dragValue,
                          onDrag: (v) => setState(() => _dragValue = v),
                          onDragEnd: (dur) {
                            setState(() => _dragValue = null);
                            handler.seek(dur);
                          },
                          showLyrics: _showLyrics,
                          showQueue: _showQueue,
                          isWidescreen: isWidescreen,
                          onToggleLyrics: () =>
                              setState(() => _showLyrics = !_showLyrics),
                          onToggleQueue: () =>
                              setState(() => _showQueue = !_showQueue),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSleepTimer(BuildContext context) {
    final handler = player.handler;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sleep Timer',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final m in [5, 10, 15, 30, 45, 60, 90])
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: Text('$m minutes'),
                      onTap: () {
                        handler.startSleepTimer(Duration(minutes: m));
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.music_off_rounded),
                    title: const Text('End of song'),
                    onTap: () {
                      handler.sleepAtEnd();
                      Navigator.of(ctx).pop();
                    },
                  ),
                  if (handler.sleepTimerEnd.value != null ||
                      handler.sleepAtEndOfSong.value)
                    ListTile(
                      leading: const Icon(Icons.close_rounded),
                      title: const Text('Cancel timer'),
                      onTap: () {
                        handler.cancelSleepTimer();
                        Navigator.of(ctx).pop();
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dynamic atmospheric backdrop blending canvas loops with multi-layered radial gradients
class _AtmosphericBackdrop extends StatelessWidget {
  final String? url;
  final List<Color> colors;
  final PlayerBackgroundStyle style;
  const _AtmosphericBackdrop({
    required this.url,
    required this.colors,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFF4A1525);
    final c2 = colors.length > 1 ? colors.last : const Color(0xFF140D1E);

    return CanvasBackground(
      fallbackArtworkUrl: url,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF0D0C11)),
          // Top-left ambient orb
          Positioned(
            top: -120,
            left: -120,
            width: 700,
            height: 700,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c1.withValues(alpha: 0.38),
                    c1.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Center-right ambient orb
          Positioned(
            bottom: -150,
            right: -100,
            width: 800,
            height: 800,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    c2.withValues(alpha: 0.32),
                    c2.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Dark contrast vignette for high readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.5),
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Top navigation bar with minimize, queue origin tag, and sleep timer
class _TopBar extends StatelessWidget {
  final Color onBg;
  final MediaMetadata meta;
  final VoidCallback onSleepTimer;
  const _TopBar({
    required this.onBg,
    required this.meta,
    required this.onSleepTimer,
  });

  @override
  Widget build(BuildContext context) {
    final handler = player.handler;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: AppNavigator.closePlayer,
            tooltip: 'Minimize player (Esc)',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: onBg,
              size: 28,
            ),
          ),
          Expanded(
            child: Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: handler.queueTitleNotifier,
                builder: (context, title, _) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 14,
                        color: onBg.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        title != null && title.isNotEmpty
                            ? 'PLAYING FROM • $title'
                            : 'NOW PLAYING',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onBg.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onSleepTimer,
            tooltip: 'Sleep timer',
            icon: Icon(
              Icons.bedtime_outlined,
              color: onBg.withValues(alpha: 0.8),
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () => showSongMenu(context, meta.toSongItem()),
            tooltip: 'More options',
            icon: Icon(
              Icons.more_horiz_rounded,
              color: onBg,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop widescreen 2-column split stage
class _WidescreenStage extends StatelessWidget {
  final MediaMetadata meta;
  final Color onBg;
  final List<Color> colors;
  final bool showQueue;
  final ValueChanged<bool> onToggleView;

  const _WidescreenStage({
    required this.meta,
    required this.onBg,
    required this.colors,
    required this.showQueue,
    required this.onToggleView,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFFE50914);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // LEFT HERO COLUMN: Large Artwork, Typography, Audio Badge, Action Cluster
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Elevated Album Artwork with Ambient Glow
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: c1.withValues(alpha: 0.45),
                            blurRadius: 54,
                            offset: const Offset(0, 18),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.65),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: EchoImage(
                          url: meta.thumbnailUrl,
                          width: 360,
                          height: 360,
                          radius: 24,
                          resize: 1080,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Track Title (bold display typography, never truncated)
                  Text(
                    meta.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: onBg,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                      height: 1.15,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Clickable Artist Link
                  InkWell(
                    onTap: () {
                      final aid = meta.artists.isNotEmpty
                          ? meta.artists.first.id
                          : null;
                      if (aid != null && aid.isNotEmpty) {
                        AppNavigator.closePlayer();
                        AppNavigator.openArtist(aid);
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      meta.artistsText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: onBg.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Metadata & Audio Format Badges
                  Row(
                    children: [
                      // Audio Format Badge
                      ValueListenableBuilder<ResolvedStream?>(
                        valueListenable: player.handler.currentStream,
                        builder: (context, stream, _) {
                          final isOpus = stream != null &&
                              (stream.mimeType.contains('opus') ||
                                  stream.mimeType.contains('webm'));
                          final label = stream == null
                              ? 'HIGH QUALITY'
                              : '${isOpus ? 'OPUS' : 'AAC'} ${stream.bitrate ~/ 1000}k';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.diamond_outlined,
                                  size: 13,
                                  color: onBg.withValues(alpha: 0.9),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: onBg.withValues(alpha: 0.9),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(width: 10),

                      if (meta.album != null &&
                          meta.album!.name.isNotEmpty) ...[
                        Flexible(
                          child: Text(
                            meta.album!.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onBg.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons Row
                  Row(
                    children: [
                      _LikeButton(meta: meta, onBg: onBg),
                      const SizedBox(width: 10),
                      _ActionCircleButton(
                        icon: Icons.playlist_add_rounded,
                        tooltip: 'Add to playlist',
                        onBg: onBg,
                        onTap: () =>
                            showAddToPlaylistSheet(context, [meta]),
                      ),
                      const SizedBox(width: 10),
                      _ActionCircleButton(
                        icon: Icons.tune_rounded,
                        tooltip: 'Equalizer & DSP',
                        onBg: onBg,
                        onTap: () => AppNavigator.push(const EqualizerScreen()),
                      ),
                      const SizedBox(width: 10),
                      _DownloadButton(onBg: onBg),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 44),

          // RIGHT COLUMN: Synced Lyrics / Queue Hub in Frosted Glass Card
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  // Tab Switcher Header (Lyrics | Queue)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        _StageTabChip(
                          icon: Icons.lyrics_rounded,
                          label: 'Synced Lyrics',
                          active: !showQueue,
                          onBg: onBg,
                          onTap: () => onToggleView(false),
                        ),
                        const SizedBox(width: 8),
                        _StageTabChip(
                          icon: Icons.queue_music_rounded,
                          label: 'Up Next',
                          active: showQueue,
                          onBg: onBg,
                          onTap: () => onToggleView(true),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12, height: 1),

                  // View Body
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: showQueue
                          ? const QueueBody()
                          : LyricsView(
                              key: ValueKey('lyrics-${meta.id}'),
                              meta: meta,
                              textColor: onBg,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact stage for narrow viewports
class _CompactStage extends StatelessWidget {
  final MediaMetadata meta;
  final Color onBg;
  final List<Color> colors;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  const _CompactStage({
    required this.meta,
    required this.onBg,
    required this.colors,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c1 = colors.isNotEmpty ? colors.first : const Color(0xFFE50914);

    return Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: showLyrics
                ? LyricsView(
                    key: ValueKey('lyrics-${meta.id}'),
                    meta: meta,
                    textColor: onBg,
                  )
                : LayoutBuilder(
                    builder: (context, c) {
                      final size =
                          (c.maxWidth - 48).clamp(160.0, c.maxHeight - 24);
                      return Center(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: c1.withValues(alpha: 0.4),
                                blurRadius: 44,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: EchoImage(
                              url: meta.thumbnailUrl,
                              width: size,
                              height: size,
                              radius: 20,
                              resize: 1080,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),

        // Title Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meta.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onBg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      meta.artistsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onBg.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              _LikeButton(meta: meta, onBg: onBg),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom deck holding seekbar and transport controls
class _BottomDeck extends StatelessWidget {
  final MediaMetadata meta;
  final Color onBg;
  final double? dragValue;
  final ValueChanged<double> onDrag;
  final ValueChanged<Duration> onDragEnd;
  final bool showLyrics;
  final bool showQueue;
  final bool isWidescreen;
  final VoidCallback onToggleLyrics;
  final VoidCallback onToggleQueue;

  const _BottomDeck({
    required this.meta,
    required this.onBg,
    required this.dragValue,
    required this.onDrag,
    required this.onDragEnd,
    required this.showLyrics,
    required this.showQueue,
    required this.isWidescreen,
    required this.onToggleLyrics,
    required this.onToggleQueue,
  });

  @override
  Widget build(BuildContext context) {
    final handler = player.handler;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isWidescreen ? 48 : 20,
        vertical: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrub Slider Bar
          _Seekbar(
            onBg: onBg,
            meta: meta,
            dragValue: dragValue,
            onDrag: onDrag,
            onDragEnd: onDragEnd,
          ),

          const SizedBox(height: 6),

          // Central Controls Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Shuffle
              ValueListenableBuilder<bool>(
                valueListenable: handler.shuffleEnabled,
                builder: (context, shuffle, _) => IconButton(
                  onPressed: handler.toggleShuffle,
                  tooltip: shuffle ? 'Shuffle (On)' : 'Shuffle (Off)',
                  icon: Icon(
                    Icons.shuffle_rounded,
                    size: 22,
                    color: shuffle ? onBg : onBg.withValues(alpha: 0.5),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Previous
              IconButton(
                onPressed: handler.skipToPrevious,
                tooltip: 'Previous',
                iconSize: 34,
                icon: Icon(Icons.skip_previous_rounded, color: onBg),
              ),

              const SizedBox(width: 14),

              // Play / Pause FAB
              StreamBuilder<bool>(
                stream: handler.player.playingStream,
                builder: (context, snap) {
                  final playing = snap.data ?? handler.player.playing;
                  return ValueListenableBuilder<bool>(
                    valueListenable: handler.isLoadingItem,
                    builder: (context, loading, _) {
                      return Material(
                        color: onBg,
                        shape: const CircleBorder(),
                        elevation: 8,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => playing ? handler.pause() : handler.play(),
                          child: Container(
                            width: 58,
                            height: 58,
                            alignment: Alignment.center,
                            child: loading
                                ? const SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 3,
                                      color: Colors.black,
                                    ),
                                  )
                                : Icon(
                                    playing
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 38,
                                    color: Colors.black,
                                  ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(width: 14),

              // Next
              IconButton(
                onPressed: handler.skipToNext,
                tooltip: 'Next',
                iconSize: 34,
                icon: Icon(Icons.skip_next_rounded, color: onBg),
              ),

              const SizedBox(width: 14),

              // Repeat
              ValueListenableBuilder<AudioServiceRepeatMode>(
                valueListenable: handler.repeatMode,
                builder: (context, mode, _) => IconButton(
                  onPressed: handler.toggleRepeat,
                  tooltip: 'Repeat',
                  icon: Icon(
                    mode == AudioServiceRepeatMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    size: 22,
                    color: mode == AudioServiceRepeatMode.none
                        ? onBg.withValues(alpha: 0.5)
                        : onBg,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Custom Styled Seekbar
class _Seekbar extends StatelessWidget {
  final Color onBg;
  final MediaMetadata meta;
  final double? dragValue;
  final ValueChanged<double> onDrag;
  final ValueChanged<Duration> onDragEnd;
  const _Seekbar({
    required this.onBg,
    required this.meta,
    required this.dragValue,
    required this.onDrag,
    required this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final handler = player.handler;
    return StreamBuilder<Duration>(
      stream: handler.player.positionStream,
      builder: (context, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        final dur = meta.duration > 0
            ? Duration(seconds: meta.duration)
            : (handler.player.duration ?? Duration.zero);
        final total = dur.inMilliseconds;
        final v = dragValue ??
            (total == 0 ? 0.0 : (pos.inMilliseconds / total).clamp(0.0, 1.0));

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                activeTrackColor: onBg,
                inactiveTrackColor: onBg.withValues(alpha: 0.22),
                thumbColor: onBg,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 6,
                  elevation: 2,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: v,
                onChanged: total == 0 ? null : onDrag,
                onChangeEnd: total == 0
                    ? null
                    : (x) => onDragEnd(
                          Duration(milliseconds: (x * total).round()),
                        ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDurationMs(
                      dragValue != null
                          ? Duration(milliseconds: (dragValue! * total).round())
                          : pos,
                    ),
                    style: TextStyle(
                      color: onBg.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatDurationMs(dur),
                    style: TextStyle(
                      color: onBg.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Reactive Like Button
class _LikeButton extends StatelessWidget {
  final MediaMetadata meta;
  final Color onBg;
  const _LikeButton({required this.meta, required this.onBg});

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<bool>(
      watchKey: meta.id,
      query: () => AppDatabase.instance.isLiked(meta.id),
      builder: (context, data) {
        final liked = data ?? false;
        return Material(
          color: liked
              ? const Color(0xFFFF4060).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: liked ? 'In Favorites' : 'Add to Favorites',
            onPressed: () async {
              final res = await player.toggleLike(meta);
              if (context.mounted) {
                showSnack(
                  context,
                  res ? 'Added to Liked Songs' : 'Removed from Liked Songs',
                );
              }
            },
            icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? const Color(0xFFFF4060) : onBg,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}

/// Action Circle Button
class _ActionCircleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color onBg;
  final VoidCallback onTap;
  const _ActionCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: onBg, size: 22),
      ),
    );
  }
}

/// Download action button
class _DownloadButton extends StatelessWidget {
  final Color onBg;
  const _DownloadButton({required this.onBg});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DownloadManager.instance,
      builder: (context, _) {
        final meta = player.handler.currentMetadata.value;
        final id = meta?.id;
        final state = id == null ? null : DownloadManager.instance.stateOf(id);
        final done = state?.state == DownloadState.completed;
        final busy = state?.state == DownloadState.downloading ||
            state?.state == DownloadState.queued;

        return Material(
          color: done
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.08),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: done
                ? 'Saved offline (Documents/downloads)'
                : busy
                ? 'Downloading ${(state?.progress != null ? (state!.progress * 100).toInt() : 0)}%'
                : 'Download song',
            onPressed: () async {
              if (meta == null || meta.isLocal) return;
              if (done) {
                await DownloadManager.instance.remove(meta.id);
                if (context.mounted) showSnack(context, 'Removed download');
              } else if (!busy) {
                await DownloadManager.instance.download(meta);
                if (context.mounted) {
                  showSnack(context, 'Downloading to Documents/downloads');
                }
              }
            },
            icon: Icon(
              done
                  ? Icons.offline_pin_rounded
                  : busy
                  ? Icons.downloading_rounded
                  : Icons.download_rounded,
              color: done ? Colors.greenAccent : onBg,
              size: 22,
            ),
          ),
        );
      },
    );
  }
}

/// Stage tab selector chip
class _StageTabChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color onBg;
  final VoidCallback onTap;
  const _StageTabChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? Colors.white.withValues(alpha: 0.2)
          : Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? onBg : onBg.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? onBg : onBg.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
