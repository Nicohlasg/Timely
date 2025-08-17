import 'package:flutter/material.dart';
import '../common/app_dialog.dart';
import '../../Theme/app_styles.dart';

enum EditScope { thisEvent, allEvents }

class EditRecurringEventDialog extends StatelessWidget {
  final Function(EditScope) onConfirm;

  const EditRecurringEventDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Edit Recurring Event',
      content: 'Do you want to save the changes for this event only, or for all events in this series?',
      type: DialogType.info,
      icon: Icons.edit_calendar_outlined,
      actions: [
        PrimaryDialogAction(
          text: 'This Event Only',
          onPressed: () => onConfirm(EditScope.thisEvent),
          customColor: context.appStyle.primaryColor,
        ),
        PrimaryDialogAction(
          text: 'All Events in Series',
          onPressed: () => onConfirm(EditScope.allEvents),
          customColor: context.appStyle.warningColor,
        ),
        SecondaryDialogAction(
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}