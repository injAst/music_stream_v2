import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/tracks/add_track_screen.dart';
import '../../providers/auth_controller.dart';

GoRouter createAppRouter(AuthController auth) {
  return GoRouter(
    initialLocation: auth.isLoggedIn ? '/home' : '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final atAuth = loc == '/login' || loc == '/register';
      if (!auth.isLoggedIn && !atAuth) return '/login';
      if (auth.isLoggedIn && atAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (_, __) => const HomeShell(),
      ),
      GoRoute(
        path: '/add-track',
        builder: (_, __) => const AddTrackScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/:id',
        builder: (_, state) => UserProfileScreen(
          userId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
}
