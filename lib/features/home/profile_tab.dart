import 'package:cached_network_image/cached_network_image.dart';
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
    final u = url;
    return CircleAvatar(
      radius: 56,
      backgroundColor: AppTheme.surfaceHighlight,
      backgroundImage: u != null && u.isNotEmpty
          ? CachedNetworkImageProvider(u)
          : null,
      child: u == null || u.isEmpty
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700),
            )
          : null,
    );
  }
}
