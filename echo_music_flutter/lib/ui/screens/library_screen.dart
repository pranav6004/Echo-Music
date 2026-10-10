import 'package:flutter/material.dart';

import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/settings.dart';
import '../../innertube/models/yt_item.dart';
import '../../playback/player_controller.dart';
import '../components/common.dart';
import '../components/items.dart';
import '../components/menus.dart';
import '../components/thumbnail.dart';
import '../shell/app_navigator.dart';
import '../components/watch_builder.dart';

/// Library — quick tiles + playlists / songs / albums / artists tabs
/// (port of `LibraryScreen.kt` and the `Library*Screen.kt` tabs).
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with AutomaticKeepAliveClientMixin {
  static const _filters = ['Playlists', 'Songs', 'Albums', 'Artists'];
  int _filter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _filter = _filters
        .indexOf(
          Settings.instance.libraryFilter.toLowerCase().replaceFirstMapped(
            RegExp('^.'),
            (m) => m[0]!.toUpperCase(),
          ),
        )
        .clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final db = AppDatabase.instance;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('Library'),
            actions: [
              IconButton(
                onPressed: AppNavigator.openHistory,
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                onPressed: AppNavigator.openSettings,
                icon: const Icon(Icons.settings_outlined),
              ),
              const SizedBox(width: 4),
            ],
          ),
          SliverToBoxAdapter(
            child: ChipsRow(
              labels: _filters,
              selected: _filter,
              onSelected: (i) {
                setState(() => _filter = i ?? 0);
                Settings.instance.libraryFilter = _filters[_filter]
                    .toUpperCase();
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            sliver: SliverGrid.count(
              crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 4 : 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.9,
              children: [
                LibraryTile(
                  icon: Icons.favorite_rounded,
                  label: 'Liked',
                  onTap: AppNavigator.openLikedSongs,
                ),
                LibraryTile(
                  icon: Icons.offline_pin_rounded,
                  label: 'Downloaded',
                  onTap: AppNavigator.openDownloaded,
                ),
                LibraryTile(
                  icon: Icons.history_rounded,
                  label: 'History',
                  onTap: AppNavigator.openHistory,
                ),
                LibraryTile(
                  icon: Icons.trending_up_rounded,
                  label: 'My top 50',
                  onTap: AppNavigator.openTopSongs,
                ),
              ],
            ),
          ),
          switch (_filter) {
            0 => _PlaylistsSliver(db: db),
            1 => _SongsSliver(db: db),
            2 => _AlbumsSliver(db: db),
            _ => _ArtistsSliver(db: db),
          },
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
          ),
        ],
      ),
    );
  }
}

class _PlaylistsSliver extends StatelessWidget {
  final AppDatabase db;
  const _PlaylistsSliver({required this.db});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WatchBuilder<List<PlaylistWithInfo>>(
      query: db.playlists,
      builder: (context, data) {
        final playlists = data ?? const <PlaylistWithInfo>[];
        final screenW = MediaQuery.sizeOf(context).width;
        final cols = responsiveGridColumns(screenW);
        final width = (screenW - (cols + 1) * 16) / cols;
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Playlists',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final name = await showTextInputDialog(
                          context,
                          title: 'Create playlist',
                        );
                        if (name != null && name.trim().isNotEmpty) {
                          await db.createPlaylist(name.trim());
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
            ),
            if (playlists.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyPlaceholder(
                  icon: Icons.queue_music_rounded,
                  text: 'No playlists yet.\nCreate one or save from YouTube Music.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final availableW = constraints.crossAxisExtent;
                    final cols = responsiveGridColumns(availableW);
                    final width = (availableW - (cols - 1) * 16) / cols;
                    return SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: width / (width + 68),
                      ),
                      itemCount: playlists.length,
                      itemBuilder: (context, i) {
                        final p = playlists[i];
                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () =>
                              AppNavigator.openLocalPlaylist(p.playlist.id),
                          onLongPress: () => showLocalPlaylistMenu(context, p),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PlaylistMosaic(
                                thumbnails: p.playlist.thumbnailUrl != null
                                    ? [p.playlist.thumbnailUrl!]
                                    : p.thumbnails,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                p.playlist.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${p.songCount} songs${p.playlist.browseId != null ? " • YouTube" : ""}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 2x2 mosaic of thumbnails (port of `PlaylistThumbnail`).
class PlaylistMosaic extends StatelessWidget {
  final List<String> thumbnails;
  final double? size;
  final IconData? icon;
  const PlaylistMosaic({
    super.key,
    required this.thumbnails,
    this.size,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget content;
    if (thumbnails.isEmpty) {
      content = Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Icon(
            icon ?? Icons.queue_music_rounded,
            size: (size ?? 120) * 0.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    } else if (thumbnails.length < 4) {
      content = ResonaImage(
        url: thumbnails.first,
        radius: 16,
      );
    } else {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final t in thumbnails.take(4))
              ResonaImage(url: t, radius: 0, resize: 224),
          ],
        ),
      );
    }

    if (size != null) {
      return SizedBox(
        width: size,
        height: size,
        child: content,
      );
    }
    return AspectRatio(
      aspectRatio: 1.0,
      child: content,
    );
  }
}

class _SongsSliver extends StatefulWidget {
  final AppDatabase db;
  const _SongsSliver({required this.db});

  @override
  State<_SongsSliver> createState() => _SongsSliverState();
}

class _SongsSliverState extends State<_SongsSliver> {
  SongSortType _sort = SongSortType.createDate;
  bool _desc = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WatchBuilder<List<Song>>(
      watchKey: '${_sort.name}-$_desc',
      query: () => widget.db.librarySongs(sort: _sort, desc: _desc),
      builder: (context, data) {
        final songs = data ?? const <Song>[];
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    SortHeader(
                      label: switch (_sort) {
                        SongSortType.createDate => 'Date added',
                        SongSortType.name => 'Name',
                        SongSortType.artist => 'Artist',
                        SongSortType.playTime => 'Play time',
                      },
                      descending: _desc,
                      onToggleDirection: () => setState(() => _desc = !_desc),
                      onPick: () async {
                        final s = await showModalBottomSheet<SongSortType>(
                          context: context,
                          useRootNavigator: true,
                          builder: (ctx) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final (t, l) in [
                                  (SongSortType.createDate, 'Date added'),
                                  (SongSortType.name, 'Name'),
                                  (SongSortType.playTime, 'Play time'),
                                ])
                                  ListTile(
                                    title: Text(l),
                                    onTap: () => Navigator.of(ctx).pop(t),
                                  ),
                              ],
                            ),
                          ),
                        );
                        if (s != null) setState(() => _sort = s);
                      },
                    ),
                    const Spacer(),
                    Text(
                      '${songs.length} songs',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      onPressed: songs.isEmpty
                          ? null
                          : () => player.playLocalList(
                              songs,
                              title: 'Songs',
                              shuffle: true,
                            ),
                      icon: const Icon(Icons.shuffle_rounded),
                    ),
                  ],
                ),
              ),
            ),
            if (songs.isEmpty)
              const SliverToBoxAdapter(
                child: EmptyPlaceholder(
                  icon: Icons.music_note_rounded,
                  text: 'Liked and saved songs show up here.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                sliver: SliverList.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) => LocalSongTile(
                    song: songs[i],
                    songContext: songs,
                    contextTitle: 'Songs',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class SortHeader extends StatelessWidget {
  final String label;
  final bool descending;
  final VoidCallback onToggleDirection;
  final VoidCallback onPick;
  const SortHeader({
    super.key,
    required this.label,
    required this.descending,
    required this.onToggleDirection,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(18),
          ),
          child: InkWell(
            onTap: onPick,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(18),
          ),
          child: InkWell(
            onTap: onToggleDirection,
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(
                descending
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AlbumsSliver extends StatelessWidget {
  final AppDatabase db;
  const _AlbumsSliver({required this.db});

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<AlbumWithInfo>>(
      query: db.libraryAlbums,
      builder: (context, data) {
        final albums = data ?? const <AlbumWithInfo>[];
        if (albums.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyPlaceholder(
              icon: Icons.album_rounded,
              text: 'Saved albums show up here.',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final availableW = constraints.crossAxisExtent;
              final cols = responsiveGridColumns(availableW);
              final width = (availableW - (cols - 1) * 16) / cols;
              return SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: width / (width + 68),
                ),
                itemCount: albums.length,
                itemBuilder: (context, i) {
              final a = albums[i];
              return YTGridItem(
                width: width,
                item: AlbumItem(
                  browseId: a.album.id,
                  playlistId: a.album.playlistId ?? '',
                  title: a.album.title,
                  artists: a.artists
                      .map((r) => Artist(name: r.name, id: r.id))
                      .toList(),
                  year: a.album.year,
                  thumbnail: a.album.thumbnailUrl ?? '',
                  explicit: a.album.explicit,
                ),
              );
            },
          );
            },
          ),
        );
      },
    );
  }
}

class _ArtistsSliver extends StatelessWidget {
  final AppDatabase db;
  const _ArtistsSliver({required this.db});

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<ArtistWithSongCount>>(
      query: () => db.libraryArtists(),
      builder: (context, data) {
        final artists = data ?? const <ArtistWithSongCount>[];
        if (artists.isEmpty) {
          return const SliverToBoxAdapter(
            child: EmptyPlaceholder(
              icon: Icons.person_rounded,
              text: 'Subscribed artists show up here.',
            ),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              final availableW = constraints.crossAxisExtent;
              final cols = responsiveGridColumns(availableW);
              if (availableW >= 600) {
                final width = (availableW - (cols - 1) * 16) / cols;
                return SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: width / (width + 52),
                  ),
                  itemCount: artists.length,
                  itemBuilder: (context, i) {
                    final a = artists[i];
                    final item = ArtistItem(
                      id: a.artist.id,
                      title: a.artist.name,
                      thumbnail: a.artist.thumbnailUrl,
                      channelId: a.artist.channelId,
                    );
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => AppNavigator.openArtist(a.artist.id),
                      onLongPress: () => showArtistMenu(context, item),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipOval(
                            child: ResonaImage(
                              url: a.artist.thumbnailUrl,
                              width: width * 0.82,
                              height: width * 0.82,
                              circle: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            a.artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            a.songCount > 0 ? '${a.songCount} songs' : 'Artist',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              return SliverList.builder(
                itemCount: artists.length,
                itemBuilder: (context, i) {
                  final a = artists[i];
                  final item = ArtistItem(
                    id: a.artist.id,
                    title: a.artist.name,
                    thumbnail: a.artist.thumbnailUrl,
                    channelId: a.artist.channelId,
                  );
                  return MediaListTile(
                    title: a.artist.name,
                    subtitle: joinByBullet([
                      if (a.artist.bookmarkedAt != null) 'Subscribed',
                      if (a.songCount > 0) '${a.songCount} songs',
                    ]),
                    thumbnailUrl: a.artist.thumbnailUrl,
                    circle: true,
                    onTap: () => AppNavigator.openArtist(a.artist.id),
                    onMore: () => showArtistMenu(context, item),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
