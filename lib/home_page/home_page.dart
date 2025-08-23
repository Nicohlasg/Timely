import 'package:flutter/material.dart';
import '../calendar_page/calendar_page.dart';
import '../profile_page/profile_page.dart';
import '../settings_page/settings_page.dart';
import 'dart:async';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/calendar_event.dart';
import '../state/calendar_state.dart';
import '../calendar_page/edit_event_screen.dart';
import 'all_events_page.dart';
import '../widgets/background_container.dart';
import '../services/recurrence_service.dart';
import '../models/event_poll.dart';
import '../state/poll_state.dart';
import '../state/proposal_state.dart';
import '../state/task_state.dart';
import '../models/task.dart';
import '../profile_page/proposals_inbox_page.dart';

// Import our new standardized components
import '../utils/dialog_utils.dart';
import '../utils/widget_utils.dart';
import '../widgets/common/app_tag.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_button.dart';
import '../Theme/app_styles.dart';
import '../widgets/weather_widget.dart'; // Import the new Weather Widget

Future<void> _showDeleteDialog(
    BuildContext context,
    CalendarEvent event,
    ) async {
  final calendarState = context.read<CalendarState>();
  final masterEvent = calendarState.events.firstWhere(
        (e) => e.id == event.id,
    orElse: () => event,
  );
  final isRecurring = masterEvent.repeatRule != RepeatRule.never;

  final deleteOption = await DialogUtils.showDeleteEventDialog(
    context,
    event: event,
    masterEvent: masterEvent,
    isRecurring: isRecurring,
  );

  if (deleteOption != null) {
    switch (deleteOption) {
      case 'this':
        await calendarState.deleteSingleOccurrence(
          masterEvent,
          event.start,
        );
        break;
      case 'following':
        await calendarState.deleteThisAndFollowing(
          masterEvent,
          event.start,
        );
        break;
      case 'all':
        await calendarState.deleteEvent(masterEvent.id);
        break;
    }
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static const List<Widget> _pages = [
    HomeView(),
    CalendarPage(),
    ProfilePage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          children: _pages,
        ),
        bottomNavigationBar: _buildGlassmorphicNavBar(),
      ),
    );
  }

  Widget _buildGlassmorphicNavBar() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: const Border(top: BorderSide(color: Colors.white30)),
          ),
          child: SafeArea(
            top: false,
            child: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                  backgroundColor: Colors.transparent,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month_outlined),
                  activeIcon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                  backgroundColor: Colors.transparent,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                  backgroundColor: Colors.transparent,
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                  backgroundColor: Colors.transparent,
                ),
              ],
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white70,
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
            ),
          ),
        ),
      ),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

// MODIFIED: Added AutomaticKeepAliveClientMixin to preserve state
class _HomeViewState extends State<HomeView>
    with AutomaticKeepAliveClientMixin<HomeView> {
  // REMOVED: Timer is no longer needed here as it's moved to the weather widget
  final User? _user = FirebaseAuth.instance.currentUser;

  // ADDED: Override wantKeepAlive and set it to true
  @override
  bool get wantKeepAlive => true;

  // initState and dispose are no longer needed here for the timer

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<CalendarEvent> _generateUpcomingEvents(
      List<CalendarEvent> masterEvents,
      DateTime now,
      ) {
    final ninetyDaysOut = now.add(const Duration(days: 90));
    return RecurrenceService.upcomingOccurrences(
      masterEvents: masterEvents,
      from: now,
      to: ninetyDaysOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ADDED: Required call for AutomaticKeepAliveClientMixin
    super.build(context);

    final calendarState = context.watch<CalendarState>();
    final now = DateTime.now();

    final allMasterEvents = calendarState.events;
    final currentEvent = allMasterEvents.firstWhere(
          (e) => e.start.isBefore(now) && e.end.isAfter(now),
      orElse: () =>
          CalendarEvent(title: 'No Current Event', start: now, end: now),
    );

    final upcomingEvents = _generateUpcomingEvents(
      allMasterEvents,
      now,
    ).where((event) => event.id != currentEvent.id).toList();

    final pollState = context.watch<PollState>();
    final upcomingPolls = pollState.polls
        .where((p) => p.proposedTimes.any((t) => t.toDate().isAfter(now)))
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: _NoScrollbarBehavior(),
          child: ListView(
            padding: const EdgeInsets.all(20.0),
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              const WeatherWidget(),
              const SizedBox(height: 24),
              if (currentEvent.title != 'No Current Event') ...[
                _buildCurrentEventCard(currentEvent, now),
                const SizedBox(height: 24),
              ],
              _buildSectionHeader("Upcoming Events", () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) =>
                    const AllEventsPage(),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, -1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOut;
                      final tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      final offsetAnimation = animation.drive(tween);
                      return SlideTransition(
                        position: offsetAnimation,
                        child: ClipRect(child: child),
                      );
                    },
                  ),
                );
              }),
              const SizedBox(height: 16),
              ...upcomingEvents
                  .take(3)
                  .map((event) => _UpcomingEventCard(event: event)),
              const SizedBox(height: 24),
              if (upcomingPolls.isNotEmpty) ...[
                _buildSectionHeader("Pending Polls", () {
                  // TODO: Navigate to a page with all polls
                }),
                const SizedBox(height: 16),
                ...upcomingPolls.map((poll) => _EventPollCard(poll: poll)),
                const SizedBox(height: 24),
              ],
              WidgetUtils.buildSectionHeader(
                "Upcoming Tasks",
                onActionPressed: () {
                  // TODO: Navigate to a page with all tasks
                },
              ),
              const SizedBox(height: 16),
              Consumer<TaskState>(
                builder: (context, taskState, child) {
                  if (taskState.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  }

                  final upcomingTasks = taskState.upcomingTasks;
                  if (upcomingTasks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: const Text(
                        "No upcoming tasks. You're all caught up!",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return Column(
                    children: upcomingTasks
                        .take(5)
                        .map((task) => TaskCard(
                      title: task.title,
                      description: task.description.isNotEmpty
                          ? task.description
                          : null,
                      isCompleted: task.isCompleted,
                      onToggle: () => context
                          .read<TaskState>()
                          .toggleTaskCompletion(task.id),
                      trailingWidget: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            task.dueDateText,
                            style: context.appStyle.subheadingStyle
                                .copyWith(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          if (task.priority == TaskPriority.high)
                            PriorityTag.high(),
                          if (task.priority == TaskPriority.medium)
                            PriorityTag.medium(),
                          if (task.priority == TaskPriority.low)
                            PriorityTag.low(),
                        ],
                      ),
                    ))
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // _buildHeader, _buildCurrentEventCard, etc. remain unchanged...
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Consumer<ProposalState>(
          builder: (context, proposalState, child) {
            final hasProposals = proposalState.proposals.isNotEmpty;
            return Badge(
              isLabelVisible: hasProposals,
              label: Text('${proposalState.proposals.length}'),
              backgroundColor: Colors.blue,
              child: IconButton(
                icon: const Icon(Icons.inbox_outlined,
                    color: Colors.white, size: 30),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ProposalsInboxPage()),
                  );
                },
                tooltip: 'Proposals Inbox',
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCurrentEventCard(CalendarEvent event, DateTime now) {
    final totalDuration = event.end.difference(event.start).inSeconds;
    final elapsedDuration = now.difference(event.start).inSeconds;
    final progress = totalDuration > 0
        ? (elapsedDuration / totalDuration).clamp(0.0, 1.0)
        : 0.0;
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: event.color.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "NOW",
            style: GoogleFonts.inter(
              color: event.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            event.title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            event.allDay
                ? "All-day"
                : "${DateFormat.jm().format(event.start)} - ${DateFormat.jm().format(event.end)}",
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
          ),
          if (event.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              "at ${event.location}",
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "$percentage%",
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: event.color.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(event.color),
            ),
          ),
          const Divider(height: 24, color: Colors.white30),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              EditButton(
                onPressed: () {
                  final masterEvent =
                  context.read<CalendarState>().events.firstWhere(
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
                },
              ),
              const SizedBox(width: 8),
              DeleteButton(
                onPressed: () => _showDeleteDialog(context, event),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onViewAll) {
    return WidgetUtils.buildSectionHeader(title, onActionPressed: onViewAll);
  }
}

// _UpcomingEventCard, _EventPollCard, _NoScrollbarBehavior remain the same...
class _UpcomingEventCard extends StatelessWidget {
  final CalendarEvent event;
  const _UpcomingEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final duration = event.end.difference(event.start);
    String durationText = "${duration.inHours} HOURS";
    if (duration.inHours < 1) {
      durationText = "${duration.inMinutes} MINS";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white30),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 8, color: event.color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DurationTag(duration: duration),
                          const SizedBox(width: 8),
                          LocationTag(),
                          const SizedBox(width: 8),
                          if (event.importance == EventImportance.high)
                            PriorityTag.high(),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        event.allDay
                            ? 'All-day • ${event.location}'
                            : "${DateFormat.jm().format(event.start)} - ${DateFormat.jm().format(event.end)} • ${event.location}",
                        style: GoogleFonts.inter(color: Colors.white70),
                      ),
                      const Divider(height: 24, color: Colors.white30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          EditButton(
                            onPressed: () {
                              final masterEvent = context
                                  .read<CalendarState>()
                                  .events
                                  .firstWhere(
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
                            },
                          ),
                          const SizedBox(width: 8),
                          DeleteButton(
                            onPressed: () => _showDeleteDialog(context, event),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventPollCard extends StatelessWidget {
  final EventPoll poll;
  const _EventPollCard({required this.poll});

  @override
  Widget build(BuildContext context) {
    // This is a simplified display card. The full voting UI would be on a detail page.
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "POLL",
            style: context.appStyle.captionStyle.copyWith(color: Colors.cyan),
          ),
          const SizedBox(height: 4),
          Text(
            poll.title,
            style: context.appStyle.headingStyle,
          ),
          const SizedBox(height: 8),
          Text(
            "You have ${poll.proposedTimes.length} time options. Tap to vote.",
            style: context.appStyle.bodyStyle,
          ),
        ],
      ),
    );
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