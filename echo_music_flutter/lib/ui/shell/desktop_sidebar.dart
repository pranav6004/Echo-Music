import '../screens/account_screen.dart';
import 'package:flutter/material.dart';

import '../../data/settings.dart';
import '../../innertube/youtube.dart';
import '../components/thumbnail.dart';
import 'app_navigator.dart';

/// Desktop Navigation Sidebar adhering to Spotify / Linear desktop specifications:
/// clean vertical hierarchy, 10px rounded hover pills, quick library access,
/// and bottom user profile dock.
class DesktopSidebar extends StatelessWidget {
  final int currentTab;
  final ValueChanged<int> onSelectTab;

  const DesktopSidebar({
    super.key,
    required this.currentTab,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Echo Music',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Primary Navigation Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                _SidebarNavTile(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: currentTab == 0,
                  onTap: () => onSelectTab(0),
                ),
                _SidebarNavTile(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  label: 'Explore',
                  isSelected: currentTab == 1,
                  onTap: () => onSelectTab(1),
                ),
                _SidebarNavTile(
                  icon: Icons.library_music_outlined,
                  activeIcon: Icons.library_music_rounded,
                  label: 'Library',
                  isSelected: currentTab == 2,
                  onTap: () => onSelectTab(2),
                ),
                _SidebarNavTile(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search_rounded,
                  label: 'Search',
                  isSelected: currentTab == 3,
                  onTap: () => onSelectTab(3),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.15),
              height: 1,
            ),
          ),

          const SizedBox(height: 12),

          // Library & Shortcuts Heading
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 20, 8),
            child: Text(
              'MY MUSIC',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ),

          // Quick Library Shortcuts
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  _SidebarShortcutTile(
                    icon: Icons.favorite_rounded,
                    iconColor: Colors.redAccent,
                    label: 'Liked Songs',
                    onTap: AppNavigator.openLikedSongs,
                  ),
                  _SidebarShortcutTile(
                    icon: Icons.download_done_rounded,
                    iconColor: Colors.tealAccent,
                    label: 'Downloaded',
                    onTap: AppNavigator.openDownloaded,
                  ),
                  _SidebarShortcutTile(
                    icon: Icons.history_rounded,
                    iconColor: Colors.amberAccent,
                    label: 'History',
                    onTap: AppNavigator.openHistory,
                  ),
                  _SidebarShortcutTile(
                    icon: Icons.trending_up_rounded,
                    iconColor: Colors.deepPurpleAccent,
                    label: 'Top Tracks',
                    onTap: AppNavigator.openTopSongs,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Account & Settings Dock
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
            ),
            child: ListenableBuilder(
              listenable: Settings.instance,
              builder: (context, _) {
                final settings = Settings.instance;
                final isLoggedIn = settings.isLoggedIn;
                return Row(
                  children: [
                    InkWell(
                      onTap: () => isLoggedIn
                          ? AppNavigator.push(const AccountScreen())
                          : AppNavigator.openLogin(),
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        children: [
                          if (isLoggedIn && settings.accountAvatarUrl.isNotEmpty)
                            EchoImage(
                              url: settings.accountAvatarUrl,
                              width: 32,
                              height: 32,
                              radius: 16,
                              circle: true,
                            )
                          else
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.surfaceContainerHighest,
                              child: Icon(
                                isLoggedIn
                                    ? Icons.person_rounded
                                    : Icons.login_rounded,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 108),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isLoggedIn
                                      ? (settings.accountName.isNotEmpty ? settings.accountName : 'Account')
                                      : 'Sign in',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (isLoggedIn && settings.accountChannelHandle.isNotEmpty)
                                  Text(
                                    settings.accountChannelHandle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, size: 20),
                      tooltip: 'Settings',
                      onPressed: AppNavigator.openSettings,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarNavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarNavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: isSelected
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.75)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSelected ? activeIcon : icon,
                  size: 20,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarShortcutTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SidebarShortcutTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

