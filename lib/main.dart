import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/profile_gate.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  await ThemeController.instance.load();
  runApp(const GigTasksApp());
}

class GigTasksApp extends StatelessWidget {
  const GigTasksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: 'GigTasks',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: ValueListenableBuilder<bool>(
          valueListenable: AuthService.registering,
          builder: (context, registering, _) => StreamBuilder<User?>(
            stream: AuthService.userStream, // same stream object every rebuild
            builder: (context, snap) {
              if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
              }
              final user = snap.data;
              // While sign-up finishes claiming the username, stay on the auth screen.
              if (user == null || registering) return const AuthScreen();
              return ProfileGate(key: ValueKey(user.uid), user: user);
            },
          ),
        ),
      ),
    );
  }
}
