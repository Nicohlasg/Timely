import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../state/notification_state.dart';
import '../models/app_notification.dart';
import '../widgets/background_container.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackgroundImageContainer(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text('Notifications', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<NotificationState>(
          builder: (context, state, _) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.notifications.isEmpty) {
              return Center(
                child: Text('No notifications yet.', style: GoogleFonts.inter(color: Colors.white70)),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final n = state.notifications[index];
                return _NotificationTile(notification: n);
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final ts = DateFormat.yMMMEd().add_jm().format(notification.createdAt.toDate());
    switch (notification.type) {
      case 'proposalAccepted':
        return ListTile(
          leading: const Icon(Icons.event_available, color: Colors.greenAccent),
          title: Text('Proposal accepted: ${notification.title}', style: const TextStyle(color: Colors.white)),
          subtitle: Text(ts, style: const TextStyle(color: Colors.white70)),
        );
      default:
        return ListTile(
          leading: const Icon(Icons.notifications, color: Colors.cyanAccent),
          title: Text(notification.title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(ts, style: const TextStyle(color: Colors.white70)),
        );
    }
  }
}


