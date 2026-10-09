import '../screens/spotify_import_screen.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'blocked_artists_screen.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils.dart';
import '../../data/database.dart';
import '../../data/download_manager.dart';
import '../../data/settings.dart';
import '../../stream/stream_resolver.dart';
import '../components/common.dart';
import '../screens/account_screen.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Settings hub (port of `SettingsScreen.kt`) with grouped iOS-style cards.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            _Group(
              children: [
                _Row(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  subtitle: s.isLoggedIn
                      ? s.accountName
                      : 'Sign in to YouTube Music',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AccountScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                _Row(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Theme, colours, fonts',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AppearanceSettings(),
                    ),
                  ),
                ),
                _Row(
                  icon: Icons.play_circle_outline_rounded,
                  title: 'Player & audio',
                  subtitle: 'Quality, queue, lyrics',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PlayerSettings()),
                  ),
                ),
                _Row(
                  icon: Icons.tune_rounded,
                  title: 'Content',
                  subtitle: 'Explicit, videos, region',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ContentSettings()),
                  ),
                ),
                _Row(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy',
                  subtitle: 'History controls',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PrivacySettings()),
                  ),
                ),
                _Row(
                  icon: Icons.storage_rounded,
                  title: 'Storage',
                  subtitle: 'Downloads and caches',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StorageSettings()),
                  ),
                ),
                _Row(
                  icon: Icons.hub_rounded,
                  title: 'Integrations & Social',
                  subtitle: 'Discord RPC, Last.fm, Spotify',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const IntegrationsSettings(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                _Row(
                  icon: Icons.info_outline_rounded,
                  title: 'About',
                  subtitle: 'Echo Music for iOS',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: scheme.outlineVariant.withValues(alpha: 0.3),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      trailing:
          trailing ??
          (onTap != null ? const Icon(Icons.chevron_right_rounded) : null),
      onTap: onTap,
      shape: const RoundedRectangleBorder(),
    );
  }
}

class _SettingsPage extends StatelessWidget {
  final String title;
  final List<Widget> groups;
  const _SettingsPage({required this.title, required this.groups});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: Settings.instance,
        builder: (context, _) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          children: [
            for (final g in groups) ...[g, const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: onChanged,
      shape: const RoundedRectangleBorder(),
    );
  }
}

Future<T?> _pick<T>(
  BuildContext context,
  String title,
  List<(T, String)> options,
  T current,
) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, style: Theme.of(ctx).textTheme.titleLarge),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final (v, label) in options)
                  ListTile(
                    title: Text(label),
                    trailing: v == current
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(v),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    const colors = [
      0xFFED5564,
      0xFFE91E63,
      0xFF9C27B0,
      0xFF673AB7,
      0xFF3F51B5,
      0xFF2196F3,
      0xFF03A9F4,
      0xFF00BCD4,
      0xFF009688,
      0xFF4CAF50,
      0xFF8BC34A,
      0xFFCDDC39,
      0xFFFFC107,
      0xFFFF9800,
      0xFFFF5722,
      0xFF795548,
      0xFF607D8B,
    ];
    return _SettingsPage(
      title: 'Appearance',
      groups: [
        _Group(
          children: [
            _Row(
              icon: Icons.dark_mode_outlined,
              title: 'Dark theme',
              subtitle: switch (s.darkMode) {
                DarkModePref.auto => 'Follow system',
                DarkModePref.on => 'On',
                DarkModePref.off => 'Off',
              },
              onTap: () async {
                final v = await _pick(context, 'Dark theme', const [
                  (DarkModePref.auto, 'Follow system'),
                  (DarkModePref.on, 'On'),
                  (DarkModePref.off, 'Off'),
                ], s.darkMode);
                if (v != null) s.darkMode = v;
              },
            ),
            _Switch(
              icon: Icons.contrast_rounded,
              title: 'Pure black',
              subtitle: 'True black backgrounds in dark mode',
              value: s.pureBlack,
              onChanged: (v) => s.pureBlack = v,
            ),
            _Row(
              icon: Icons.font_download_outlined,
              title: 'Font',
              subtitle: switch (s.appFont) {
                AppFont.system => 'System',
                AppFont.outfit => 'Outfit',
                AppFont.plusJakartaSans => 'Plus Jakarta Sans',
              },
              onTap: () async {
                final v = await _pick(context, 'Font', const [
                  (AppFont.system, 'System'),
                  (AppFont.outfit, 'Outfit'),
                  (AppFont.plusJakartaSans, 'Plus Jakarta Sans'),
                ], s.appFont);
                if (v != null) s.appFont = v;
              },
            ),
          ],
        ),
        _Group(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Theme colour',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in colors)
                    GestureDetector(
                      onTap: () => s.themeColor = c,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Color(c),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: s.themeColor == c
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: s.themeColor == c
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        _Group(
          children: [
            _Row(
              icon: Icons.wallpaper_rounded,
              title: 'Player background',
              subtitle: switch (s.playerBackground) {
                PlayerBackgroundStyle.gradient => 'Artwork gradient',
                PlayerBackgroundStyle.blur => 'Blurred artwork',
                PlayerBackgroundStyle.plain => 'Plain',
              },
              onTap: () async {
                final v = await _pick(context, 'Player background', const [
                  (PlayerBackgroundStyle.gradient, 'Artwork gradient'),
                  (PlayerBackgroundStyle.blur, 'Blurred artwork'),
                  (PlayerBackgroundStyle.plain, 'Plain'),
                ], s.playerBackground);
                if (v != null) s.playerBackground = v;
              },
            ),
            _Switch(
              icon: Icons.hide_image_outlined,
              title: 'Hide player thumbnail',
              value: s.hidePlayerThumbnail,
              onChanged: (v) => s.hidePlayerThumbnail = v,
            ),
            _Row(
              icon: Icons.home_outlined,
              title: 'Default tab',
              subtitle:
                  s.defaultTab.name[0].toUpperCase() +
                  s.defaultTab.name.substring(1),
              onTap: () async {
                final v = await _pick(context, 'Default tab', const [
                  (DefaultTab.home, 'Home'),
                  (DefaultTab.explore, 'Explore'),
                  (DefaultTab.library, 'Library'),
                ], s.defaultTab);
                if (v != null) s.defaultTab = v;
              },
            ),
          ],
        ),
      ],
    );
  }
}

class PlayerSettings extends StatelessWidget {
  const PlayerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    return _SettingsPage(
      title: 'Player & audio',
      groups: [
        _Group(
          children: [
            _Row(
              icon: Icons.graphic_eq_rounded,
              title: 'Audio quality',
              subtitle: switch (s.audioQuality) {
                AudioQualityPrefSetting.auto => 'Auto',
                AudioQualityPrefSetting.high => 'High',
                AudioQualityPrefSetting.low => 'Low (data saver)',
              },
              onTap: () async {
                final v = await _pick(context, 'Audio quality', const [
                  (AudioQualityPrefSetting.auto, 'Auto'),
                  (AudioQualityPrefSetting.high, 'High'),
                  (AudioQualityPrefSetting.low, 'Low (data saver)'),
                ], s.audioQuality);
                if (v != null) {
                  s.audioQuality = v;
                  StreamResolver.instance.quality = switch (v) {
                    AudioQualityPrefSetting.auto => AudioQualityPref.auto,
                    AudioQualityPrefSetting.high => AudioQualityPref.high,
                    AudioQualityPrefSetting.low => AudioQualityPref.low,
                  };
                  StreamResolver.instance.clearCache();
                }
              },
            ),
            _Switch(
              icon: Icons.volume_up_outlined,
              title: 'Audio normalization',
              subtitle: 'Match loudness between songs',
              value: s.audioNormalization,
              onChanged: (v) => s.audioNormalization = v,
            ),
          ],
        ),
        _Group(
          children: [
            _Switch(
              icon: Icons.save_outlined,
              title: 'Persistent queue',
              subtitle: 'Restore the queue on launch',
              value: s.persistentQueue,
              onChanged: (v) => s.persistentQueue = v,
            ),
            _Switch(
              icon: Icons.playlist_add_check_rounded,
              title: 'Auto load more',
              subtitle: 'Keep the queue going with related songs',
              value: s.autoLoadMore,
              onChanged: (v) => s.autoLoadMore = v,
            ),
            _Switch(
              icon: Icons.skip_next_rounded,
              title: 'Skip on error',
              subtitle: 'Move to the next song when one fails',
              value: s.autoSkipNextOnError,
              onChanged: (v) => s.autoSkipNextOnError = v,
            ),
            _Switch(
              icon: Icons.repeat_rounded,
              title: 'Remember shuffle & repeat',
              value: s.rememberShuffleAndRepeat,
              onChanged: (v) => s.rememberShuffleAndRepeat = v,
            ),
          ],
        ),
        _Group(
          children: [
            _Switch(
              icon: Icons.lyrics_outlined,
              title: 'Show lyrics on open',
              subtitle: 'Open the player in lyrics view',
              value: s.showLyricsOnPlayer,
              onChanged: (v) => s.showLyricsOnPlayer = v,
            ),
            _Row(
              icon: Icons.format_align_left_rounded,
              title: 'Lyrics alignment',
              subtitle:
                  s.lyricsTextPosition.name[0].toUpperCase() +
                  s.lyricsTextPosition.name.substring(1),
              onTap: () async {
                final v = await _pick(context, 'Lyrics alignment', const [
                  (LyricsTextPosition.left, 'Left'),
                  (LyricsTextPosition.center, 'Center'),
                  (LyricsTextPosition.right, 'Right'),
                ], s.lyricsTextPosition);
                if (v != null) s.lyricsTextPosition = v;
              },
            ),
            _Switch(
              icon: Icons.touch_app_outlined,
              title: 'Tap lyrics to seek',
              value: s.lyricsClickSeeks,
              onChanged: (v) => s.lyricsClickSeeks = v,
            ),
            _Switch(
              icon: Icons.bolt_rounded,
              title: 'BetterLyrics',
              subtitle: 'Word-synced lyrics',
              value: s.enableBetterLyrics,
              onChanged: (v) => s.enableBetterLyrics = v,
            ),
            _Switch(
              icon: Icons.apple_rounded,
              title: 'Paxsenix',
              subtitle: 'Apple Music synced lyrics engine',
              value: s.enablePaxsenix,
              onChanged: (v) => s.enablePaxsenix = v,
            ),
            _Switch(
              icon: Icons.lyrics_rounded,
              title: 'YouLyPlus',
              subtitle: 'Multi-mirror community lyrics',
              value: s.enableYouLyPlus,
              onChanged: (v) => s.enableYouLyPlus = v,
            ),
            _Switch(
              icon: Icons.library_music_outlined,
              title: 'LRCLIB',
              value: s.enableLrcLib,
              onChanged: (v) => s.enableLrcLib = v,
            ),
            _Switch(
              icon: Icons.translate_rounded,
              title: 'KuGou',
              value: s.enableKugou,
              onChanged: (v) => s.enableKugou = v,
            ),
            _Switch(
              icon: Icons.smart_display_outlined,
              title: 'YouTube lyrics',
              subtitle: 'Unsynced fallback',
              value: s.enableYouTubeLyrics,
              onChanged: (v) => s.enableYouTubeLyrics = v,
            ),
          ],
        ),
      ],
    );
  }
}

class ContentSettings extends StatelessWidget {
  const ContentSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    return _SettingsPage(
      title: 'Content',
      groups: [
        _Group(
          children: [
            _Switch(
              icon: Icons.explicit_rounded,
              title: 'Hide explicit content',
              value: s.hideExplicit,
              onChanged: (v) => s.hideExplicit = v,
            ),
            _Switch(
              icon: Icons.videocam_off_outlined,
              title: 'Hide video songs',
              value: s.hideVideoSongs,
              onChanged: (v) => s.hideVideoSongs = v,
            ),
            _Switch(
              icon: Icons.movie_filter_outlined,
              title: 'Hide YouTube Shorts',
              value: s.hideYoutubeShorts,
              onChanged: (v) => s.hideYoutubeShorts = v,
            ),
            _Row(
              icon: Icons.person_off_rounded,
              title: 'Blocked artists',
              subtitle: '${s.blockedArtists.length} artists blocked',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BlockedArtistsScreen(),
                ),
              ),
            ),
          ],
        ),
        _Group(
          children: [
            _Row(
              icon: Icons.language_rounded,
              title: 'Content language',
              subtitle: s.contentLanguage == 'system'
                  ? 'System default'
                  : s.contentLanguage,
              onTap: () async {
                final v = await _pick(context, 'Content language', const [
                  ('system', 'System default'),
                  ('en', 'English'),
                  ('es', 'Español'),
                  ('fr', 'Français'),
                  ('de', 'Deutsch'),
                  ('hi', 'हिन्दी'),
                  ('ja', '日本語'),
                  ('ko', '한국어'),
                  ('pt', 'Português'),
                  ('ru', 'Русский'),
                  ('ar', 'العربية'),
                  ('zh-CN', '中文'),
                ], s.contentLanguage);
                if (v != null) s.contentLanguage = v;
              },
            ),
            _Row(
              icon: Icons.public_rounded,
              title: 'Content country',
              subtitle: s.contentCountry == 'system'
                  ? 'System default'
                  : s.contentCountry,
              onTap: () async {
                final v = await _pick(context, 'Content country', const [
                  ('system', 'System default'),
                  ('US', 'United States'),
                  ('GB', 'United Kingdom'),
                  ('IN', 'India'),
                  ('DE', 'Germany'),
                  ('FR', 'France'),
                  ('JP', 'Japan'),
                  ('KR', 'Korea'),
                  ('BR', 'Brazil'),
                  ('CA', 'Canada'),
                  ('AU', 'Australia'),
                  ('MX', 'Mexico'),
                ], s.contentCountry);
                if (v != null) s.contentCountry = v;
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Language and country changes apply after restarting the app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        _Group(
          children: [
            _Switch(
              icon: Icons.sync_rounded,
              title: 'Sync with YouTube Music',
              subtitle: 'Likes, library and playlists',
              value: s.ytmSync,
              onChanged: (v) => s.ytmSync = v,
            ),
          ],
        ),
      ],
    );
  }
}

class PrivacySettings extends StatelessWidget {
  const PrivacySettings({super.key});

  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    return _SettingsPage(
      title: 'Privacy',
      groups: [
        _Group(
          children: [
            _Switch(
              icon: Icons.history_toggle_off_rounded,
              title: 'Pause listening history',
              subtitle: 'Stop recording plays on this device',
              value: s.pauseListenHistory,
              onChanged: (v) => s.pauseListenHistory = v,
            ),
            _Switch(
              icon: Icons.cloud_off_outlined,
              title: 'Pause YouTube Music history',
              subtitle: 'Do not report plays to your account',
              value: s.pauseRemoteListenHistory,
              onChanged: (v) => s.pauseRemoteListenHistory = v,
            ),
            _Switch(
              icon: Icons.search_off_rounded,
              title: 'Pause search history',
              value: s.pauseSearchHistory,
              onChanged: (v) => s.pauseSearchHistory = v,
            ),
          ],
        ),
        _Group(
          children: [
            _Row(
              icon: Icons.delete_sweep_outlined,
              title: 'Clear listening history',
              onTap: () async {
                await AppDatabase.instance.clearHistory();
                if (context.mounted) showSnack(context, 'History cleared');
              },
            ),
            _Row(
              icon: Icons.delete_outline_rounded,
              title: 'Clear search history',
              onTap: () async {
                await AppDatabase.instance.clearSearchHistory();
                if (context.mounted) {
                  showSnack(context, 'Search history cleared');
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class StorageSettings extends StatefulWidget {
  const StorageSettings({super.key});

  @override
  State<StorageSettings> createState() => _StorageSettingsState();
}

class _StorageSettingsState extends State<StorageSettings> {
  int _downloadBytes = 0;

  Future<void> _handleBackup(BuildContext context) async {
    try {
      final data = await AppDatabase.instance.exportBackup();
      data['settings'] = {
        'blockedArtists': Settings.instance.blockedArtists.toList(),
      };
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      Directory? dir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          dir = Directory(p.join(userProfile, 'Downloads'));
        }
      }
      dir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final file = File(p.join(dir.path, 'echo_music_backup_$timestamp.json'));
      await file.writeAsString(jsonStr, encoding: utf8);

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup Created'),
            content: Text('Library successfully backed up to:\n\n${file.path}'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showSnack(context, 'Backup failed: $e');
      }
    }
  }

  Future<void> _handleRestore(BuildContext context) async {
    final controller = TextEditingController();
    String? defaultPath;
    try {
      Directory? dir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) dir = Directory(p.join(userProfile, 'Downloads'));
      }
      dir ??= await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      if (await dir.exists()) {
        final list = dir.listSync().whereType<File>().where((f) => f.path.contains('echo_music_backup_')).toList();
        if (list.isNotEmpty) {
          list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          defaultPath = list.first.path;
        }
      }
    } catch (_) {}

    if (defaultPath != null) controller.text = defaultPath;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Library'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the full path to an Echo Music JSON backup file:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'C:\\Users\\...\\Downloads\\echo_music_backup.json',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final path = controller.text.trim();
              Navigator.of(ctx).pop();
              if (path.isEmpty) return;
              try {
                final file = File(path);
                if (!await file.exists()) {
                  if (context.mounted) showSnack(context, 'File not found: $path');
                  return;
                }
                final raw = await file.readAsString(encoding: utf8);
                final map = jsonDecode(raw) as Map<String, dynamic>;
                final count = await AppDatabase.instance.importBackup(map);
                if (map['settings'] is Map) {
                  final s = map['settings'] as Map<String, dynamic>;
                  final blocked = s['blockedArtists'] as List?;
                  if (blocked != null) {
                    for (final b in blocked) {
                      await Settings.instance.blockArtist(b.toString());
                    }
                  }
                }
                if (context.mounted) {
                  showSnack(context, 'Library restored ($count items)');
                }
              } catch (e) {
                if (context.mounted) showSnack(context, 'Restore error: $e');
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    AppDatabase.instance.totalDownloadBytes().then((b) {
      if (mounted) setState(() => _downloadBytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Storage',
      groups: [
        _Group(
          children: [
            _Row(
              icon: Icons.backup_outlined,
              title: 'Backup library',
              subtitle: 'Export playlists, songs, favorites & settings to JSON',
              onTap: () => _handleBackup(context),
            ),
            _Row(
              icon: Icons.restore_outlined,
              title: 'Restore library',
              subtitle: 'Import a previously saved .json backup file',
              onTap: () => _handleRestore(context),
            ),
          ],
        ),
        _Group(
          children: [
            _Row(
              icon: Icons.offline_pin_outlined,
              title: 'Downloaded songs',
              subtitle: formatBytes(_downloadBytes),
              trailing: TextButton(
                onPressed: () async {
                  await DownloadManager.instance.removeAll();
                  if (mounted) setState(() => _downloadBytes = 0);
                },
                child: const Text('Clear'),
              ),
            ),
            _Row(
              icon: Icons.image_outlined,
              title: 'Image cache',
              subtitle: 'Album art and thumbnails',
              trailing: TextButton(
                onPressed: () async {
                  await DefaultCacheManager().emptyCache();
                  if (context.mounted) {
                    showSnack(context, 'Image cache cleared');
                  }
                },
                child: const Text('Clear'),
              ),
            ),
            _Row(
              icon: Icons.link_off_rounded,
              title: 'Stream URL cache',
              subtitle: 'Resolved playback links',
              trailing: TextButton(
                onPressed: () {
                  StreamResolver.instance.clearCache();
                  showSnack(context, 'Stream cache cleared');
                },
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          EchoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 56,
                        height: 56,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Echo Music',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'iOS port • Flutter',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'A modern music app with ad-free streaming from YouTube Music, synced lyrics and offline playback. '
                  'This is the Flutter port of the Android app, built for iOS.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Group(
            children: [
              _Row(
                icon: Icons.code_rounded,
                title: 'Source code',
                subtitle: 'github.com/iad1tya/Echo-Music',
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/iad1tya/Echo-Music'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _Row(
                icon: Icons.discord,
                title: 'Discord',
                subtitle: 'Join the community',
                onTap: () => launchUrl(
                  Uri.parse('https://discord.gg/Xt5hgsJJuA'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _Row(
                icon: Icons.policy_outlined,
                title: 'Licence',
                subtitle: 'GPL-3.0',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Special thanks: Metrolist, InnerTune, SimpMusic, ViMusic, OuterTune — the InnerTube parsing, lyrics providers and queue logic are ported from the Echo Music Android codebase which builds on their work.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class IntegrationsSettings extends StatefulWidget {
  const IntegrationsSettings({super.key});

  @override
  State<IntegrationsSettings> createState() => _IntegrationsSettingsState();
}

class _IntegrationsSettingsState extends State<IntegrationsSettings> {
  @override
  Widget build(BuildContext context) {
    final s = Settings.instance;
    return _SettingsPage(
      title: 'Integrations & Social',
      groups: [
        _Group(
          title: 'DISCORD',
          children: [
            _Switch(
              icon: Icons.games_rounded,
              title: 'Discord Rich Presence',
              subtitle:
                  'Display song, artist, and album artwork on your Discord profile',
              value: s.enableDiscordRpc,
              onChanged: (v) {
                setState(() => s.enableDiscordRpc = v);
              },
            ),
          ],
        ),
        _Group(
          title: 'SCROBBLING',
          children: [
            _Switch(
              icon: Icons.radio_rounded,
              title: 'Last.fm Scrobbler',
              subtitle: s.lastFmSessionKey.isNotEmpty
                  ? 'Connected as ${s.lastFmUsername.isNotEmpty ? s.lastFmUsername : "User"}'
                  : 'Scrobble plays to Last.fm',
              value: s.enableLastFm,
              onChanged: (v) {
                setState(() => s.enableLastFm = v);
              },
            ),
            _Row(
              icon: Icons.key_rounded,
              title: 'Last.fm Credentials',
              subtitle: s.lastFmSessionKey.isNotEmpty
                  ? 'Tap to update credentials'
                  : 'Configure API key & Session key',
              onTap: _showLastFmDialog,
            ),
            _Switch(
              icon: Icons.graphic_eq_rounded,
              title: 'ListenBrainz Scrobbler',
              subtitle: s.listenBrainzToken.isNotEmpty
                  ? 'User token active'
                  : 'Open-source scrobbling to MetaBrainz',
              value: s.enableListenBrainz,
              onChanged: (v) {
                setState(() => s.enableListenBrainz = v);
              },
            ),
            _Row(
              icon: Icons.token_rounded,
              title: 'ListenBrainz User Token',
              subtitle: s.listenBrainzToken.isNotEmpty
                  ? '••••••••••••'
                  : 'Enter user token',
              onTap: _showListenBrainzDialog,
            ),
          ],
        ),
        _Group(
          title: 'PLAYLIST TOOLS',
          children: [
            _Row(
              icon: Icons.sync_alt_rounded,
              title: 'Import from Spotify',
              subtitle: 'Mirror public Spotify playlists into your library',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SpotifyImportScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLastFmDialog() {
    final s = Settings.instance;
    final userCtrl = TextEditingController(text: s.lastFmUsername);
    final keyCtrl = TextEditingController(text: s.lastFmApiKey);
    final secretCtrl = TextEditingController(text: s.lastFmApiSecret);
    final skCtrl = TextEditingController(text: s.lastFmSessionKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Last.fm Credentials'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userCtrl,
                decoration: const InputDecoration(labelText: 'Last.fm Username'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyCtrl,
                decoration: const InputDecoration(labelText: 'API Key'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: secretCtrl,
                decoration: const InputDecoration(labelText: 'API Secret'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: skCtrl,
                decoration: const InputDecoration(labelText: 'Session Key (sk)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              s.lastFmUsername = userCtrl.text.trim();
              s.lastFmApiKey = keyCtrl.text.trim();
              s.lastFmApiSecret = secretCtrl.text.trim();
              s.lastFmSessionKey = skCtrl.text.trim();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showListenBrainzDialog() {
    final s = Settings.instance;
    final tokenCtrl = TextEditingController(text: s.listenBrainzToken);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ListenBrainz User Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Get your User Token from listenbrainz.org/profile to scrobble plays automatically.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              decoration: const InputDecoration(
                labelText: 'User Token',
                hintText: 'Paste token here',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              s.listenBrainzToken = tokenCtrl.text.trim();
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
