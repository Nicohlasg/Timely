import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/calendar_event.dart';
import '../state/calendar_state.dart';
import '../calendar_page/edit_event_screen.dart';
import '../widgets/delete_event_dialog.dart';
import '../services/recurrence_service.dart';

class AllEventsPage extends StatefulWidget {
  const AllEventsPage({super.key});

  @override
  State<AllEventsPage> createState() => _AllEventsPageState();
}

class _AllEventsPageState extends State<AllEventsPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CalendarEvent> _generateAllOccurrences(List<CalendarEvent> masterEvents) {
    final now = DateTime.now();
    final horizon = DateTime(now.year + 2, now.month, now.day);
    final results = <CalendarEvent>[];

    for (final event in masterEvents) {
      if (event.repeatRule == RepeatRule.never) {
        if (!event.end.isBefore(now)) results.add(event);
        continue;
      }
      // Generate occurrences from the event's natural start through horizon.
      final occurrences = RecurrenceService.occurrencesInRange(
  masterEvent: event,
  startRange: event.start.isBefore(now) ? event.start : now,
  endRange: horizon,
      );
      for (final occ in occurrences) {
        if (!occ.end.isBefore(now)) results.add(occ);
      }
    }
    return results;
  }

  Future<bool> _confirmDeletion(CalendarEvent event) async {
    final calendarState = context.read<CalendarState>();
    final masterEvent = calendarState.events.firstWhere(
      (e) => e.id == event.id,
      orElse: () => event,
    );
    final isRecurring = masterEvent.repeatRule != RepeatRule.never;

    final didConfirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteEventDialog(
        event: event,
        masterEvent: masterEvent,
        isRecurring: isRecurring,
        onDelete: (deleteOption) async {
          Navigator.of(context).pop(true);
          switch (deleteOption) {
            case 'this':
              await calendarState.deleteSingleOccurrence(masterEvent, event.start);
              break;
            case 'following':
              await calendarState.deleteThisAndFollowing(masterEvent, event.start);
              break;
            case 'all':
              await calendarState.deleteEvent(masterEvent.id);
              break;
          }
        },
      ),
    );
    return didConfirmDelete ?? false;
  }

  void _editEvent(CalendarEvent event) {
    final calendarState = context.read<CalendarState>();
    final masterEvent = calendarState.events.firstWhere(
      (e) => e.id == event.id,
      orElse: () => event,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEventScreen(
          event: event,
          masterEvent: masterEvent,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = context.watch<CalendarState>();
    final allOccurrences = _generateAllOccurrences(calendarState.events);

    final query = _searchController.text.toLowerCase();
    final filteredEvents = allOccurrences.where((event) {
      final titleMatch = event.title.toLowerCase().contains(query);
      final locationMatch = event.location.toLowerCase().contains(query);
      return titleMatch || locationMatch;
    }).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return Scaffold(
      backgroundColor: const Color(0xFF1A202C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _buildSearchField(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 8),
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          final key = ValueKey('${event.id}-${event.start}');

          return Dismissible(
            key: key,
            direction: DismissDirection.endToStart,
            confirmDismiss: (direction) => _confirmDeletion(event),
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.centerRight,
              child: const Icon(Icons.delete_sweep_outlined, color: Colors.white),
            ),
            child: _buildEventListItem(event),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Search by title or location...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          prefixIcon: Icon(
            Icons.search,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0),
        ),
      ),
    );
  }

  Widget _buildEventListItem(CalendarEvent event) {
    return GestureDetector(
      onTap: () => _editEvent(event),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 50,
              decoration: BoxDecoration(
                color: event.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('E, MMM d, yyyy • h:mm a').format(event.start),
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
                  if (event.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.location,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
