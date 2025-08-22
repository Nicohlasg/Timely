import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../state/sync_state.dart';
import '../widgets/background_container.dart';

class SyncCalendarsPage extends StatelessWidget {
  const SyncCalendarsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Sync Calendars', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<SyncState>(
          builder: (context, syncState, child) {
            return ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildGoogleCalendarCard(context, syncState),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoogleCalendarCard(BuildContext context, SyncState syncState) {
    final isSignedIn = syncState.currentUser != null;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/img/google_calendar_icon.png', width: 40),
              const SizedBox(width: 16),
              Text(
                'Google Calendar',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isSignedIn) ...[
            Text(
              'Signed in as:',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            Text(
              syncState.currentUser!.email,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            if (syncState.isLoadingCalendars)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Center(child: CircularProgressIndicator(color: Colors.white)),
              )
            else if (syncState.calendars.isNotEmpty)
              _buildCalendarSelectionDropdown(syncState),
            const SizedBox(height: 8),
            Text(
              'Sync is handled automatically in the background. You can also trigger a manual sync.',
              style: GoogleFonts.inter(color: Colors.white70, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: syncState.isSyncing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.sync, color: Colors.white),
                    label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(color: Colors.white)),
                    onPressed: syncState.isSyncing
                        ? null
                        : () async {
                            final result = await syncState.syncNow();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(result)),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: () => syncState.signOut(),
                ),
              ],
            )
          ] else ...[
            Text(
              'Connect your Google Account to enable automatic, two-way syncing with Google Calendar.',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => syncState.signIn(),
              child: const Text('Sign in with Google'),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildCalendarSelectionDropdown(SyncState syncState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select calendar to sync:',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: syncState.selectedCalendarId,
          onChanged: (String? newValue) {
            if (newValue != null) {
              syncState.selectCalendar(newValue);
            }
          },
          items: syncState.calendars.map<DropdownMenuItem<String>>((calendar) {
            return DropdownMenuItem<String>(
              value: calendar.id,
              child: Text(calendar.summary ?? 'Unnamed Calendar', overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          dropdownColor: Colors.grey[800],
          style: GoogleFonts.inter(color: Colors.white),
          iconEnabledColor: Colors.white,
          isExpanded: true,
        ),
      ],
    );
  }
}