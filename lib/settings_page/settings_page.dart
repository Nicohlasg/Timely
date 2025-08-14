import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../state/profile_state.dart';
import '../profile_page/edit_profile_page.dart';
import 'appearance_page.dart';
import 'sync_calendars_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<SettingsItem> settingsOptions = <SettingsItem>[
      SettingsItem(icon: Icons.person, title: 'Account'),
      SettingsItem(icon: Icons.notifications, title: 'Notifications'),
      SettingsItem(icon: Icons.remove_red_eye, title: 'Appearance'),
      SettingsItem(icon: Icons.sync_alt, title: 'Sync Calendars'),
      SettingsItem(icon: Icons.lock, title: 'Privacy & Security'),
      SettingsItem(icon: Icons.headset_mic, title: 'Help and Support'),
      SettingsItem(icon: Icons.help_outline, title: 'About'),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(),
            ),
            ...settingsOptions.map<Widget>((SettingsItem item) {
              return SettingsOptionTile(
                item: item,
                onTap: () {
                  if (item.title == 'Account') {
                    final profileState = context.read<ProfileState>();
                    if (profileState.userProfile != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (BuildContext context) => EditProfilePage(
                            userProfile: profileState.userProfile!,
                          ),
                          fullscreenDialog: true,
                        ),
                      );
                    }
                  } else if (item.title == 'Appearance') {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const AppearancePage(),
                      ),
                    );
                  }
                  else if (item.title == 'Sync Calendars') {
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) => const SyncCalendarsPage(),
                      ),
                    );
                  }
                  else {
                    debugPrint('Tapped on ${item.title}');
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('Error signing out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }
}

class SettingsItem {
  final IconData icon;
  final String title;
  const SettingsItem({required this.icon, required this.title});
}

class SettingsOptionTile extends StatelessWidget {
  final SettingsItem item;
  final VoidCallback? onTap;
  const SettingsOptionTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          leading: Icon(item.icon, color: Colors.white),
          title: Text(
            item.title,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white70),
          onTap: onTap,
        ),
        const Divider(height: 1, color: Colors.white24),
      ],
    );
  }
}
