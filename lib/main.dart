import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase/firebase_options.dart';
import 'login/login_page.dart';
import 'main_page.dart';
import 'model_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await ModelService().loadModel();
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
      home: const SplashScreen(),
    );
  }
}

// ── Splash Screen ─────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final AnimationController _textCtrl;
  late final AnimationController _shimmerCtrl;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _shimmer;

  String? _authState;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkAuth();
  }

  void _setupAnimations() {
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);
    _logoScale = Tween<double>(begin: 0.70, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut),
    );
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _logoCtrl.forward();
    });

    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _textCtrl.forward();
    });

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _shimmer = Tween<double>(begin: -1.5, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut),
    );
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _shimmerCtrl.forward();
    });
  }

  Future<void> _checkAuth() async {
    final minimumDelay = Future.delayed(const Duration(milliseconds: 2600));
    String result;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      result = 'login';
    } else {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          result = 'login';
        } else {
          final data = doc.data()!;
          final status = (data['status'] ?? 'approved').toString();
          if (status == 'pending') {
            await FirebaseAuth.instance.signOut();
            result = 'pending';
          } else if (status == 'rejected') {
            await FirebaseAuth.instance.signOut();
            result = 'rejected';
          } else {
            result = 'home';
          }
        }
      } catch (_) {
        await FirebaseAuth.instance.signOut();
        result = 'login';
      }
    }

    await minimumDelay;
    if (mounted) setState(() => _authState = result);
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Widget _buildDestination() {
    switch (_authState) {
      case 'pending':  return const LoginPage(showPendingDialog: true);
      case 'rejected': return const LoginPage(showRejectedMessage: true);
      case 'home':     return const MainPage();
      default:         return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authState != null) return _buildDestination();

    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_logoCtrl, _textCtrl, _shimmerCtrl]),
        builder: (context, _) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 180,
                      height: 180,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // App name + tagline
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) {
                            final s = _shimmer.value;
                            return LinearGradient(
                              begin: Alignment(s - 0.6, 0),
                              end: Alignment(s + 0.6, 0),
                              colors: const [
                                Color(0xFF11BD51),
                                Color(0xFF0DD668),
                                Colors.white,
                                Color(0xFF0DD668),
                                Color(0xFF11BD51),
                              ],
                              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                            ).createShader(bounds);
                          },
                          child: const Text(
                            'CaneVision',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Sugarcane Grading System',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3A9E62),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        const _LoadingDots(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Animated loading dots ─────────────────────────────────────────────────────

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _anims = _ctrls
        .map((c) => Tween<double>(begin: 0.3, end: 1.0).animate(
              CurvedAnimation(parent: c, curve: Curves.easeInOut),
            ))
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Opacity(
              opacity: _anims[i].value,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF11BD51),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}