import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MoveRecurringEventDialog extends StatelessWidget {
  final Function(String) onConfirm;

  const MoveRecurringEventDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D3748).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white30),
        ),
        title: Column(
          children: [
            const Icon(Icons.move_up, color: Colors.blue, size: 40),
            const SizedBox(height: 16),
            Text(
              'Move Recurring Event',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This is a recurring event. How would you like to move it?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogButton(
                context: context,
                text: 'Move This Event Only',
                color: Colors.blue,
                onPressed: () => onConfirm('this'),
              ),
              const SizedBox(height: 10),
              _buildDialogButton(
                context: context,
                text: 'Move This & Following',
                color: Colors.blue.shade300,
                onPressed: () => onConfirm('following'),
              ),
              const SizedBox(height: 10),
              _buildDialogButton(
                context: context,
                text: 'Move All Events in Series',
                color: Colors.blue.shade400,
                onPressed: () => onConfirm('all'),
              ),
              const SizedBox(height: 10),
              _buildDialogButton(
                context: context,
                text: 'Duplicate Event',
                color: Colors.green,
                onPressed: () => onConfirm('duplicate'),
              ),
              const Divider(height: 24, color: Colors.white30),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
              ),
            ],
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  Widget _buildDialogButton({
    required BuildContext context,
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(text, style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
    );
  }
}