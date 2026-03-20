import 'package:flutter/material.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'analysis_page.dart'; // imports kGradeLookup and gradeQuality

class CertificatePage extends StatefulWidget {
  final String farmerName;
  final String farmId;
  final String farmerDocId;
  final String grade;
  final String quality;
  final int trashDiscount;
  final String remarkCode;
  final String remarkFull;

  const CertificatePage({
    super.key,
    required this.farmerName,
    required this.farmId,
    required this.farmerDocId,
    required this.grade,
    required this.quality,
    required this.trashDiscount,
    required this.remarkCode,
    required this.remarkFull,
  });

  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  String _graderName = '';
  String _graderEmail = '';
  bool _loadingGrader = true;

  @override
  void initState() {
    super.initState();
    _fetchGraderInfo();
  }

  // Fetch logged-in grader's name and email from Firestore
  Future<void> _fetchGraderInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _graderName = doc.data()?['fullName'] ?? user.displayName ?? 'Unknown';
            _graderEmail = doc.data()?['email'] ?? user.email ?? '';
          });
        }
      }
    } catch (_) {
      // fallback to Auth display name if Firestore fails
      final user = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() {
          _graderName = user?.displayName ?? 'Unknown';
          _graderEmail = user?.email ?? '';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingGrader = false);
    }
  }

  String get _certId {
    final rand = Random();
    final id1 = rand.nextInt(9000) + 1000;
    final id2 = rand.nextInt(900) + 100;
    final id3 = rand.nextInt(900) + 100;
    return 'CERT-$id1-$id2-$id3';
  }

  String get _today {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  String get _timestamp {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    return '${now.month}/${now.day}/${now.year}, $h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final certId = _certId;

    // Resolve advisory from the same lookup table used in AnalysisPage
    final gradeKey = widget.grade.toUpperCase();
    final info = kGradeLookup[gradeKey] ?? kGradeLookup['FF']!;
    final String advisory = info['advisory'] as String;

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
                      border: Border.all(
                          color: const Color(0xFF11BD51), width: 2),
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

            // ── Certificate Card ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 4),
                child: Container(
                  width: double.infinity,
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
                    children: [
                      // ── Certificate Header ────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF11BD51)
                                    .withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF11BD51),
                                    width: 2),
                              ),
                              child: const Icon(Icons.workspace_premium,
                                  color: Color(0xFF11BD51), size: 28),
                            ),
                            const SizedBox(height: 12),
                            const Text('Certificate of Quality',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A))),
                            const SizedBox(height: 4),
                            const Text(
                                'Sugarcane Quality Assessment Report',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF888888))),
                            const SizedBox(height: 4),
                            Text('Certificate ID: $certId',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFAAAAAA))),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Farmer Information ────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.person_outline,
                                    size: 15, color: Color(0xFF555555)),
                                SizedBox(width: 6),
                                Text('Farmer Information',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Name', widget.farmerName),
                            const SizedBox(height: 6),
                            _buildInfoRow('Farm ID', widget.farmId),
                            const SizedBox(height: 6),
                            _buildInfoRow('Inspection Date', _today),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Graded By ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.badge_outlined,
                                    size: 15, color: Color(0xFF555555)),
                                SizedBox(width: 6),
                                Text('Graded By',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _loadingGrader
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF11BD51),
                                        strokeWidth: 2),
                                  )
                                : Column(
                                    children: [
                                      _buildInfoRow(
                                          'Quality Grader', _graderName),
                                      const SizedBox(height: 6),
                                      _buildInfoRow('Email', _graderEmail),
                                    ],
                                  ),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Grade Banner ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF11BD51),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.workspace_premium,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(widget.grade,
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white)),
                                  Text(widget.quality,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Quality Parameters ────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.check_circle_outline,
                                    size: 15, color: Color(0xFF11BD51)),
                                SizedBox(width: 6),
                                Text('Quality Parameters',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1A1A1A))),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Trash Discount
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Trash Discount',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF888888))),
                                      const SizedBox(height: 4),
                                      Text('${widget.trashDiscount}%',
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A1A))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Remarks
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Remarks',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF888888))),
                                      const SizedBox(height: 4),
                                      Text(widget.remarkCode,
                                          style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF1A1A1A))),
                                      const SizedBox(height: 2),
                                      Text(widget.remarkFull,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF888888),
                                              height: 1.4)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Operational Advisory ──────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.info_outline,
                                    size: 15, color: Color(0xFFF39C12)),
                                SizedBox(width: 6),
                                Text('Operational Advisory',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF39C12))),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBF0),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFF39C12)
                                        .withOpacity(0.35),
                                    width: 1),
                              ),
                              child: Text(
                                advisory,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF555555),
                                    height: 1.6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Verified Note ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Text(
                          'This certificate is digitally generated and verified.\nGenerated on $_timestamp',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFFAAAAAA),
                              height: 1.6),
                        ),
                      ),

                      const Divider(color: Color(0xFFF0F0F0), height: 1),

                      // ── Action Buttons ────────────────────────
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildActionButton(
                              icon: Icons.download_outlined,
                              label: 'Download Certificate',
                              onTap: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(_snackBar(
                                      'Download feature coming soon!')),
                            ),
                            const SizedBox(height: 10),
                            _buildActionButton(
                              icon: Icons.send_outlined,
                              label: 'Send to Farmer',
                              onTap: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(_snackBar(
                                      'Send feature coming soon!')),
                            ),
                            const SizedBox(height: 10),
                            _buildActionButton(
                              icon: Icons.qr_code_scanner_outlined,
                              label: 'Scan New Sugarcane',
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF888888))),
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A))),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF11BD51).withOpacity(0.4), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF11BD51)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF11BD51))),
          ],
        ),
      ),
    );
  }

  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF11BD51),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      );
}