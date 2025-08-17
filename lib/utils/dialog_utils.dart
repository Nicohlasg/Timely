import 'package:flutter/material.dart';
import '../widgets/common/app_dialog.dart';
import '../widgets/dialogs/conflict_dialog.dart';
import '../widgets/dialogs/delete_event_dialog.dart';
import '../widgets/dialogs/edit_recurring_event_dialog.dart';
import '../widgets/dialogs/move_recurring_event_dialog.dart';
import '../models/calendar_event.dart';

/// Centralized dialog utilities for consistent dialog management
class DialogUtils {
  
  /// Shows a conflict dialog when events overlap
  static Future<bool?> showConflictDialog(
    BuildContext context,
    String conflictingEventTitle,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConflictDialog(
        conflictingEventTitle: conflictingEventTitle,
      ),
    );
  }
  
  /// Shows a delete event dialog with proper recurring event handling
  static Future<String?> showDeleteEventDialog(
    BuildContext context, {
    required CalendarEvent event,
    required CalendarEvent masterEvent,
    required bool isRecurring,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => DeleteEventDialog(
        event: event,
        masterEvent: masterEvent,
        isRecurring: isRecurring,
        onDelete: (deleteOption) {
          Navigator.of(context).pop(deleteOption);
        },
      ),
    );
  }
  
  /// Shows an edit recurring event dialog
  static Future<EditScope?> showEditRecurringDialog(
    BuildContext context,
  ) {
    return showDialog<EditScope>(
      context: context,
      builder: (context) => EditRecurringEventDialog(
        onConfirm: (scope) {
          Navigator.of(context).pop(scope);
        },
      ),
    );
  }
  
  /// Shows a move recurring event dialog
  static Future<String?> showMoveRecurringDialog(
    BuildContext context,
  ) {
    return showDialog<String>(
      context: context,
      builder: (context) => MoveRecurringEventDialog(
        onConfirm: (action) {
          Navigator.of(context).pop(action);
        },
      ),
    );
  }
  
  /// Shows a generic confirmation dialog
  static Future<bool?> showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    bool isDestructive = false,
  }) {
    return DialogHelper.showConfirmDialog(
      context,
      title: title,
      content: message,
      confirmText: confirmText,
      cancelText: cancelText,
      type: isDestructive ? DialogType.error : DialogType.warning,
      icon: isDestructive ? Icons.warning : Icons.help_outline,
    );
  }
  
  /// Shows an info dialog with just an OK button
  static Future<void> showInfoDialog(
    BuildContext context, {
    required String title,
    required String message,
    String buttonText = 'OK',
  }) {
    return DialogHelper.showInfoDialog(
      context,
      title: title,
      content: message,
      buttonText: buttonText,
    );
  }
  
  /// Shows a loading dialog
  static void showLoadingDialog(BuildContext context, [String? message]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        title: 'Loading',
        contentWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ],
        ),
        actions: const [],
      ),
    );
  }
  
  /// Dismisses any currently shown dialog
  static void dismissDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}