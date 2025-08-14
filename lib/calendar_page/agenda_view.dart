import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:table_calendar/table_calendar.dart';
import '../models/calendar_event.dart';
import '../state/calendar_state.dart';
import 'package:provider/provider.dart';

class EventLayout {
  final CalendarEvent event;
  final double top, height, left, width;
  final CalendarEvent? masterEvent;

  EventLayout({
    required this.event,
    required this.top,
    required this.height,
    required this.left,
    required this.width,
    this.masterEvent,
  });
}

class AgendaView extends StatefulWidget {
  final DateTime selectedDay;
  final List<CalendarEvent> Function(DateTime) getEventsForDay;
  final Function(CalendarEvent, {CalendarEvent? masterEvent}) onEditEvent;
  final AnimationController sheetController;
  final double headerHeight;

  const AgendaView({
    super.key,
    required this.selectedDay,
    required this.getEventsForDay,
    required this.onEditEvent,
    required this.sheetController,
    required this.headerHeight,
  });

  @override
  State<AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<AgendaView> {
  late DateTime _now;
  Timer? _timer;
  late ScrollController _scrollController;

  EventLayout? _draggedEventLayout;
  double _dragEventOriginalTop = 0;
  Offset _dragOffset = Offset.zero;
  CalendarEvent? _ghostEvent;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _scrollController = ScrollController();
    widget.sheetController.addStatusListener(_onSheetStatusChanged);
    _timer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _onSheetStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scrollToCurrentTime();
  }

  void _scrollToCurrentTime() {
    if (mounted && _scrollController.hasClients && isSameDay(widget.selectedDay, _now)) {
      final viewportHeight = _scrollController.position.viewportDimension;
      final currentTimePosition = (_now.hour * 60.0) + _now.minute;
      double initialScrollOffset = (currentTimePosition - (viewportHeight / 2))
          .clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(initialScrollOffset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    widget.sheetController.removeStatusListener(_onSheetStatusChanged);
    super.dispose();
  }

  Future<void> _onLongPressEnd(LongPressEndDetails details) async {
    final eventToSave = _ghostEvent;
    final originalLayout = _draggedEventLayout;

    try {
      if (originalLayout == null || eventToSave == null || isSameMinute(eventToSave.start, originalLayout.event.start)) {
        return;
      }

      final calendarState = context.read<CalendarState>();
      final eventsOnDay = widget.getEventsForDay(widget.selectedDay);
      final conflictingEvent = eventsOnDay.firstWhere(
            (e) => e.id != originalLayout.event.id && e.id != originalLayout.masterEvent?.id && eventToSave.start.isBefore(e.end) && eventToSave.end.isAfter(e.start),
        orElse: () => CalendarEvent(id: '', title: '', start: DateTime.now(), end: DateTime.now()),
      );

      bool canSave = true;
      if (conflictingEvent.id.isNotEmpty && mounted) {
        final continueAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2D3748),
            title: Text('Event Conflict', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Text('This event conflicts with "${conflictingEvent.title}". Save anyway?', style: GoogleFonts.inter(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white70))),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Save Anyway', style: GoogleFonts.inter(color: Colors.orange))),
            ],
          ),
        ) ?? false;
        if (!continueAnyway) canSave = false;
      }

      if (canSave) {
        final masterEvent = originalLayout.masterEvent ?? originalLayout.event;
        final isRecurring = masterEvent.repeatRule != RepeatRule.never;

        if (isRecurring) {
          final newSingleEvent = CalendarEvent(
            title: masterEvent.title,
            location: masterEvent.location,
            start: eventToSave.start,
            end: eventToSave.end,
            allDay: masterEvent.allDay,
            color: masterEvent.color,
            repeatRule: RepeatRule.never,
            userId: calendarState.currentUserId ?? '',
          );
          await calendarState.updateSingleOccurrence(
            masterEvent: masterEvent,
            occurrenceDate: originalLayout.event.start,
            updatedEvent: newSingleEvent,
          );
        } else {
          final updatedEvent = originalLayout.event.copyWith(start: eventToSave.start, end: eventToSave.end);
          await calendarState.updateEvent(updatedEvent);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _draggedEventLayout = null;
          _ghostEvent = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timedEvents = widget.getEventsForDay(widget.selectedDay).where((e) => !e.allDay).toList();
    final allDayEvents = widget.getEventsForDay(widget.selectedDay).where((e) => e.allDay).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            _buildDragHandle(),
            if (allDayEvents.isNotEmpty) _buildAllDayEventsHeader(allDayEvents),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: widget.sheetController,
                    builder: (context, child) {
                      final bool isExpanded = widget.sheetController.value > 0.9;
                      final double timelineHeight = 24 * 60.0;
                      final eventLayouts = _calculateAnimatedLayouts(
                        context,
                        timedEvents,
                        constraints.maxWidth - 70,
                        heightPerMinute: 1.0,
                        isExpanded: isExpanded,
                        ghostEvent: _ghostEvent,
                        draggedEventId: _draggedEventLayout?.event.id,
                      );

                      return ClipRect(
                        child: ScrollConfiguration(
                          behavior: _NoScrollbarBehavior(),
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              bottom: kBottomNavigationBarHeight,
                            ),
                            child: SizedBox(
                              height: timelineHeight,
                              child: Stack(
                                children: [
                                  CustomPaint(
                                    painter: _TimelinePainter(
                                      textDirection: Directionality.of(context),
                                      heightPerMinute: 1.0,
                                    ),
                                    size: Size(constraints.maxWidth, timelineHeight),
                                  ),
                                  ...eventLayouts.map(
                                        (layout) {
                                      final bool isGhost = layout.event.id == _ghostEvent?.id;
                                      return _buildAnimatedEvent(layout, isGhost);
                                    },
                                  ),
                                  if (isSameDay(widget.selectedDay, _now))
                                    _buildCurrentTimeIndicator(heightPerMinute: 1.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedEvent(EventLayout layout, bool isGhost) {
    final isOriginalDragged = layout.event.id == _draggedEventLayout?.event.id;
    final opacity = isOriginalDragged && !isGhost ? 0.0 : 1.0;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      top: layout.top,
      left: layout.left,
      width: layout.width,
      height: layout.height,
      child: GestureDetector(
        onLongPressStart: (details) => _onLongPressStart(layout),
        onLongPressMoveUpdate: _onLongPressMoveUpdate,
        onLongPressEnd: _onLongPressEnd,
        onTap: () => widget.onEditEvent(
          layout.event,
          masterEvent: layout.masterEvent,
        ),
        child: Opacity(
          opacity: opacity,
          child: isGhost
              ? _buildGhostEventWidget(layout)
              : _AgendaEventCard(event: layout.event, height: layout.height),
        ),
      ),
    );
  }

  Widget _buildGhostEventWidget(EventLayout layout) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: layout.event.color, width: 2, style: BorderStyle.solid),
      ),
      child: Center(
        child: Text(
          DateFormat.Hm().format(layout.event.start),
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            backgroundColor: Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  void _onLongPressStart(EventLayout layout) {
    if (widget.sheetController.value < 1.0) return;
    setState(() {
      _draggedEventLayout = layout;
      _dragEventOriginalTop = layout.top;
      _dragOffset = Offset.zero;
      _ghostEvent = layout.event;
    });
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggedEventLayout == null) return;

    _dragOffset = details.offsetFromOrigin;

    final layout = _draggedEventLayout!;
    final newTop = (_dragEventOriginalTop + _dragOffset.dy).clamp(0.0, (24 * 60.0) - layout.height);
    final snappedTop = (newTop / 15).round() * 15.0;
    final minutesFromTop = snappedTop.toInt();
    final hour = (minutesFromTop ~/ 60) % 24;
    final minute = minutesFromTop % 60;

    final newStart = DateTime(
      layout.event.start.year,
      layout.event.start.month,
      layout.event.start.day,
      hour,
      minute,
    );
    final newEnd = newStart.add(layout.event.end.difference(layout.event.start));

    setState(() {
      _ghostEvent = layout.event.copyWith(start: newStart, end: newEnd);
    });
  }

  bool isSameMinute(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  Widget _buildCurrentTimeIndicator({required double heightPerMinute}) {
    final double topPosition =
        ((_now.hour * 60.0) + _now.minute) * heightPerMinute;
    const double bubbleHeight = 28.0;

    return Positioned(
      top: topPosition - (bubbleHeight / 2),
      left: 0,
      right: 0,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 75,
            height: bubbleHeight,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Center(
              child: Text(
                DateFormat('HH:mm').format(_now),
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(child: Container(height: 2, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        widget.sheetController.value -=
            details.primaryDelta! / widget.headerHeight;
      },
      onVerticalDragEnd: (details) {
        if (widget.sheetController.value > 0.5 ||
            details.primaryVelocity! < -500) {
          widget.sheetController.fling(velocity: 1.0);
        } else {
          widget.sheetController.fling(velocity: -1.0);
        }
      },
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAllDayEventsHeader(List<CalendarEvent> allDayEvents) {
    final calendarState = context.read<CalendarState>();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: allDayEvents
            .map(
                (event) {
              final masterEvent = calendarState.events.firstWhere((e) => e.id == event.id, orElse: () => event);
              return GestureDetector(
                onTap: () => widget.onEditEvent(event, masterEvent: masterEvent),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 2.0),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: event.color.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    event.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }
        )
            .toList(),
      ),
    );
  }
}

class _AgendaEventCard extends StatelessWidget {
  final CalendarEvent event;
  final double height;

  const _AgendaEventCard({
    required this.event,
    required this.height,
  });

  Widget _buildFlexibleText({required String text, required TextStyle style}) {
    return Flexible(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, style: style, maxLines: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double minHeightForTime = 38.0;
    const double minHeightForLocation = 58.0;

    final bool showTime = height >= minHeightForTime;
    final bool showLocation =
        height >= minHeightForLocation && event.location.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(right: 2.0, bottom: 1.0),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: event.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _buildFlexibleText(
              text: event.title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (showTime) ...[
              const SizedBox(height: 2),
              _buildFlexibleText(
                text:
                '${DateFormat.Hm().format(event.start)} - ${DateFormat.Hm().format(event.end)}',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
            ],
            if (showLocation) ...[
              const SizedBox(height: 2),
              _buildFlexibleText(
                text: event.location,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final TextDirection textDirection;
  final double heightPerMinute;

  const _TimelinePainter({
    required this.textDirection,
    this.heightPerMinute = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (int i = 0; i <= 24; i++) {
      final y = i * 60.0 * heightPerMinute;
      canvas.drawLine(Offset(60, y), Offset(size.width, y), paint);
      if (i < 24) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${i.toString().padLeft(2, '0')}:00',
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
          ),
          textDirection: textDirection,
        )..layout();
        final yOffset = y - (textPainter.height / 2);
        textPainter.paint(canvas, Offset(6, max(0, yOffset)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return oldDelegate.heightPerMinute != heightPerMinute;
  }
}

class _NoScrollbarBehavior extends ScrollBehavior {
  @override
  Widget buildScrollbar(
      BuildContext context,
      Widget child,
      ScrollableDetails details,
      ) {
    return child;
  }
}

List<EventLayout> _calculateAnimatedLayouts(
    BuildContext context,
    List<CalendarEvent> originalEvents,
    double maxWidth, {
      required double heightPerMinute,
      required bool isExpanded,
      CalendarEvent? ghostEvent,
      String? draggedEventId,
    }) {
  if (originalEvents.isEmpty && ghostEvent == null) return [];

  List<CalendarEvent> events = List.from(originalEvents);

  if (draggedEventId != null) {
    final draggedMasterId = Provider.of<CalendarState>(context, listen: false)
        .events
        .firstWhere((e) => e.id == draggedEventId, orElse: () => CalendarEvent(id: draggedEventId, title: '', start: DateTime.now(), end: DateTime.now()))
        .id;
    events.removeWhere((e) => e.id == draggedMasterId);
  }
  if (ghostEvent != null) {
    events.add(ghostEvent);
  }

  final List<EventLayout> layouts = [];
  final List<List<CalendarEvent>> eventGroups = [];

  if (events.isNotEmpty) {
    events.sort((a, b) => a.start.compareTo(b.start));

    List<CalendarEvent> currentGroup = [events.first];
    eventGroups.add(currentGroup);
    DateTime currentGroupEndTime = events.first.end;

    for (int i = 1; i < events.length; i++) {
      final event = events[i];
      if (event.start.isBefore(currentGroupEndTime)) {
        currentGroup.add(event);
        if (event.end.isAfter(currentGroupEndTime)) {
          currentGroupEndTime = event.end;
        }
      } else {
        currentGroup = [event];
        eventGroups.add(currentGroup);
        currentGroupEndTime = event.end;
      }
    }
  }

  final calendarState = Provider.of<CalendarState>(context, listen: false);

  for (var group in eventGroups) {
    List<List<CalendarEvent>> columns = [];
    group.sort((a, b) => a.start.compareTo(b.start));

    for (var event in group) {
      bool placed = false;
      for (var col in columns) {
        if (!col.last.end.isAfter(event.start)) {
          col.add(event);
          placed = true;
          break;
        }
      }
      if (!placed) columns.add([event]);
    }

    double colWidth = maxWidth / columns.length;
    for (int i = 0; i < columns.length; i++) {
      for (var event in columns[i]) {
        final top =
            (event.start.hour * 60 + event.start.minute) * heightPerMinute;
        final durationInMinutes = event.end.difference(event.start).inMinutes;

        double calculatedHeight;

        if (isExpanded) {
          calculatedHeight = durationInMinutes * heightPerMinute;
        } else {
          calculatedHeight = durationInMinutes < 60 ? 60 * heightPerMinute : durationInMinutes * heightPerMinute;
        }
        final height = max(20.0, calculatedHeight);

        final masterEvent = calendarState.events.firstWhere(
              (e) => e.id == event.id,
          orElse: () => event,
        );

        layouts.add(
          EventLayout(
            event: event,
            masterEvent: masterEvent,
            top: top,
            height: height,
            left: 60 + (i * colWidth),
            width: colWidth,
          ),
        );
      }
    }
  }
  return layouts;
}