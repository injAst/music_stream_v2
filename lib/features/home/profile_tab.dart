import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_controller.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthController>(
        builder: (context, auth, _) {
          final u = auth.user;
          if (u == null) {
            return const Center(child: Text('Нет профиля'));
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: const Text('Профиль'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _Avatar(url: u.avatarUrl, name: u.displayName),
                      const SizedBox(height: 20),
                      Text(
                        u.displayName,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        u.email,
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => context.push('/edit-profile'),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('Изменить профиль'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await auth.logout();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Выйти'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, this.url});

  final String name;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'profile_avatar',
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.surfaceHighlight,
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null && url!.isNotEmpty
            ? Image.network(
                url!,
                fit: BoxFit.cover,
              )
            : Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
                ),
              ),
      ),
    );
  }
}
