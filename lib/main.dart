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
  // await dotenv.load(fileName: '.env');
  AppEnv.checkValues();

  bool firebaseInitialized = false;

  try {
    print("Attempting Firebase.initializeApp()...");
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print("Firebase.initializeApp() completed successfully.");
    firebaseInitialized = true;
  } on FirebaseException catch (e) {
    if (e.code == 'duplicate-app') {
      print("Firebase.initializeApp() failed with 'duplicate-app'. Assuming already initialized.");
      firebaseInitialized = true; // Treat as success for further steps
    } else {
      print("Firebase.initializeApp() failed with error: ${e.code} - ${e.message}");
      // For other Firebase errors, you might want to handle them differently or rethrow.
    }
  } catch (e, s) {
    // Catch any other non-Firebase exceptions during initializeApp
    print("An unexpected error occurred during Firebase.initializeApp(): $e");
    print("Stack trace: $s");
  }

  if (firebaseInitialized) {
    try {
      print("Activating Firebase App Check...");
      await FirebaseAppCheck.instance.activate(
        androidProvider:
        kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
        kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
      print("Firebase App Check activated successfully.");

      print("Initializing Notification Service...");
      final NotificationService notificationService = NotificationService();
      await notificationService.initNotifications();
      print("Notification Service initialized successfully.");

      print("All services initialized. Running app.");
      runApp(const MainApp());
    } catch (e, s) {
      print("Error initializing AppCheck or NotificationService: $e");
      print("Stack trace: $s");
      // Decide how to proceed if these secondary services fail
      // Maybe runApp with an error message or a limited functionality app
      runApp(const MainApp()); // Or an error widget
    }
  } else {
    print("Firebase could not be initialized. App might not function correctly.");
    // Decide how to proceed if Firebase is absolutely critical and did not initialize
    // runApp(const FirebaseErrorApp()); // Example: Show an error screen
    runApp(const MainApp()); // Or try to run the app anyway, it will likely crash at Firebase usage
  }
}

// ... (Rest of your MainApp, MyApp, UndoSnackBarHandler, AuthenticationWrapper classes remain the same) ...
// (Make sure they are identical to the previous version you posted)
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
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
        ChangeNotifierProvider(create: (_) => GroupState()),
        ChangeNotifierProvider(create: (_) => ProposalState()),
        ChangeNotifierProvider(create: (_) => NotificationState()),
        ChangeNotifierProvider(create: (_) => TaskState()),
        ChangeNotifierProvider(create: (_) => AppStyleProvider()),
      ],
      child: const MyApp(),
    );
  }
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

