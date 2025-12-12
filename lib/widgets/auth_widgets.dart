import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipe_keeper/providers/firebase_providers.dart';
import 'package:recipe_keeper/services/auth_service.dart';

/// App bar with authentication status and admin controls
class AuthAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const AuthAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final userAsync = ref.watch(currentUserProvider);

    return AppBar(
      title: Text(title),
      actions: [
        ...?actions,
        userAsync.when(
          data: (user) {
            if (user == null) {
              // Not signed in - show sign in button
              return IconButton(
                icon: const Icon(Icons.login),
                tooltip: 'Sign In',
                onPressed: () => _showSignInDialog(context, ref),
              );
            } else {
              // Signed in - show user menu
              return PopupMenuButton<String>(
                icon: CircleAvatar(
                  radius: 16,
                  backgroundImage: authService.photoURL != null
                      ? NetworkImage(authService.photoURL!)
                      : null,
                  child: authService.photoURL == null
                      ? Text(authService.displayName[0].toUpperCase())
                      : null,
                ),
                tooltip: authService.displayName,
                onSelected: (value) async {
                  if (value == 'signout') {
                    await authService.signOut();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authService.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (authService.isAdmin)
                          const Text(
                            'Admin',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Sign Out'),
                      ],
                    ),
                  ),
                ],
              );
            }
          },
          loading: () => const SizedBox(width: 48),
          error: (_, __) => const SizedBox(width: 48),
        ),
      ],
    );
  }

  void _showSignInDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sign in to add, edit, or manage recipes.'),
            SizedBox(height: 16),
            Text(
              'Public viewing does not require sign-in.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              final authService = ref.read(authServiceProvider);
              final result = await authService.signInWithGoogle();
              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Welcome, ${authService.displayName}!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            icon: const Icon(Icons.login),
            label: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
  }
}

/// Admin guard widget - shows children only if user is admin
class AdminGuard extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const AdminGuard({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    
    if (isAdmin) {
      return child;
    }
    
    return fallback ?? const SizedBox.shrink();
  }
}

/// Sign-in guard widget - shows children only if user is signed in
class SignInGuard extends ConsumerWidget {
  final Widget child;
  final Widget? fallback;

  const SignInGuard({
    super.key,
    required this.child,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    
    if (isSignedIn) {
      return child;
    }
    
    return fallback ?? const SizedBox.shrink();
  }
}
