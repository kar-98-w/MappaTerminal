import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/navbar.dart'; // ✅ Import your navbar
import 'screens/login_screen.dart'; // still used for account tab

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MyApp());
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SF Pampanga Terminals',
      debugShowCheckedModeBanner: false,
      // ✅ Start with the navigation bar
      home: const NavBar(isAdmin: false),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}
