import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'history_page.dart';
import 'settings_page.dart';
import 'account_page.dart';

/// Hamburger sidebar for CaneVision.
/// [onLogout] is called when the user taps Log Out (reuse MainPage._logout).
class AppDrawer extends StatelessWidget {
  final VoidCallback onLogout;
  const AppDrawer({super.key, required this.onLogout});

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context); // close drawer
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => page,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(color: Color(0xFFE8F8EF)),
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: user == null
                    ? null
                    : FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .get(),
                builder: (context, snap) {
                  final data = snap.data?.data();
                  final name =
                      (data?['fullName'] ?? user?.displayName ?? 'Grader')
                          .toString();
                  final email =
                      (data?['email'] ?? user?.email ?? '').toString();
                  final initial =
                      name.isNotEmpty ? name[0].toUpperCase() : 'G';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: Color(0xFF11BD51),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(initial,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 12),
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 2),
                      Text(email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF666666))),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            _item(Icons.history, 'History',
                () => _open(context, const HistoryPage())),
            _item(Icons.settings_outlined, 'Settings',
                () => _open(context, const SettingsPage())),
            _item(Icons.person_outline, 'Account',
                () => _open(context, const AccountPage())),

            const Spacer(),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            _item(Icons.logout, 'Log Out', () {
              Navigator.pop(context);
              onLogout();
            }, color: Colors.redAccent),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap,
      {Color color = const Color(0xFF1A1A1A)}) {
    return ListTile(
      leading: Icon(icon,
          size: 22,
          color: color == Colors.redAccent ? color : const Color(0xFF11BD51)),
      title: Text(label,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}