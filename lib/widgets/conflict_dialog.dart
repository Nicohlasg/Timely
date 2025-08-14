import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ConflictDialog extends StatelessWidget {
  final String conflictingEventTitle;

  const ConflictDialog({
    super.key,
    required this.conflictingEventTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: const Color(0xFF2D3748).withValues(alpha:0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.white30),
        ),
        title: Column(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade300, size: 40),
            const SizedBox(height: 16),
            Text(
              'Scheduling Conflict',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'This event conflicts with "$conflictingEventTitle". Do you want to move it anyway?',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Move Anyway', style: GoogleFonts.inter()),
              ),
            ],
          ),
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }
}