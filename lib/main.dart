import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:month_year_picker/month_year_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';
import 'home_page/home_page.dart';

import 'login_page/login_page.dart';
import 'login_page/register_page.dart';
import 'login_page/forgot_password_page.dart';

import 'calendar_page/calendar_page.dart';

import 'profile_page/profile_page.dart';

import 'settings_page/settings_page.dart';

import 'services/notification_service.dart';
import 'services/google_calendar_service.dart';
import 'state/friend_state.dart';
import 'state/sync_state.dart';
import 'state/poll_state.dart';
import 'state/calendar_state.dart';
import 'state/group_state.dart';
import 'state/profile_state.dart';
import 'state/proposal_state.dart';
import 'state/notification_state.dart';
import 'state/task_state.dart';

import 'Theme/app_styles.dart';
import 'environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
    appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );
  final NotificationService notificationService = NotificationService();
  await notificationService.initNotifications();

  // Optional debug check
  assert(() {
    for (final k in [
      'GOOGLE_SERVER_CLIENT_ID',
      'CHAT_FUNCTION_URL',
      'SYNC_STORE_TOKEN_URL',
      'SYNC_CALENDAR_URL',
      'OCR_FUNCTION_URL'
    ]) {
      if (dotenv.env[k] == null) {
        debugPrint('Env var not set: $k (may rely on --dart-define)');
      }
    }
    return true;
  }());
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => GoogleCalendarService()),
        ChangeNotifierProvider(create: (_) => CalendarState()),
        ChangeNotifierProvider(create: (_) => ProfileState()),
        ChangeNotifierProvider(create: (_) => FriendState()),
        ChangeNotifierProvider(
          create: (context) => SyncState(
            context.read<GoogleCalendarService>(),
            context.read<CalendarState>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => PollState()),
        // In your MultiProvider list
        ChangeNotifierProvider(create: (_) => GroupState()),
        ChangeNotifierProvider(create: (_) => ProposalState()),
        ChangeNotifierProvider(create: (_) => NotificationState()),
        ChangeNotifierProvider(create: (_) => TaskState()),
        // Add the style provider for theme management
        ChangeNotifierProvider(create: (_) => AppStyleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      builder: (context, child) => UndoSnackBarHandler(child: child!),
      home: const AuthenticationWrapper(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/calendar': (context) => const CalendarPage(),
        '/profile': (context) => const ProfilePage(),
        '/settings': (context) => const SettingsPage(),
        '/forgot_password': (context) => const ForgotPasswordPage(),
      },
    );
  }
}

class UndoSnackBarHandler extends StatefulWidget {
  final Widget child;
  const UndoSnackBarHandler({super.key, required this.child});

  @override
  State<UndoSnackBarHandler> createState() => _UndoSnackBarHandlerState();
}

class _UndoSnackBarHandlerState extends State<UndoSnackBarHandler> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<CalendarState>().addListener(_showUndoSnackBarIfNeeded);
      } catch (e) {
        // Silently ignore.
      }
    });
  }

  @override
  void dispose() {
    try {
      context.read<CalendarState>().removeListener(_showUndoSnackBarIfNeeded);
    } catch (e) {
      // Silently ignore.
    }
    super.dispose();
  }

  void _showUndoSnackBarIfNeeded() {
    if (!mounted) return;

    final calendarState = context.read<CalendarState>();
    if (calendarState.lastDeletedEvent != null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      final snackBar = SnackBar(
        backgroundColor: const Color(0xFF2D3748),
        content: Text(
          'Event deleted',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.blue,
          onPressed: () {
            calendarState.undoDeletion();
          },
        ),
        dismissDirection: DismissDirection.horizontal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.white30),
        ),
        margin: const EdgeInsets.all(16),
      );

      messenger.showSnackBar(snackBar).closed.then((reason) {
        if (reason != SnackBarClosedReason.action) {
          calendarState.dismissUndo();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class AuthenticationWrapper extends StatelessWidget {
  const AuthenticationWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}
