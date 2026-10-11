import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';
import '../main_page.dart';

class LoginPage extends StatefulWidget {
  final bool showPendingDialog;
  final bool showRejectedMessage;

  const LoginPage({
    super.key,
    this.showPendingDialog = false,
    this.showRejectedMessage = false,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _agreedToTerms = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    // Show dialog after first frame so context is ready
    if (widget.showPendingDialog) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPendingDialog();
      });
    }
    if (widget.showRejectedMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showError(
            'Your account has been rejected. Please contact your administrator.');
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    if (!_agreedToTerms) {
      _showError('Please agree to the Terms and Services to continue.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = credential.user!.uid;
      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        _showError('Account not found.');
        setState(() => _isLoading = false);
        return;
      }

      final data = doc.data()!;

      final role = (data['role'] ?? '').toString();
      if (role == 'Admin') {
        await _auth.signOut();
        setState(() => _isLoading = false);
        _showError('Access denied.');
        return;
      }

      final status = (data['status'] ?? 'approved').toString();

      if (status == 'pending') {
        await _auth.signOut();
        setState(() => _isLoading = false);
        _showPendingDialog();
        return;
      }

      if (status == 'rejected') {
        await _auth.signOut();
        setState(() => _isLoading = false);
        _showError(
            'Your account has been rejected. Please contact your administrator.');
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const MainPage(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'invalid-credential':
          message = 'Invalid credentials. Please try again.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;
        default:
          message = 'Login failed. Please try again.';
      }
      _showError(message);
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  size: 32, color: Color(0xFFFFB300)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Waiting for Admin Approval',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 10),
            const Text(
              'Your account is waiting for admin approval. You will be able to log in once an admin approves your registration.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF666666), height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11BD51),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: const Color(0xFF11BD51), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/images/logo.png',
                          width: 40, height: 40, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('CaneVision',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F8EF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.assignment_outlined,
                                color: Color(0xFF27AE60), size: 28),
                          ),
                          const SizedBox(height: 8),
                          const Text('Grader',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A))),
                          const Text('Grade sugarcane',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF888888))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    _buildFieldLabel('Email', Icons.email_outlined),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _emailController,
                        hint: 'Enter your email here',
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 20),

                    _buildFieldLabel('Password', Icons.lock_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Enter password here',
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF888888),
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Terms and Services checkbox ──────────────────
                    TermsCheckbox(
                      value: _agreedToTerms,
                      onChanged: (v) => setState(() => _agreedToTerms = v),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF888888))),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            PageRouteBuilder(
                              pageBuilder: (_, animation, __) =>
                                  const SignupPage(),
                              transitionsBuilder:
                                  (_, animation, __, child) => FadeTransition(
                                      opacity: animation, child: child),
                              transitionDuration:
                                  const Duration(milliseconds: 250),
                            ),
                          ),
                          child: const Text('Sign up here',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF11BD51),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF11BD51),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF11BD51).withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('Login as Quality Grader',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3)),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 17, color: const Color(0xFF444444)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
        filled: true,
        fillColor: Colors.white,
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: Colors.grey.withOpacity(0.15), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFF27AE60), width: 1.5),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TERMS AND SERVICES
// ════════════════════════════════════════════════════════════════

/// Shows the Terms and Services in a scrollable dialog.
Future<void> showTermsDialog(BuildContext context) {
  const heading = TextStyle(
      fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A));
  const body =
      TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF555555));

  Widget section(String title, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: heading),
            const SizedBox(height: 3),
            Text(text, style: body),
          ],
        ),
      );

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Terms and Services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('1. Acceptance of Terms',
                  'By creating an account or using CaneVision, you agree to these Terms and Services. If you do not agree, please do not use the app.'),
              section('2. Use of the App',
                  'CaneVision is a sugarcane grading tool. You agree to use it only for lawful, work-related purposes and to scan only samples you are authorized to grade.'),
              section('3. Accounts and Approval',
                  'New accounts may require approval before access is granted. You are responsible for keeping your login credentials secure and for all activity under your account.'),
              section('4. Farmer Information',
                  'You may enter farmers\' names, Farm IDs, emails and phone numbers. You confirm you have permission to record this information and agree to use it only for grading and record-keeping.'),
              section('5. Grading Results',
                  'Grades are produced by an automated model and are meant to assist, not replace, professional judgment. Results may not always be accurate, and you are responsible for decisions made based on them.'),
              section('6. Privacy and Data',
                  'Account, farmer and scan data are stored in our cloud database and used to operate the app. We do not sell your personal data.'),
              section('7. Suspension or Termination',
                  'Accounts that misuse the app or violate these terms may be suspended or removed.'),
              section('8. Changes to These Terms',
                  'We may update these terms from time to time. Continued use of the app means you accept the updated terms.'),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('I Understand',
              style: TextStyle(
                  color: Color(0xFF11BD51), fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

/// Checkbox row: "I agree to the Terms and Services" (link opens the terms).
class TermsCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  late final TapGestureRecognizer _tap;

  @override
  void initState() {
    super.initState();
    _tap = TapGestureRecognizer()..onTap = () => showTermsDialog(context);
  }

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: widget.value,
            activeColor: const Color(0xFF11BD51),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (v) => widget.onChanged(v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms and Services',
                  recognizer: _tap,
                  style: const TextStyle(
                    color: Color(0xFF11BD51),
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}