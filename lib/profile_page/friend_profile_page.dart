import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/calendar_event.dart';
import '../models/user_profile_data.dart';
import '../services/firebase_friend_service.dart';
import '../widgets/background_container.dart';
import 'package:table_calendar/table_calendar.dart';
import 'propose_event_page.dart';
import '../state/friend_state.dart';
import 'report_dialog.dart';


class FriendProfilePage extends StatelessWidget {
  final UserProfileData friendProfile;
  const FriendProfilePage({super.key, required this.friendProfile});

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(friendProfile.username, style: GoogleFonts.inter()),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add_comment_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ProposeEventPage(recipientProfile: friendProfile),
                    fullscreenDialog: true, // Presents the page as a modal
                  ),
                );
              },
              tooltip: 'Propose Event',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) async {
                if (value == 'block') {
                  // Confirm before blocking
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Block User?'),
                      content: Text('Are you sure you want to block ${friendProfile.firstName}? You will no longer be friends and cannot interact.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Block', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await context.read<FriendState>().blockUser(friendProfile.uid);
                    if(context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${friendProfile.firstName} has been blocked.')));
                      Navigator.of(context).pop(); // Go back to the friends list
                    }
                  }
                } else if (value == 'report') {
                  showDialog(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.3),
                    builder: (context) => ReportDialog(reportedUser: friendProfile),
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'block', child: Text('Block User', style: TextStyle(color: Colors.red))),
                const PopupMenuItem(value: 'report', child: Text('Report User')),
              ],
            ),
            // Unfriend button on the friend profile page
            Builder(builder: (context) {
              return IconButton(
                icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
                tooltip: 'Unfriend',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Unfriend?'),
                      content: Text('Remove ${friendProfile.firstName} ${friendProfile.lastName} from your friends?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Unfriend', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    // Access FriendState via Provider without import cycles
                    try {
                      // Delay provider lookup to after dialog pop
                      final friendState = Provider.of<FriendState>(context, listen: false);
                      await friendState.removeFriendByUserId(friendProfile.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Removed ${friendProfile.firstName} from friends')),
                        );
                        Navigator.of(context).maybePop();
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to remove friend.')),
                        );
                      }
                    }
                  }
                },
              );
            })
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildProfileHeader(friendProfile),
            const SizedBox(height: 24),
            _FriendScheduleWidget(friendProfile: friendProfile),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserProfileData profile) {
    // Expanded with username, email, status, phone, occupation, location if present
    Widget infoRow(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.white70, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: GoogleFonts.inter(color: Colors.white70)),
              ),
            ],
          ),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage: NetworkImage(profile.photoURL),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.firstName} ${profile.lastName}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('@${profile.username}',
                  style: GoogleFonts.inter(color: Colors.white70)),
              if (profile.status.isNotEmpty &&
                  (profile.status['text'] as String? ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('"${profile.status['text']}"',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontStyle: FontStyle.italic)),
                ),
              const SizedBox(height: 8),
              if (profile.email.isNotEmpty)
                infoRow(Icons.alternate_email, profile.email),
              if (profile.phoneNumber.isNotEmpty)
                infoRow(Icons.phone_outlined, profile.phoneNumber),
              if (profile.occupation.isNotEmpty)
                infoRow(Icons.work_outline, profile.occupation),
              if (profile.location.isNotEmpty)
                infoRow(Icons.location_on_outlined, profile.location),
            ],
          ),
        ),
      ],
    );
  }
}

// Stateful widget to handle fetching and displaying the schedule
class _FriendScheduleWidget extends StatefulWidget {
  final UserProfileData friendProfile;
  const _FriendScheduleWidget({required this.friendProfile});

  @override
  State<_FriendScheduleWidget> createState() => _FriendScheduleWidgetState();
}

class _FriendScheduleWidgetState extends State<_FriendScheduleWidget> {
  bool _isExpanded = false;
  bool _isLoading = false;
  String? _errorMessage;
  List<CalendarEvent> _friendEvents = [];
  DateTime _selectedDay = DateTime.now();

  Future<void> _fetchSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = FirebaseFriendService(); // In a real app, inject this
      final eventsData =
          await service.getFriendSchedule(widget.friendProfile.uid);

      // The Cloud Function returns raw maps, we need to convert them
      _friendEvents = eventsData.map((eventMap) {
        return CalendarEvent(
          title: eventMap['title'],
          location: eventMap['location'],
          start: DateTime.parse(eventMap['start']),
          end: DateTime.parse(eventMap['end']),
          color: Color(eventMap['color']),
          allDay: eventMap['allDay'],
        );
      }).toList();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventsForSelectedDay = _friendEvents
        .where((event) => isSameDay(event.start, _selectedDay))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ElevatedButton.icon(
            icon: Icon(_isExpanded
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            label: Text("View ${widget.friendProfile.firstName}'s Schedule"),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: Colors.blue.withValues(alpha: 0.8)),
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
                // Fetch schedule only when expanding for the first time
                if (_isExpanded &&
                    _friendEvents.isEmpty &&
                    _errorMessage == null) {
                  _fetchSchedule();
                }
              });
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              width: double.infinity,
              child: _isExpanded
                  ? _buildScheduleContent(eventsForSelectedDay)
                  : const SizedBox.shrink(),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildScheduleContent(List<CalendarEvent> dailyEvents) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          "Could not load schedule: $_errorMessage",
          style: TextStyle(color: Colors.red.shade300),
          textAlign: TextAlign.center,
        ),
      );
    }

    // A simplified, read-only version of your AgendaView timeline
    return Column(
      children: [
        const Divider(height: 32, color: Colors.white30),
        // Simple day switcher
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() =>
                      _selectedDay = _selectedDay.subtract(Duration(days: 1)));
                }),
            Text(DateFormat.yMMMEd().format(_selectedDay),
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(
                      () => _selectedDay = _selectedDay.add(Duration(days: 1)));
                }),
          ],
        ),
        const SizedBox(height: 16),
        if (dailyEvents.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("${widget.friendProfile.firstName} is free all day!",
                style: TextStyle(color: Colors.white70)),
          )
        else
          ...dailyEvents.map((event) => ListTile(
                leading: Icon(Icons.circle, color: event.color, size: 12),
                title: Text(event.title, style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  "${DateFormat.jm().format(event.start)} - ${DateFormat.jm().format(event.end)}",
                  style: TextStyle(color: Colors.white70),
                ),
              ))
      ],
    );
  }
}
