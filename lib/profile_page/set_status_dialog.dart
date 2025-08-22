import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/profile_state.dart';

class SetStatusDialog extends StatefulWidget {
  const SetStatusDialog({super.key});

  @override
  State<SetStatusDialog> createState() => _SetStatusDialogState();
}

class _SetStatusDialogState extends State<SetStatusDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Pre-fill the text field with the current status
    final currentStatus = context.read<ProfileState>().userProfile?.status['text'] ?? '';
    _controller = TextEditingController(text: currentStatus);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
            Icon(Icons.edit_note_outlined, color: Colors.blue.shade300, size: 40),
            const SizedBox(height: 16),
            Text(
              'Set Your Status',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: _controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'What are you up to?',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  context.read<ProfileState>().updateUserStatus(_controller.text);
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Set Status', style: GoogleFonts.inter()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  context.read<ProfileState>().clearUserStatus();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Clear Status',
                  style: GoogleFonts.inter(color: Colors.red.shade300),
                ),
              ),
            ],
          )
        ],
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      ),
    );
  }
}