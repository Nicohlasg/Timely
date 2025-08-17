import 'package:flutter/material.dart';
import '../common/app_dialog.dart';
import '../../Theme/app_styles.dart';

class MoveRecurringEventDialog extends StatelessWidget {
  final Function(String) onConfirm;

  const MoveRecurringEventDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.appStyle;
    
    return AppDialog(
      title: 'Move Recurring Event',
      content: 'This is a recurring event. How would you like to move it?',
      type: DialogType.info,
      icon: Icons.move_up,
      actions: [
        PrimaryDialogAction(
          text: 'Move This Event Only',
          onPressed: () => onConfirm('this'),
          customColor: style.primaryColor,
        ),
        PrimaryDialogAction(
          text: 'Move This & Following',
          onPressed: () => onConfirm('following'),
          customColor: Color.lerp(style.primaryColor, Colors.white, 0.3)!,
        ),
        PrimaryDialogAction(
          text: 'Move All Events in Series',
          onPressed: () => onConfirm('all'),
          customColor: Color.lerp(style.primaryColor, Colors.white, 0.1)!,
        ),
        PrimaryDialogAction(
          text: 'Duplicate Event',
          onPressed: () => onConfirm('duplicate'),
          customColor: style.successColor,
        ),
        SecondaryDialogAction(
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}