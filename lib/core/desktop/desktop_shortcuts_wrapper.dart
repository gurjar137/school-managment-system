import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

class DesktopShortcutsWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSearchOverride;
  final VoidCallback? onRefreshOverride;

  const DesktopShortcutsWrapper({
    super.key,
    required this.child,
    this.onSearchOverride,
    this.onRefreshOverride,
  });

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        // Cmd+K on macOS, Ctrl+K on Windows / Linux / Web
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () => _handleSearch(context),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => _handleSearch(context),
        
        // Cmd+R on macOS, Ctrl+R on Windows / Linux
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () => _handleRefresh(context),
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () => _handleRefresh(context),
      },
      child: Focus(
        autofocus: true,
        child: child,
      ),
    );
  }

  void _handleSearch(BuildContext context) {
    if (onSearchOverride != null) {
      onSearchOverride!();
      return;
    }
    try {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final currentLoc = router.state.uri.toString();
        if (!currentLoc.contains('search')) {
          router.push('/global-search');
        }
      }
    } catch (_) {}
  }

  void _handleRefresh(BuildContext context) {
    if (onRefreshOverride != null) {
      onRefreshOverride!();
      return;
    }
    try {
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        final currentLoc = router.state.uri.toString();
        router.go(currentLoc);
      }
    } catch (_) {}
  }
}
