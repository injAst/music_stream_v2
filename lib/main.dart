import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/router/app_router.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/track_repository.dart';
import 'providers/audio_player_controller.dart';
import 'providers/auth_controller.dart';
import 'providers/library_controller.dart';
import 'providers/navigation_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final authRepo = AuthRepository(prefs);
  final trackRepo = TrackRepository(prefs);
  final auth = AuthController(authRepo);
  await auth.init();
  final router = createAppRouter(auth);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepo),
        Provider<TrackRepository>.value(value: trackRepo),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider(
          create: (_) => AudioPlayerController(),
        ),
        ChangeNotifierProvider(
          create: (c) => LibraryController(c.read<TrackRepository>())..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationController(),
        ),
      ],
      child: PulseMusicApp(router: router),
    ),
  );
}
