import 'package:flutter/material.dart';
import '../common/app_dialog.dart';
import '../../Theme/app_styles.dart';

class ConflictDialog extends StatelessWidget {
  final String conflictingEventTitle;

  const ConflictDialog({
    super.key,
    required this.conflictingEventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      title: 'Scheduling Conflict',
      content: 'This event conflicts with "$conflictingEventTitle". Do you want to move it anyway?',
      type: DialogType.warning,
      icon: Icons.warning_amber_rounded,
      actions: [
        SecondaryDialogAction(
          text: 'Cancel',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PrimaryDialogAction(
          text: 'Move Anyway',
          onPressed: () => Navigator.of(context).pop(true),
          customColor: context.appStyle.warningColor,
        ),
      ],
    );
  }
}