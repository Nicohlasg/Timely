import 'package:flutter/material.dart';
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
    return AppDialog(
      title: isRecurring ? 'Delete Recurring Event' : 'Delete Event',
      content: isRecurring
          ? 'This is a recurring event. Choose what you want to delete.'
          : 'Are you sure you want to permanently delete "${event.title}"?',
      type: DialogType.error,
      icon: Icons.delete_sweep_outlined,
      actions: isRecurring ? _buildRecurringActions(context) : _buildSingleActions(context),
    );
  }

  List<DialogAction> _buildSingleActions(BuildContext context) {
    return [
      IconDialogAction(
        text: 'Delete Event',
        icon: Icons.delete_forever,
        onPressed: () => onDelete('all'),
        color: context.appStyle.errorColor,
      ),
      SecondaryDialogAction(
        text: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }

  List<DialogAction> _buildRecurringActions(BuildContext context) {
    final style = context.appStyle;
    
    return [
      PrimaryDialogAction(
        text: 'This Event Only',
        onPressed: () => onDelete('this'),
        customColor: style.primaryColor,
      ),
      PrimaryDialogAction(
        text: 'This and Following Events',
        onPressed: () => onDelete('following'),
        customColor: style.warningColor,
      ),
      PrimaryDialogAction(
        text: 'All Events in Series',
        onPressed: () => onDelete('all'),
        customColor: style.errorColor,
      ),
      SecondaryDialogAction(
        text: 'Cancel',
        onPressed: () => Navigator.of(context).pop(),
      ),
    ];
  }
}