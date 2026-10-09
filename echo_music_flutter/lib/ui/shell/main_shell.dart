import 'package:flutter/material.dart';

import '../../playback/media_metadata.dart';
import '../../playback/player_controller.dart';
import '../player/desktop_player_bar.dart';
import '../player/full_player.dart';
import '../player/mini_player.dart';
import '../screens/explore_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/search_screen.dart';
import 'app_navigator.dart';
import 'desktop_sidebar.dart';
import 'desktop_side_panel.dart';
import 'floating_nav_bar.dart';

/// Root layout with adaptive responsiveness:
/// - Desktop (>= 800px): Persistent left navigation sidebar, center content canvas,
///   optional right side panel for Lyrics/Queue, and docked bottom desktop player bar with volume.
/// - Mobile (< 800px): Fluid tab navigators + floating pill nav bar + mini player overlay.
class MainShell extends StatefulWidget {
  final int initialTab;
  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _playerAnim;
  double _dragStart = 0;
  DesktopPanelType? _desktopPanel;

  static const double desktopBreakpoint = 800;
  static const double desktopPlayerHeight = 84;
  static const double navBarHeight = 64;
  static const double miniPlayerHeight = 64;

  @override
  void initState() {
    super.initState();
    AppNavigator.currentTab.value = widget.initialTab;
    _playerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    AppNavigator.playerExpanded.addListener(_onPlayerExpandedChanged);
    AppNavigator.currentTab.addListener(_rebuild);
    AppNavigator.queueRequested.addListener(_onQueueRequested);
  }

  void _rebuild() => setState(() {});

  void _onPlayerExpandedChanged() {
    if (AppNavigator.playerExpanded.value) {
      _playerAnim.animateTo(1, curve: Curves.easeOutCubic);
    } else {
      _playerAnim.animateTo(0, curve: Curves.easeInCubic);
    }
  }

  void _onQueueRequested() {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) {
      setState(() => _desktopPanel = DesktopPanelType.queue);
    }
  }

  @override
  void dispose() {
    AppNavigator.playerExpanded.removeListener(_onPlayerExpandedChanged);
    AppNavigator.currentTab.removeListener(_rebuild);
    AppNavigator.queueRequested.removeListener(_onQueueRequested);
    _playerAnim.dispose();
    super.dispose();
  }

  void _onTab(int i) {
    if (AppNavigator.currentTab.value == i) {
      AppNavigator.popToRoot();
    } else {
      AppNavigator.currentTab.value = i;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tab = AppNavigator.currentTab.value;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenSize = MediaQuery.sizeOf(context);
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isDesktop = screenWidth >= desktopBreakpoint;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (AppNavigator.playerExpanded.value) {
          AppNavigator.closePlayer();
          return;
        }
        final nav = AppNavigator.tabKeys[tab].currentState;
        if (nav != null && nav.canPop()) nav.pop();
      },
      child: Scaffold(
        extendBody: !isDesktop,
        body: ValueListenableBuilder<MediaMetadata?>(
          valueListenable: player.handler.currentMetadata,
          builder: (context, meta, _) {
            final hasPlayer = meta != null;

            if (isDesktop) {
              // -------------------------------------------------------------
              // DESKTOP LAYOUT (>= 800px): Sidebar + Content + Side Panel + Player Bar
              // -------------------------------------------------------------
              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Left Navigation Sidebar
                            DesktopSidebar(
                              currentTab: tab,
                              onSelectTab: _onTab,
                            ),

                            // Main Content Area
                            Expanded(
                              child: ClipRect(
                                child: IndexedStack(
                                  index: tab,
                                  children: [
                                    _TabNavigator(
                                      navKey: AppNavigator.tabKeys[0],
                                      child: const HomeScreen(),
                                    ),
                                    _TabNavigator(
                                      navKey: AppNavigator.tabKeys[1],
                                      child: const ExploreScreen(),
                                    ),
                                    _TabNavigator(
                                      navKey: AppNavigator.tabKeys[2],
                                      child: const LibraryScreen(),
                                    ),
                                    _TabNavigator(
                                      navKey: AppNavigator.tabKeys[3],
                                      child: const SearchScreen(),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Optional Collapsible Right Side Panel (Lyrics or Queue)
                            if (_desktopPanel != null)
                              DesktopSidePanel(
                                type: _desktopPanel!,
                                onClose: () => setState(() => _desktopPanel = null),
                              ),
                          ],
                        ),
                      ),

                      // Docked Bottom Desktop Player Bar
                      DesktopPlayerBar(
                        height: desktopPlayerHeight,
                        isLyricsOpen: _desktopPanel == DesktopPanelType.lyrics,
                        isQueueOpen: _desktopPanel == DesktopPanelType.queue,
                        onToggleLyrics: () {
                          setState(() {
                            _desktopPanel = _desktopPanel == DesktopPanelType.lyrics
                                ? null
                                : DesktopPanelType.lyrics;
                          });
                        },
                        onToggleQueue: () {
                          setState(() {
                            _desktopPanel = _desktopPanel == DesktopPanelType.queue
                                ? null
                                : DesktopPanelType.queue;
                          });
                        },
                      ),
                    ],
                  ),

                  // Full Player Overlay (when maximized)
                  if (hasPlayer) _buildFullPlayerOverlay(screenHeight),
                ],
              );
            }

            // ---------------------------------------------------------------
            // MOBILE COMPACT LAYOUT (< 800px): Floating Nav Bar + Mini Player
            // ---------------------------------------------------------------
            final reserved = navBarHeight +
                24 +
                (hasPlayer ? miniPlayerHeight + 8 : 0) +
                bottomInset;

            return Stack(
              children: [
                // Tab content with bottom padding for floating bar
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    padding: MediaQuery.paddingOf(context).copyWith(bottom: reserved),
                    viewPadding: MediaQuery.viewPaddingOf(context).copyWith(bottom: reserved),
                  ),
                  child: IndexedStack(
                    index: tab,
                    children: [
                      _TabNavigator(
                        navKey: AppNavigator.tabKeys[0],
                        child: const HomeScreen(),
                      ),
                      _TabNavigator(
                        navKey: AppNavigator.tabKeys[1],
                        child: const ExploreScreen(),
                      ),
                      _TabNavigator(
                        navKey: AppNavigator.tabKeys[2],
                        child: const LibraryScreen(),
                      ),
                      _TabNavigator(
                        navKey: AppNavigator.tabKeys[3],
                        child: const SearchScreen(),
                      ),
                    ],
                  ),
                ),

                // Bottom chrome: mini player + floating nav bar
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _playerAnim,
                    builder: (context, child) => Opacity(
                      opacity: (1 - _playerAnim.value * 2).clamp(0, 1),
                      child: IgnorePointer(
                        ignoring: _playerAnim.value > 0.3,
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: bottomInset + 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (hasPlayer)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: MiniPlayer(
                                height: miniPlayerHeight,
                                onTap: AppNavigator.openPlayer,
                                onDragUp: AppNavigator.openPlayer,
                              ),
                            ),
                          FloatingNavBar(
                            currentIndex: tab,
                            searchSelected: tab == 3,
                            onTap: _onTab,
                            onSearch: () => _onTab(3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Full player overlay
                if (hasPlayer) _buildFullPlayerOverlay(screenHeight),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullPlayerOverlay(double screenHeight) {
    return AnimatedBuilder(
      animation: _playerAnim,
      builder: (context, child) {
        final v = _playerAnim.value;
        if (v == 0) return const SizedBox.shrink();
        return Positioned(
          left: 0,
          right: 0,
          top: screenHeight * (1 - v),
          height: screenHeight,
          child: Opacity(opacity: v.clamp(0, 1), child: child),
        );
      },
      child: GestureDetector(
        onVerticalDragStart: (d) => _dragStart = d.globalPosition.dy,
        onVerticalDragUpdate: (d) {
          final delta = (d.globalPosition.dy - _dragStart) / screenHeight;
          if (delta > 0) {
            _playerAnim.value = (1 - delta).clamp(0, 1);
          }
        },
        onVerticalDragEnd: (d) {
          final fling = d.primaryVelocity != null && d.primaryVelocity! > 600;
          if (fling || _playerAnim.value < 0.7) {
            AppNavigator.playerExpanded.value = false;
            _playerAnim.animateTo(0, curve: Curves.easeInCubic);
          } else {
            _playerAnim.animateTo(1, curve: Curves.easeOutCubic);
          }
        },
        child: const FullPlayer(),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navKey;
  final Widget child;
  const _TabNavigator({required this.navKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navKey,
      onGenerateRoute: (settings) =>
          MaterialPageRoute(builder: (_) => child, settings: settings),
    );
  }
}
