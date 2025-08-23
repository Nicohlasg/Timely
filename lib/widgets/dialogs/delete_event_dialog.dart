import 'package:flutter/material.dart';
import '../common/app_button.dart';
import '../common/app_dialog.dart';
import '../../models/calendar_event.dart';
import '../../Theme/app_styles.dart';

class DeleteEventDialog extends StatelessWidget {
  final CalendarEvent event;
  final CalendarEvent masterEvent;
  final bool isRecurring;
  final Function(String) onDelete;

  const DeleteEventDialog({
    super.key,
    required this.event,
    required this.masterEvent,
    required this.isRecurring,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // For recurring events, we build a custom layout to ensure consistent button widths.
    // For single events, we use the standard action layout.
    return isRecurring
        ? _buildRecurringDialog(context)
        : _buildSingleDialog(context);
  }

  /// Builds the dialog for a single, non-recurring event using the original action format.
  Widget _buildSingleDialog(BuildContext context) {
    return AppDialog(
      title: 'Delete Event',
      content: 'Are you sure you want to permanently delete "${event.title}"?',
      type: DialogType.error,
      icon: Icons.delete_sweep_outlined,
      actions: [
        SecondaryDialogAction(
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        IconDialogAction(
          text: 'Delete Event',
          icon: Icons.delete_forever,
          onPressed: () => onDelete('all'),
          color: context.appStyle.errorColor,
        ),
      ],
    );
  }

  /// Builds the dialog for a recurring event with a custom button layout.
  Widget _buildRecurringDialog(BuildContext context) {
    final style = context.appStyle;

    return AppDialog(
      title: 'Delete Recurring Event',
      type: DialogType.error,
      icon: Icons.delete_sweep_outlined,
      actions: const [], // Actions are handled by the contentWidget for layout control.
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        // This forces all child buttons to expand to the same width.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This is a recurring event. Choose what you want to delete.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // We use AppButton directly with the CORRECT parameters from your file.
          AppButton(
            text: 'This Event Only',
            onPressed: () => onDelete('this'),
            customColor: style.primaryColor,
            type: AppButtonType.primary,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'This and Following Events',
            onPressed: () => onDelete('following'),
            customColor: style.warningColor,
            type: AppButtonType.primary,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'All Events in Series',
            onPressed: () => onDelete('all'),
            customColor: style.errorColor,
            type: AppButtonType.primary,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Cancel',
            onPressed: () => Navigator.of(context).pop(),
            type: AppButtonType.outlined, // Use outlined type for the cancel action
          ),
        ],
      ),
    );
  }
}