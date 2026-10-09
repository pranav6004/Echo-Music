import 'package:flutter/material.dart';

import '../../data/settings.dart';

class BlockedArtistsScreen extends StatefulWidget {
  const BlockedArtistsScreen({super.key});

  @override
  State<BlockedArtistsScreen> createState() => _BlockedArtistsScreenState();
}

class _BlockedArtistsScreenState extends State<BlockedArtistsScreen> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Artist'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the artist name to prevent them from appearing in queues, radios, and recommendations.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Artist name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) async {
                final name = val.trim();
                if (name.isNotEmpty) {
                  await Settings.instance.blockArtist(name);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }
              },
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
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await Settings.instance.blockArtist(name);
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final settings = Settings.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Artists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Block artist',
            onPressed: () => _showAddDialog(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final allBlocked = settings.blockedArtists.toList()..sort();
          final filtered = allBlocked
              .where((a) => a.toLowerCase().contains(_filter.toLowerCase()))
              .toList();

          if (allBlocked.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.block_flipped,
                      size: 64,
                      color: scheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No blocked artists',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Artists you block won\'t appear in autoplay queues or smart recommendations.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Block an artist'),
                      onPressed: () => _showAddDialog(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search blocked artists (${allBlocked.length})...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _filter = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) => setState(() => _filter = val),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final artist = filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.errorContainer,
                        foregroundColor: scheme.onErrorContainer,
                        child: const Icon(Icons.person_off_rounded, size: 20),
                      ),
                      title: Text(
                        artist,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Unblock'),
                        onPressed: () async {
                          await settings.unblockArtist(artist);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Unblocked $artist')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
