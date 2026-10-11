import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/config/env_config.dart';
import 'core/error/app_failure.dart';
import 'core/theme/anni_theme.dart';
import 'data/local/local_database.dart';
import 'data/providers/app_providers.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/downloads_screen.dart';
import 'presentation/screens/equalizer_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/library_screen.dart';
import 'presentation/screens/main_shell_screen.dart';
import 'presentation/screens/now_playing_screen.dart';
import 'presentation/screens/search_screen.dart';
import 'presentation/screens/settings_profile_screen.dart';
import 'presentation/screens/splash_onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter & Platform Error Boundaries
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'FlutterError caught by global boundary',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error(
      'Uncaught platform error caught by global boundary',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  // 2. Edge-to-edge system UI styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AnniTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 3. Initialize LocalDatabase & Background AudioService Handler
  final LocalDatabase localDb = LocalDatabase();
  await localDb.initialize();

  late final AnniAudioPlayerHandler audioHandler;
  try {
    audioHandler = await AudioService.init<AnniAudioPlayerHandler>(
      builder: () => AnniAudioPlayerHandler(localDatabase: localDb),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.anni.music.channel.audio',
        androidNotificationChannelName: 'Anni Music Playback',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (e) {
    AppLogger.warn('AudioService fallback handler initialized', error: e);
    audioHandler = AnniAudioPlayerHandler(localDatabase: localDb);
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        localDatabaseProvider.overrideWithValue(localDb),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const AnniMusicApp(),
    ),
  );
}

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

/// Declarative GoRouter configuration for Anni Music.
final GoRouter anniRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const SplashOnboardingScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (BuildContext context, GoRouterState state) =>
          const AuthScreen(),
    ),
    GoRoute(
      path: '/now-playing',
      parentNavigatorKey: _rootNavigatorKey,
      pageBuilder: (BuildContext context, GoRouterState state) {
        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: const NowPlayingScreen(),
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<Offset> offset = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return SlideTransition(position: offset, child: child);
          },
        );
      },
    ),
    GoRoute(
      path: '/equalizer',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (BuildContext context, GoRouterState state) =>
          const EqualizerScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (
        BuildContext context,
        GoRouterState state,
        StatefulNavigationShell navigationShell,
      ) {
        return MainShellScreen(navigationShell: navigationShell);
      },
      branches: <StatefulShellBranch>[
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/home',
              builder: (BuildContext context, GoRouterState state) =>
                  const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/search',
              builder: (BuildContext context, GoRouterState state) =>
                  const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/library',
              builder: (BuildContext context, GoRouterState state) =>
                  const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/downloads',
              builder: (BuildContext context, GoRouterState state) =>
                  const DownloadsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: <RouteBase>[
            GoRoute(
              path: '/settings',
              builder: (BuildContext context, GoRouterState state) =>
                  const SettingsProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Root application widget reactive to UserSettingsEntity theme mode
/// (`'dark'` Obsidian `#07070A`, `'amoled'` `#000000`, or `'light'` Daylight).
class AnniMusicApp extends ConsumerWidget {
  const AnniMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final UserSettingsEntity settings = ref.watch(userSettingsProvider);

    return MaterialApp.router(
      title: EnvConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AnniTheme.lightTheme(),
      darkTheme: AnniTheme.darkTheme(settings.isAmoled),
      themeMode: settings.isLight ? ThemeMode.light : ThemeMode.dark,
      routerConfig: anniRouter,
    );
  }
}
