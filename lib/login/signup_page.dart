import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _orgIdController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // Firebase instances
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _orgIdController.dispose();
    super.dispose();
  }

  // ── SIGN UP LOGIC ─────────────────────────────────────────────
  Future<void> _handleSignUp() async {
    // Basic validation
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _orgIdController.text.trim().isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Create user in Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // Step 2: Save extra user details to Firestore
      // This creates a document in the "users" collection with the user's UID as the document ID
      await _firestore.collection('users').doc(uid).set({
        'fullName': _fullNameController.text.trim(),
        'email': _emailController.text.trim(),
        'organizationId': _orgIdController.text.trim(),
        'role': 'Quality Grader',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Step 3: Update Firebase Auth display name
      await userCredential.user!.updateDisplayName(
        _fullNameController.text.trim(),
      );

      // Step 4: Sign out immediately — Firebase auto-logs in after
      // createUserWithEmailAndPassword, so we sign out to force the
      // user to log in manually. AuthWrapper will redirect to LoginPage.
      await _auth.signOut();

      if (mounted) {
        _showSuccess('Account created! Please log in.');
        // Go back to login page after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase Auth errors
      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;
        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        default:
          message = 'Sign up failed. Please try again.';
      }
      _showError(message);
    } catch (e) {
      _showError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.agriculture,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'CaneVision',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 30),

                    // Grader Icon Card
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
                            offset: const Offset(0, 4),
                          ),
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

                    // Tab Toggle
                    Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Login tab
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                margin: const EdgeInsets.all(4),
                                alignment: Alignment.center,
                                child: const Text('Login',
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF888888))),
                              ),
                            ),
                          ),
                          // Sign up tab — active
                          Expanded(
                            child: Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A4A4A),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              alignment: Alignment.center,
                              child: const Text('Sign up',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Full Name
                    _buildFieldLabel('Full name', Icons.person_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _fullNameController,
                      hint: 'Enter your full name here',
                      keyboardType: TextInputType.name,
                    ),

                    const SizedBox(height: 20),

                    // Email
                    _buildFieldLabel('Email', Icons.email_outlined),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Enter your email here',
                      keyboardType: TextInputType.emailAddress,
                    ),

                    const SizedBox(height: 20),

                    // Password
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

                    const SizedBox(height: 20),

                    // Organization ID
                    _buildFieldLabel('Organization ID', Icons.business_outlined),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _orgIdController,
                      hint: 'Enter your organization ID here',
                    ),

                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2B2FD9),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF2B2FD9).withOpacity(0.6),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Sign up as Quality Grader',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3),
                              ),
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