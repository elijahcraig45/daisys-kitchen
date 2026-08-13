import 'package:flutter/material.dart';
import 'package:recipe_keeper/theme/app_theme.dart';

/// Helper for showing consistent, user-friendly snackbars.
///
/// Every colour comes from the theme so both light and dark render correctly.
class SnackBarHelper {
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.check_circle_outline,
      background: context.statusColors.success,
      duration: const Duration(seconds: 3),
    );
  }

  static void showError(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.error_outline,
      background: context.colors.error,
      foreground: context.colors.onError,
      duration: const Duration(seconds: 5),
    );
  }

  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.info_outline,
      background: context.statusColors.info,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(BuildContext context, String message) {
    _show(
      context,
      message,
      icon: Icons.warning_amber_outlined,
      background: context.statusColors.warning,
      duration: const Duration(seconds: 4),
    );
  }

  /// Show a loading snackbar; the caller closes it when the work finishes.
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoading(
    BuildContext context,
    String message,
  ) {
    final colors = context.colors;
    return ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(colors.onInverseSurface),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(days: 1),
      ),
    );
  }

  static void dismiss(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color background,
    required Duration duration,
    Color? foreground,
  }) {
    if (!context.mounted) return;

    final onBackground = foreground ?? context.statusColors.onStatus;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: onBackground, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: onBackground)),
            ),
          ],
        ),
        backgroundColor: background,
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: onBackground,
          onPressed: () {},
        ),
      ),
    );
  }
}
