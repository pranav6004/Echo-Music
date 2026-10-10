import 'package:flutter/material.dart';

import '../../services/spotify_importer.dart';
import '../components/common.dart';
import '../components/thumbnail.dart';
import '../shell/app_navigator.dart';

class SpotifyImportScreen extends StatefulWidget {
  const SpotifyImportScreen({super.key});

  @override
  State<SpotifyImportScreen> createState() => _SpotifyImportScreenState();
}

class _SpotifyImportScreenState extends State<SpotifyImportScreen> {
  final _controller = TextEditingController();
  SpotifyPlaylistData? _playlist;
  bool _fetching = false;
  bool _importing = false;
  String? _error;

  int _currentTrack = 0;
  int _totalTracks = 0;
  String _currentTrackName = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaylist() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _fetching = true;
      _error = null;
      _playlist = null;
    });

    try {
      final data = await SpotifyImporter.instance.fetchPlaylist(text);
      if (mounted) {
        setState(() {
          _playlist = data;
          _fetching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e'.replaceAll('Exception: ', '');
          _fetching = false;
        });
      }
    }
  }

  Future<void> _startImport() async {
    final playlist = _playlist;
    if (playlist == null || _importing) return;

    setState(() {
      _importing = true;
      _currentTrack = 0;
      _totalTracks = playlist.tracks.length;
      _currentTrackName = '';
    });

    try {
      final matchedCount = await SpotifyImporter.instance.importToLibrary(
        data: playlist,
        onProgress: (current, total, name) {
          if (mounted) {
            setState(() {
              _currentTrack = current;
              _totalTracks = total;
              _currentTrackName = name;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _importing = false;
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import Complete'),
            content: Text(
              'Successfully matched and imported $matchedCount of ${playlist.tracks.length} tracks into "${playlist.name}".',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _importing = false;
          _error = 'Import error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Spotify'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              // Hero card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1DB954).withValues(alpha: 0.25),
                      scheme.surfaceContainerLow,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.queue_music_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spotify Playlist Mirror',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paste any public Spotify playlist URL to find matching high-res tracks and import into your Resona library.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // URL input field
              TextField(
                controller: _controller,
                enabled: !_importing && !_fetching,
                decoration: InputDecoration(
                  labelText: 'Spotify Playlist Link',
                  hintText: 'https://open.spotify.com/playlist/...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => _controller.clear(),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: (_) => _fetchPlaylist(),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  FilledButton.icon(
                    icon: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.search_rounded),
                    label: const Text('Fetch Playlist'),
                    onPressed: (_fetching || _importing) ? null : _fetchPlaylist,
                  ),
                  const SizedBox(width: 12),
                  if (_playlist != null && !_importing)
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.download_rounded),
                      label: Text('Import ${_playlist!.tracks.length} Tracks'),
                      onPressed: _startImport,
                    ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: scheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Import Progress Indicator
              if (_importing) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Matching tracks...',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '$_currentTrack / $_totalTracks',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: _totalTracks > 0 ? _currentTrack / _totalTracks : null,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _currentTrackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Playlist Preview
              if (_playlist != null && !_importing) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_playlist!.coverUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ResonaImage(
                          url: _playlist!.coverUrl!,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _playlist!.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_playlist!.tracks.length} tracks detected',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Tracks to be matched:',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < _playlist!.tracks.length.clamp(0, 50); i++) ...[
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    title: Text(
                      _playlist!.tracks[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      _playlist!.tracks[i].artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (_playlist!.tracks.length > 50)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '+ ${_playlist!.tracks.length - 50} more tracks',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
