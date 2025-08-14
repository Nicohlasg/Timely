import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/calendar_event.dart';

/// A reusable dialog for deleting events, with a nicer UI and
/// logic for handling recurring events.
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
            Icon(Icons.delete_sweep_outlined,
                color: Colors.red.shade300, size: 40),
            const SizedBox(height: 16),
            Text(
              isRecurring ? 'Delete Recurring Event' : 'Delete Event',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          isRecurring
              ? 'This is a recurring event. Choose what you want to delete.'
              : 'Are you sure you want to permanently delete "${event.title}"?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: isRecurring
            ? _buildRecurringActions(context)
            : _buildSingleActions(context),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }

  List<Widget> _buildSingleActions(BuildContext context) {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_forever),
            label: const Text('Delete Event'),
            onPressed: () => onDelete('all'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildRecurringActions(BuildContext context) {
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDialogButton(
            context: context,
            text: 'This Event Only',
            color: Colors.blue,
            onPressed: () => onDelete('this'),
          ),
          const SizedBox(height: 10),
          _buildDialogButton(
            context: context,
            text: 'This and Following Events',
            color: Colors.orange,
            onPressed: () => onDelete('following'),
          ),
          const SizedBox(height: 10),
          _buildDialogButton(
            context: context,
            text: 'All Events in Series',
            color: Colors.red,
            onPressed: () => onDelete('all'),
          ),
          const Divider(height: 24, color: Colors.white30),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child:
                Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
        ],
      ),
    ];
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