import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme.dart';
import 'data/settings.dart';
import 'ui/screens/account_screen.dart';
import 'ui/screens/login_screen.dart';
import 'ui/shell/app_navigator.dart';
import 'ui/shell/main_shell.dart';

class ResonaScrollBehavior extends MaterialScrollBehavior {
  const ResonaScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class ResonaApp extends StatefulWidget {
  const ResonaApp({super.key});

  @override
  State<ResonaApp> createState() => _ResonaAppState();
}

class _ResonaAppState extends State<ResonaApp> {
  @override
  void initState() {
    super.initState();
    loginScreenBuilder = () => const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Settings.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final mode = switch (settings.darkMode) {
          DarkModePref.auto => ThemeMode.system,
          DarkModePref.on => ThemeMode.dark,
          DarkModePref.off => ThemeMode.light,
        };
        return MaterialApp(
          title: 'Resona',
          debugShowCheckedModeBanner: false,
          scrollBehavior: const ResonaScrollBehavior(),
          navigatorKey: AppNavigator.rootKey,
          theme: ResonaTheme.build(
            brightness: Brightness.light,
            settings: settings,
          ),
          darkTheme: ResonaTheme.build(
            brightness: Brightness.dark,
            settings: settings,
          ),
          themeMode: mode,
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            SystemChrome.setSystemUIOverlayStyle(
              dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
            );
            return child!;
          },
          home: MainShell(initialTab: settings.defaultTab.index),
        );
      },
    );
  }
}
