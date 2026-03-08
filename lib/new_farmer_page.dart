import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NewFarmerPage extends StatefulWidget {
  const NewFarmerPage({super.key});

  @override
  State<NewFarmerPage> createState() => _NewFarmerPageState();
}

class _NewFarmerPageState extends State<NewFarmerPage> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _farmIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _fullNameController.dispose();
    _farmIdController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // ── Save Farmer to Firestore ──────────────────────────────────
  Future<void> _saveFarmer() async {
    if (_fullNameController.text.trim().isEmpty ||
        _farmIdController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _auth.currentUser?.uid ?? '';

      // Save new farmer document to Firestore "farmers" collection
      await _firestore.collection('farmers').add({
        'fullName': _fullNameController.text.trim(),
        'farmId': _farmIdController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'grade': '--',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${_fullNameController.text.trim()} added successfully!'),
            backgroundColor: const Color(0xFF27AE60),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
        // Go back to main page — farmer will appear automatically via StreamBuilder
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to save farmer. Please try again.');
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
            // ── Top App Bar ───────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF11BD51), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),

                    // Back button + title
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ],
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                size: 16, color: Color(0xFF1A1A1A)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('Add New Farmer',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A))),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // ── Form Card ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Farmer Details',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 4),
                          const Text(
                              'This farmer will appear in the Registered Farmers list',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888))),

                          const SizedBox(height: 20),

                          // Full Name
                          _buildFieldLabel(
                              'Full Name', Icons.person_outline),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _fullNameController,
                            hint: 'Enter farmer\'s full name',
                            keyboardType: TextInputType.name,
                          ),

                          const SizedBox(height: 18),

                          // Farm ID
                          _buildFieldLabel(
                              'Farm ID', Icons.tag_outlined),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _farmIdController,
                            hint: 'e.g. FARM-882',
                          ),

                          const SizedBox(height: 18),

                          // Phone
                          _buildFieldLabel(
                              'Phone Number', Icons.phone_outlined),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _phoneController,
                            hint: 'e.g. 09723726322',
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 18),

                          // Email
                          _buildFieldLabel(
                              'Email Address', Icons.email_outlined),
                          const SizedBox(height: 8),
                          _buildTextField(
                            controller: _emailController,
                            hint: 'Enter farmer\'s email address',
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ── Save Button ───────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveFarmer,
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
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Save Farmer',
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
        Icon(icon, size: 16, color: const Color(0xFF444444)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333))),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
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