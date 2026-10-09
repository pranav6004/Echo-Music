import '../components/items.dart';
import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../innertube/models/yt_item.dart';
import '../../innertube/pages/pages.dart';
import '../../innertube/youtube.dart';
import '../../playback/player_controller.dart';
import '../components/common.dart';
import '../components/menus.dart';
import '../components/thumbnail.dart';

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  ChartsPage? _page;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await YouTube.instance.charts();
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  void _playAll({bool shuffle = false}) {
    final page = _page;
    if (page == null) return;
    final allSongs = <SongItem>[];
    for (final sec in page.sections) {
      for (final item in sec.items) {
        if (item is SongItem) {
          allSongs.add(item);
        }
      }
    }
    if (allSongs.isNotEmpty) {
      player.playSongItems(allSongs, title: 'Top Charts', shuffle: shuffle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Top Charts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Failed to load charts: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(context, theme, scheme),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final page = _page!;
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        // Hero Header
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primaryContainer.withValues(alpha: 0.7),
                scheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.leaderboard_rounded,
                  size: 36,
                  color: scheme.onPrimary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Charts & Top Tracks',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'The most played and trending tracks right now on YouTube Music',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Play All'),
                onPressed: () => _playAll(shuffle: false),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('Shuffle'),
                onPressed: () => _playAll(shuffle: true),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Sections
        for (final sec in page.sections) ...[
          if (sec.items.isNotEmpty) ...[
            if (sec.items.first is SongItem) ...[
              Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 12),
                child: Text(
                  sec.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              for (var i = 0; i < sec.items.length; i++) ...[
                if (sec.items[i] is SongItem)
                  _buildChartItem(context, theme, scheme, sec.items[i] as SongItem, i + 1),
              ],
            ] else ...[
              const SizedBox(height: 16),
              SectionCarousel(
                title: sec.title,
                items: sec.items,
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _buildChartItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    SongItem item,
    int rank,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: rank <= 3 ? FontWeight.w900 : FontWeight.w600,
                color: rank <= 3 ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: EchoImage(
              url: item.thumbnail,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item.artistsText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.duration != null && item.duration! > 0)
            Text(
              formatDuration(item.duration!),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => showSongMenu(context, item),
          ),
        ],
      ),
      onTap: () {
        player.playSong(item);
      },
    );
  }
}
