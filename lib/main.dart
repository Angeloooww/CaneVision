import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
          seedColor: const Color(0xFF11BD51),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  // 'loading' | 'login' | 'pending' | 'rejected' | 'home'
  String _state = 'loading';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _state = 'login');
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        setState(() => _state = 'login');
        return;
      }

      final data = doc.data()!;
      final status = (data['status'] ?? 'approved').toString();

      if (status == 'pending') {
        await FirebaseAuth.instance.signOut();
        setState(() => _state = 'pending');
      } else if (status == 'rejected') {
        await FirebaseAuth.instance.signOut();
        setState(() => _state = 'rejected');
      } else {
        setState(() => _state = 'home');
      }
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      setState(() => _state = 'login');
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case 'loading':
        return const _LoadingScreen();
      case 'pending':
        return const LoginPage(showPendingDialog: true);
      case 'rejected':
        return const LoginPage(showRejectedMessage: true);
      case 'home':
        return const MainPage();
      default:
        return const LoginPage();
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFE8F8EF),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF11BD51),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
