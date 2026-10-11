import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shows the logged-in grader's info and lets them change their password.
/// The password is changed in Firebase Authentication (where it is actually
/// stored), after re-authenticating with the current password.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isChanging = false;
  bool _formOpen = false;

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.redAccent : const Color(0xFF11BD51),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _snack('Please fill in all password fields.', error: true);
      return;
    }
    if (next.length < 6) {
      _snack('New password must be at least 6 characters.', error: true);
      return;
    }
    if (next != confirm) {
      _snack('New passwords do not match.', error: true);
      return;
    }
    if (next == current) {
      _snack('New password must be different from the current one.',
          error: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      _snack('No signed-in account found.', error: true);
      return;
    }

    setState(() => _isChanging = true);

    try {
      // 1. Re-authenticate with the current password
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: current);
      await user.reauthenticateWithCredential(cred);

      // 2. Update the password in Firebase Auth (the real login)
      await user.updatePassword(next);

      // 3. Optional: log the change in Firestore (never store the password).
      //    Non-fatal if your security rules don't allow it.
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'passwordChangedAt': FieldValue.serverTimestamp()});
      } catch (_) {}

      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      if (mounted) setState(() => _formOpen = false);
      _snack('Password changed successfully!');
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          _snack('Current password is incorrect.', error: true);
          break;
        case 'weak-password':
          _snack('New password is too weak.', error: true);
          break;
        case 'requires-recent-login':
          _snack('Please log out and log in again, then retry.',
              error: true);
          break;
        case 'too-many-requests':
          _snack('Too many attempts. Try again later.', error: true);
          break;
        default:
          _snack('Failed to change password (${e.code}).', error: true);
      }
    } catch (e) {
      _snack('Failed to change password. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isChanging = false);
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '—';
    const m = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
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
                  const Text('Account',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A))),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _user == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(_user.uid)
                        .get(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name =
                      (data?['fullName'] ?? _user?.displayName ?? 'Grader')
                          .toString();
                  final email =
                      (data?['email'] ?? _user?.email ?? '').toString();
                  final status =
                      (data?['status'] ?? 'approved').toString();
                  final initial =
                      name.isNotEmpty ? name[0].toUpperCase() : 'G';

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // ── Profile card ─────────────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF11BD51),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(initial,
                                    style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white)),
                              ),
                              const SizedBox(height: 12),
                              Text(name,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A))),
                              const SizedBox(height: 2),
                              const Text('Quality Grader',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF888888))),
                              const SizedBox(height: 18),
                              const Divider(color: Color(0xFFF0F0F0)),
                              const SizedBox(height: 6),
                              _infoRow(Icons.email_outlined, 'Email', email),
                              _infoRow(Icons.verified_user_outlined,
                                  'Status', status[0].toUpperCase() +
                                      status.substring(1)),
                              _infoRow(
                                  Icons.calendar_today_outlined,
                                  'Member since',
                                  _formatDate(
                                      _user?.metadata.creationTime)),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Change password card ─────────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: _cardDecoration(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () =>
                                    setState(() => _formOpen = !_formOpen),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_outline,
                                        size: 18,
                                        color: Color(0xFF11BD51)),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text('Change Password',
                                          style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A1A))),
                                    ),
                                    Icon(
                                        _formOpen
                                            ? Icons.expand_less
                                            : Icons.expand_more,
                                        color: const Color(0xFF888888)),
                                  ],
                                ),
                              ),
                              if (_formOpen) ...[
                                const SizedBox(height: 16),
                                _label('Current Password'),
                                const SizedBox(height: 6),
                                _passField(
                                  _currentCtrl,
                                  'Enter current password',
                                  _showCurrent,
                                  () => setState(
                                      () => _showCurrent = !_showCurrent),
                                ),
                                const SizedBox(height: 14),
                                _label('New Password'),
                                const SizedBox(height: 6),
                                _passField(
                                  _newCtrl,
                                  'At least 6 characters',
                                  _showNew,
                                  () => setState(() => _showNew = !_showNew),
                                ),
                                const SizedBox(height: 14),
                                _label('Confirm New Password'),
                                const SizedBox(height: 6),
                                _passField(
                                  _confirmCtrl,
                                  'Re-enter new password',
                                  _showConfirm,
                                  () => setState(
                                      () => _showConfirm = !_showConfirm),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isChanging ? null : _changePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF11BD51),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          const Color(0xFF11BD51)
                                              .withOpacity(0.6),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                    child: _isChanging
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5))
                                        : const Text('Update Password',
                                            style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
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

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      );

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF888888)),
          const SizedBox(width: 10),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A))),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333)));

  Widget _passField(TextEditingController c, String hint, bool visible,
      VoidCallback toggle) {
    return TextField(
      controller: c,
      obscureText: !visible,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
        filled: true,
        fillColor: const Color(0xFFF7F7F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: const Color(0xFF888888)),
          onPressed: toggle,
        ),
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
              const BorderSide(color: Color(0xFF11BD51), width: 1.5),
        ),
      ),
    );
  }
}