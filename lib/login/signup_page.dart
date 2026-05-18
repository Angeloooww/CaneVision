import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Country model ─────────────────────────────────────────────────
class _Country {
  final String name;
  final String flag;
  final String dialCode;
  final int digitCount; // expected local number length
  final String hint;

  const _Country({
    required this.name,
    required this.flag,
    required this.dialCode,
    required this.digitCount,
    required this.hint,
  });
}

const List<_Country> _countries = [
  _Country(name: 'Philippines', flag: '🇵🇭', dialCode: '+63', digitCount: 10, hint: '9XX XXX XXXX'),
  _Country(name: 'United States', flag: '🇺🇸', dialCode: '+1',  digitCount: 10, hint: 'XXX XXX XXXX'),
  _Country(name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44', digitCount: 10, hint: 'XXXX XXXXXX'),
  _Country(name: 'Australia', flag: '🇦🇺', dialCode: '+61', digitCount: 9,  hint: 'XXX XXX XXX'),
  _Country(name: 'Japan', flag: '🇯🇵', dialCode: '+81', digitCount: 10, hint: 'XX XXXX XXXX'),
  _Country(name: 'Singapore', flag: '🇸🇬', dialCode: '+65', digitCount: 8,  hint: 'XXXX XXXX'),
  _Country(name: 'Malaysia', flag: '🇲🇾', dialCode: '+60', digitCount: 9,  hint: 'XX XXXX XXXX'),
  _Country(name: 'Indonesia', flag: '🇮🇩', dialCode: '+62', digitCount: 10, hint: 'XXX XXXX XXXX'),
  _Country(name: 'Canada', flag: '🇨🇦', dialCode: '+1',  digitCount: 10, hint: 'XXX XXX XXXX'),
  _Country(name: 'India', flag: '🇮🇳', dialCode: '+91', digitCount: 10, hint: 'XXXXX XXXXX'),
  _Country(name: 'UAE', flag: '🇦🇪', dialCode: '+971', digitCount: 9,  hint: 'XX XXX XXXX'),
  _Country(name: 'Saudi Arabia', flag: '🇸🇦', dialCode: '+966', digitCount: 9, hint: 'XX XXX XXXX'),
];

// ── Signup Page ───────────────────────────────────────────────────
class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Default to Philippines
  _Country _selectedCountry = _countries[0];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Validate contact number ───────────────────────────────────
  String? _validateContact(String number) {
    final digits = number.replaceAll(RegExp(r'\D'), '');

    // PH-specific: must start with 9 and be exactly 10 digits
    if (_selectedCountry.dialCode == '+63') {
      if (digits.length != 10) {
        return 'PH number must be 10 digits (e.g. 9XX XXX XXXX).';
      }
      if (!digits.startsWith('9')) {
        return 'PH mobile numbers must start with 9.';
      }
      return null;
    }

    // Generic: check digit count
    if (digits.length != _selectedCountry.digitCount) {
      return '${_selectedCountry.name} numbers must be ${_selectedCountry.digitCount} digits.';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final contact = _contactNumberController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || contact.isEmpty ||
        email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError('Please fill in all required fields.');
      return;
    }

    final contactError = _validateContact(contact);
    if (contactError != null) {
      _showError(contactError);
      return;
    }

    if (password != confirmPassword) {
      _showError('Passwords do not match.');
      return;
    }

    if (password.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String uid = userCredential.user!.uid;

      final String fullName = middleName.isNotEmpty
          ? '$firstName $middleName $lastName'
          : '$firstName $lastName';

      // Store full international number e.g. "+63 917 123 4567"
      final String fullContact =
          '${_selectedCountry.dialCode} $contact';

      await _firestore.collection('users').doc(uid).set({
        'firstName': firstName,
        'middleName': middleName,
        'lastName': lastName,
        'fullName': fullName,
        'email': email,
        'contactNumber': fullContact,
        'countryCode': _selectedCountry.dialCode,
        'country': _selectedCountry.name,
        'role': 'Grader',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await userCredential.user!.updateDisplayName(fullName);
      await _auth.signOut();

      if (mounted) {
        _showSuccess(
            'Registration submitted! Please wait for admin approval before logging in.');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } on FirebaseAuthException catch (e) {
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

  // ── Country picker bottom sheet ───────────────────────────────
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Country',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: _countries.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF0F0F0)),
                itemBuilder: (_, i) {
                  final c = _countries[i];
                  final isSelected = c.dialCode == _selectedCountry.dialCode &&
                      c.name == _selectedCountry.name;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedCountry = c;
                        _contactNumberController.clear();
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFE8F8EF)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Text(c.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(c.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: const Color(0xFF1A1A1A))),
                          ),
                          Text(c.dialCode,
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF888888))),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.check_circle,
                                size: 18, color: Color(0xFF11BD51)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
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
        duration: const Duration(seconds: 3),
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
            // ── App bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44,
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
                    const SizedBox(height: 20),

                    // ── Icon card ──────────────────────────────
                    Container(
                      width: 110, height: 110,
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
                            width: 50, height: 50,
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
                    const SizedBox(height: 28),

                    // ── First Name ─────────────────────────────
                    _buildFieldLabel('First Name *', Icons.person_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _firstNameController,
                        hint: 'Enter your first name',
                        keyboardType: TextInputType.name),
                    const SizedBox(height: 16),

                    // ── Middle Name ────────────────────────────
                    _buildFieldLabel(
                        'Middle Name (optional)', Icons.person_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _middleNameController,
                        hint: 'Enter your middle name',
                        keyboardType: TextInputType.name),
                    const SizedBox(height: 16),

                    // ── Last Name ──────────────────────────────
                    _buildFieldLabel('Last Name *', Icons.person_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _lastNameController,
                        hint: 'Enter your last name',
                        keyboardType: TextInputType.name),
                    const SizedBox(height: 16),

                    // ── Contact Number ─────────────────────────
                    _buildFieldLabel(
                        'Contact Number *', Icons.phone_outlined),
                    const SizedBox(height: 8),
                    _buildContactField(),
                    const SizedBox(height: 6),
                    // Helper text
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${_selectedCountry.name}: ${_selectedCountry.digitCount} digits · ${_selectedCountry.hint}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF888888)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Email ──────────────────────────────────
                    _buildFieldLabel('Email *', Icons.email_outlined),
                    const SizedBox(height: 8),
                    _buildTextField(
                        controller: _emailController,
                        hint: 'Enter your email here',
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),

                    // ── Password ───────────────────────────────
                    _buildFieldLabel('Password *', Icons.lock_outline),
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
                          color: const Color(0xFF888888), size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Confirm Password ───────────────────────
                    _buildFieldLabel(
                        'Confirm Password *', Icons.lock_outline),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _confirmPasswordController,
                      hint: 'Re-enter your password',
                      obscureText: _obscureConfirmPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF888888), size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Info note ──────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFFFB300).withOpacity(0.4)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: Color(0xFFFFB300)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your account will be reviewed by an admin before you can log in.',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF795548)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Submit button ──────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleSignUp,
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
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5))
                            : const Text('Submit Registration',
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

  // ── Contact field with country code prefix ────────────────────
  Widget _buildContactField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          // Country code selector
          GestureDetector(
            onTap: _showCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                      color: Colors.grey.withOpacity(0.15), width: 1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedCountry.flag,
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 6),
                  Text(_selectedCountry.dialCode,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A))),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Color(0xFF888888)),
                ],
              ),
            ),
          ),
          // Number input
          Expanded(
            child: TextField(
              controller: _contactNumberController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_selectedCountry.digitCount),
              ],
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: _selectedCountry.hint,
                hintStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFFBBBBBB)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 14),
              ),
            ),
          ),
        ],
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