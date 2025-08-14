import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile_data.dart';
import '../services/firebase_friend_service.dart';

class ReportDialog extends StatefulWidget {
  final UserProfileData reportedUser;
  const ReportDialog({super.key, required this.reportedUser});

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  String? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Spam or Misleading Content',
    'Harassment or Bullying',
    'Inappropriate Profile Information',
    'Impersonation',
    'Other',
  ];

  void _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason for the report.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // In a real app, inject this via Provider
      final service = FirebaseFriendService();
      await service.submitReport(
        reportedUserId: widget.reportedUser.uid,
        reason: _selectedReason!,
        details: _detailsController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted. Thank you.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
        title: Text(
          'Report ${widget.reportedUser.firstName}',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ..._reasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(color: Colors.white)),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) => setState(() => _selectedReason = value),
                activeColor: Colors.blue,
              )),
              if (_selectedReason == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: TextField(
                    controller: _detailsController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Please provide more details...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitReport,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text('Submit Report', style: GoogleFonts.inter()),
          ),
        ],
      ),
    );
  }
}