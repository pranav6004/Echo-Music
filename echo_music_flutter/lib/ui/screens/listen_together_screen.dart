import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/listen_together_service.dart';
import '../shell/app_navigator.dart';

class ListenTogetherScreen extends StatefulWidget {
  const ListenTogetherScreen({super.key});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  final _usernameController = TextEditingController();
  final _roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _usernameController.text = ListenTogetherService.instance.username;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _roomCodeController.dispose();
    super.dispose();
  }

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    } else {
      AppNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => _handleBack(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Party Rooms'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Back',
              onPressed: () => _handleBack(context),
            ),
            actions: [
              AnimatedBuilder(
                animation: ListenTogetherService.instance,
                builder: (context, _) {
                  final svc = ListenTogetherService.instance;
                  if (svc.isConnected && svc.roomCode != null) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: FilledButton.tonalIcon(
                        onPressed: () => svc.leaveRoom(),
                        icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                        label: const Text('Leave Room'),
                        style: FilledButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                          backgroundColor:
                              theme.colorScheme.errorContainer.withOpacity(0.4),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          body: AnimatedBuilder(
            animation: ListenTogetherService.instance,
            builder: (context, _) {
              final svc = ListenTogetherService.instance;
              final isInRoom = svc.isConnected && svc.roomCode != null;

              return CustomScrollView(
                slivers: [
                  // Header Banner
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.arrow_back_rounded, size: 20),
                            tooltip: 'Back',
                            onPressed: () => _handleBack(context),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purpleAccent.shade400,
                                  Colors.deepPurple.shade600,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purpleAccent.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.podcasts_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Party Rooms',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Listen together in real-time with zero audio latency',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isInRoom)
                            FilledButton.tonalIcon(
                              onPressed: () => svc.leaveRoom(),
                              icon: const Icon(Icons.exit_to_app_rounded, size: 18),
                              label: const Text('Leave Room'),
                              style: FilledButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                                backgroundColor:
                                    theme.colorScheme.errorContainer.withOpacity(0.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Status message bar if any
                  if (svc.statusMessage != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                svc.isConnecting
                                    ? Icons.sync_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  svc.statusMessage!,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              if (svc.isConnecting)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Main Body Content
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 48),
                    sliver: isInRoom
                        ? SliverToBoxAdapter(
                            child: _buildActiveRoomView(context, svc, theme))
                        : SliverToBoxAdapter(
                            child: _buildLobbyView(
                                context, svc, theme, isDark)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLobbyView(
    BuildContext context,
    ListenTogetherService svc,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username setting
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                child: Icon(Icons.person_rounded),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Your Display Name',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => svc.setUsername(val),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2-Card action grid
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final cards = [
              // Create room card
              _buildActionCard(
                theme: theme,
                title: 'Host a Room',
                subtitle:
                    'Generate a unique room code and control playback for all listeners.',
                icon: Icons.add_circle_outline_rounded,
                iconColor: Colors.purpleAccent,
                buttonLabel: 'Create Room',
                buttonIcon: Icons.rocket_launch_rounded,
                isLoading: svc.isConnecting,
                onPressed: () {
                  svc.setUsername(_usernameController.text);
                  svc.createRoom();
                },
              ),

              // Join room card
              _buildActionCard(
                theme: theme,
                title: 'Join a Room',
                subtitle:
                    'Enter a 6-character room code to sync playback with a friend.',
                icon: Icons.group_add_rounded,
                iconColor: Colors.blueAccent,
                buttonLabel: 'Join Session',
                buttonIcon: Icons.login_rounded,
                isLoading: svc.isConnecting,
                customInput: TextField(
                  controller: _roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ROOM CODE',
                    hintStyle: TextStyle(
                      letterSpacing: 2,
                      color:
                          theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: theme.colorScheme.outlineVariant
                              .withOpacity(0.5)),
                    ),
                  ),
                ),
                onPressed: () {
                  final code = _roomCodeController.text.trim();
                  if (code.isNotEmpty) {
                    svc.setUsername(_usernameController.text);
                    svc.joinRoom(code);
                  }
                },
              ),
            ];

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 20),
                  Expanded(child: cards[1]),
                ],
              );
            } else {
              return Column(
                children: [
                  cards[0],
                  const SizedBox(height: 20),
                  cards[1],
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required ThemeData theme,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
    Widget? customInput,
    bool isLoading = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: theme.colorScheme.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          if (customInput != null) ...[
            const SizedBox(height: 20),
            customInput,
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isLoading ? null : onPressed,
              icon: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(buttonIcon, size: 18),
              label: Text(buttonLabel),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRoomView(
    BuildContext context,
    ListenTogetherService svc,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Room Code Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.purple.shade900.withOpacity(0.6),
                Colors.deepPurple.shade900.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: Colors.purpleAccent.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: svc.isHost
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: svc.isHost ? Colors.amber : Colors.blueAccent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          svc.isHost ? Icons.star_rounded : Icons.sync_rounded,
                          size: 14,
                          color: svc.isHost ? Colors.amber : Colors.blueAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          svc.isHost ? 'HOST' : 'GUEST',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: svc.isHost ? Colors.amber : Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'ROOM CODE',
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: 2,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                svc.roomCode ?? '',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  if (svc.roomCode != null) {
                    Clipboard.setData(ClipboardData(text: svc.roomCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Room code copied to clipboard!')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy Code'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white30),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Synced Track Card (if active)
        if (svc.currentTrack != null) ...[
          Text(
            'NOW PLAYING IN ROOM',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: svc.currentTrack!.thumbnail != null
                      ? CachedNetworkImage(
                          imageUrl: svc.currentTrack!.thumbnail!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade900,
                            child: const Icon(Icons.music_note_rounded),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: Colors.grey.shade900,
                          child: const Icon(Icons.music_note_rounded),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        svc.currentTrack!.title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        svc.currentTrack!.artist,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  svc.isPlaying
                      ? Icons.play_circle_filled_rounded
                      : Icons.pause_circle_filled_rounded,
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],

        // Members List
        Text(
          'CONNECTED MEMBERS (${svc.members.length})',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: svc.members.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withOpacity(0.2),
            ),
            itemBuilder: (context, idx) {
              final m = svc.members[idx];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: m.isHost
                      ? Colors.amber.withOpacity(0.2)
                      : theme.colorScheme.primaryContainer,
                  child: Text(
                    m.username.isNotEmpty ? m.username[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          m.isHost ? Colors.amber : theme.colorScheme.primary,
                    ),
                  ),
                ),
                title: Text(
                  m.username,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                trailing: m.isHost
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'HOST',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
