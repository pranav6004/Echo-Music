import 'package:flutter/material.dart';

import '../../data/database.dart';
import '../../data/settings.dart';
import '../../innertube/models/yt_item.dart';
import '../../innertube/youtube.dart';
import '../../playback/player_controller.dart';
import '../../playback/media_metadata.dart';
import '../../services/ai_service.dart';
import '../components/common.dart';
import '../components/items.dart';
import '../components/thumbnail.dart';
import '../settings/ai_settings_screen.dart';
import '../shell/app_navigator.dart';

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> {
  final _promptCtrl = TextEditingController();
  int _trackCount = 15;
  bool _generating = false;
  String? _statusText;
  String? _error;

  List<AiTrackSuggestion>? _suggestions;
  List<SongItem> _resolvedSongs = [];
  bool _resolving = false;

  final _presets = const [
    'Late Night Lo-Fi Beats',
    'Cyberpunk Synthwave',
    'Rainy Day Coffee Shop Jazz',
    'High Energy Gym Workout',
    '2000s Nostalgic Indie Rock',
    'Epic Cinematic Orchestral',
  ];

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _generating = true;
      _error = null;
      _suggestions = null;
      _resolvedSongs = [];
      _statusText = 'Consulting AI curator...';
    });

    try {
      final suggestions = await AiService.instance.generatePlaylist(
        prompt: prompt,
        count: _trackCount,
      );

      if (!mounted) return;

      if (suggestions.isEmpty) {
        setState(() {
          _generating = false;
          _error = 'AI did not return any track recommendations. Please check your AI API key and model settings.';
        });
        return;
      }

      setState(() {
        _suggestions = suggestions;
        _generating = false;
        _resolving = true;
        _statusText = 'Matching tracks on YouTube Music (0/${suggestions.length})...';
      });

      final yt = YouTube.instance;
      final resolved = <SongItem>[];

      for (var i = 0; i < suggestions.length; i++) {
        final item = suggestions[i];
        if (!mounted) return;
        setState(() {
          _statusText = 'Matching tracks (${i + 1}/${suggestions.length}): ${item.title} - ${item.artist}';
        });

        try {
          final res = await yt.search('${item.title} ${item.artist}', YouTube.filterSong);
          final songs = res.items.whereType<SongItem>().toList();
          if (songs.isNotEmpty) {
            resolved.add(songs.first);
            if (mounted) {
              setState(() {
                _resolvedSongs = List.from(resolved);
              });
            }
          }
        } catch (_) {}

        await Future.delayed(const Duration(milliseconds: 40));
      }

      if (mounted) {
        setState(() {
          _resolving = false;
          _statusText = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _generating = false;
          _resolving = false;
          _error = '$e';
        });
      }
    }
  }

  Future<void> _saveAsPlaylist() async {
    if (_resolvedSongs.isEmpty) return;
    final name = _promptCtrl.text.trim().isNotEmpty
        ? 'AI: ${_promptCtrl.text.trim()}'
        : 'AI Generated Mix';

    final db = AppDatabase.instance;
    final pl = await db.createPlaylist(name);
    await db.addToPlaylist(pl.id, _resolvedSongs.map(MediaMetadata.fromSongItem).toList());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved "${pl.name}" to library')),
      );
    }
  }

  void _playAll() {
    if (_resolvedSongs.isEmpty) return;
    player.playSongItems(_resolvedSongs, title: 'AI: ${_promptCtrl.text.trim()}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = Settings.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Music Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'AI Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            children: [
              // Hero card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer.withValues(alpha: 0.6),
                      scheme.tertiaryContainer.withValues(alpha: 0.4),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [scheme.primary, scheme.tertiary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prompt to Playlist Studio',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active: ${s.aiProvider.toUpperCase()} (${s.aiModel.isNotEmpty ? s.aiModel : "default"})',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Config'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Preset chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in _presets) ...[
                      ActionChip(
                        label: Text(p),
                        onPressed: () {
                          _promptCtrl.text = p;
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Prompt Input Field
              TextField(
                controller: _promptCtrl,
                enabled: !_generating && !_resolving,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Describe the vibe, mood, genre, or scene...',
                  hintText: 'e.g. driving through neon rainy Tokyo with dark synthwave and chill vocals',
                  prefixIcon: const Icon(Icons.music_note_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onSubmitted: (_) => _generate(),
              ),

              const SizedBox(height: 12),

              // Count selector + Generate button
              Row(
                children: [
                  const Text('Track Count:'),
                  const SizedBox(width: 12),
                  for (final cnt in [10, 15, 20, 30]) ...[
                    ChoiceChip(
                      label: Text('$cnt'),
                      selected: _trackCount == cnt,
                      onSelected: (sel) {
                        if (sel) setState(() => _trackCount = cnt);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  FilledButton.icon(
                    icon: (_generating || _resolving)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Generate'),
                    onPressed: (_generating || _resolving) ? null : _generate,
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
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

              if (_statusText != null) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: scheme.surfaceContainerHigh,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _statusText!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Results Header & Actions
              if (_resolvedSongs.isNotEmpty) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      'Generated Tracks (${_resolvedSongs.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Play All'),
                      onPressed: _playAll,
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save to Library'),
                      onPressed: _saveAsPlaylist,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _resolvedSongs.length; i++) ...[
                  ListTile(
                    dense: true,
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ResonaImage(
                            url: _resolvedSongs[i].thumbnail,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                    title: Text(
                      _resolvedSongs[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _resolvedSongs[i].artists.map((a) => a.name).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      player.playSong(_resolvedSongs[i]);
                    },
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
