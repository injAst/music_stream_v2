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
import 'providers/playlist_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final authRepo = AuthRepository(prefs);
  final trackRepo = TrackRepository(prefs);
  final auth = AuthController(authRepo);
  await auth.init();
  final lib = LibraryController(trackRepo)..load();
  final audioPlayer = AudioPlayerController(prefs);
  auth.setLibrary(lib);
  auth.setAudioPlayer(audioPlayer);
  audioPlayer.setAuthRepo(authRepo);
  
  final router = createAppRouter(auth);

  runApp(
    MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepo),
        Provider<TrackRepository>.value(value: trackRepo),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<LibraryController>.value(value: lib),
        ChangeNotifierProvider<AudioPlayerController>.value(value: audioPlayer),
        ChangeNotifierProxyProvider<LibraryController, AudioPlayerController>(
          create: (_) => audioPlayer,
          update: (_, library, player) => (player ?? audioPlayer)..setLibrary(library),
        ),
        ChangeNotifierProvider(
          create: (_) => NavigationController(),
        ),
        ChangeNotifierProxyProvider<AuthController, PlaylistController>(
          create: (context) => PlaylistController(auth: context.read<AuthController>()),
          update: (context, auth, previous) => PlaylistController(auth: auth),
        ),
      ],
      child: PulseMusicApp(router: router),
    ),
  );
}
