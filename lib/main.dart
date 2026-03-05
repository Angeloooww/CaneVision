import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase/firebase_options.dart';
import 'login/login_page.dart';
import 'main_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CaneVisionApp());
}

class CaneVisionApp extends StatelessWidget {
  const CaneVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CaneVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ECC71),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // AuthWrapper listens to Firebase auth state —
      // if logged out it always shows LoginPage, never auto-logs in
      home: const AuthWrapper(),
    );
  }
}

/// Listens to Firebase auth state changes in real time.
/// - If user is logged in  → show MainPage
/// - If user is logged out → show LoginPage (even after refresh/restart)
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for Firebase to respond
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFE8F8EF),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF27AE60),
                strokeWidth: 2.5,
              ),
            ),
          );
        }

        // User is logged in → go to MainPage
        if (snapshot.hasData && snapshot.data != null) {
          return const MainPage();
        }

        // User is logged out → go to LoginPage
        return const LoginPage();
      },
    );
  }
}