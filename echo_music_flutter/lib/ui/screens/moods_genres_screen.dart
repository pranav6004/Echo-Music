import 'package:flutter/material.dart';

import '../../innertube/models/yt_item.dart';
import '../../innertube/youtube.dart';
import '../shell/app_navigator.dart';
import 'browse_screen.dart';

class MoodsAndGenresScreen extends StatefulWidget {
  const MoodsAndGenresScreen({super.key});

  @override
  State<MoodsAndGenresScreen> createState() => _MoodsAndGenresScreenState();
}

class _MoodsAndGenresScreenState extends State<MoodsAndGenresScreen> {
  List<MoodAndGenres>? _items;
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
      final items = await YouTube.instance.moodAndGenres();
      if (mounted) {
        setState(() {
          _items = items;
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

  static const List<List<Color>> _cardGradients = [
    [Color(0xFF8E2DE2), Color(0xFF4A00E0)], // Purple
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Green
    [Color(0xFFFF416C), Color(0xFFFF4B2B)], // Coral
    [Color(0xFF2193B0), Color(0xFF6DD5ED)], // Cyan
    [Color(0xFFF7971E), Color(0xFFFFD200)], // Gold
    [Color(0xFFE55D87), Color(0xFF5FC3E4)], // Pink blue
    [Color(0xFF00B4DB), Color(0xFF0083B0)], // Deep ocean
    [Color(0xFF7F00FF), Color(0xFFE100FF)], // Violet
    [Color(0xFFB993D6), Color(0xFF8CA6DB)], // Lavender
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Crimson
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moods & Genres'),
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
                      Text('Failed to load moods & genres: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(context, theme, scheme),
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme, ColorScheme scheme) {
    final groups = _items ?? [];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1200
            ? 4
            : width >= 800
                ? 3
                : width >= 500
                    ? 2
                    : 1;

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: groups.length,
          itemBuilder: (context, groupIdx) {
            final group = groups[groupIdx];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 12),
                  child: Text(
                    group.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 2.8,
                  ),
                  itemCount: group.items.length,
                  itemBuilder: (context, itemIdx) {
                    final item = group.items[itemIdx];
                    final gradient = _cardGradients[
                        (groupIdx * 3 + itemIdx) % _cardGradients.length];
                    return Material(
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          AppNavigator.push(
                            BrowseScreen(
                              endpoint: item.endpoint,
                              title: item.title,
                            ),
                          );
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}


/// Backward compatibility alias
typedef MoodsScreen = MoodsAndGenresScreen;
