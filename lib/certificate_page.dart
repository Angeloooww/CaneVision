import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
  /// Optional: local file path of the scanned sugarcane image.
  /// When provided the image is shown on the certificate and uploaded
  /// to Firebase Storage so the admin dashboard can display it.
  final String? imagePath;

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
    this.imagePath,
  });

  @override
  State<CertificatePage> createState() => _CertificatePageState();
}

class _CertificatePageState extends State<CertificatePage> {
  String _graderName = '';
  String _graderEmail = '';
  bool _loadingGrader = true;

  // ── Database save state ──────────────────────────────────────
  bool _isSaving = true;
  bool _saveSuccess = false;
  String _saveError = '';
  String _savedCertId = '';
  String _uploadedPhotoUrl = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _fetchGraderInfo();
    await _saveGradeRecord();
  }

  // ── Fetch logged-in grader from Firestore ──────────────────────
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
            _graderName =
                doc.data()?['fullName'] ?? user.displayName ?? 'Unknown';
            _graderEmail = doc.data()?['email'] ?? user.email ?? '';
          });
        }
      }
    } catch (_) {
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

  // ── Upload photo to Firebase Storage ──────────────────────────
  Future<String> _uploadPhoto(String certId) async {
    if (widget.imagePath == null || widget.imagePath!.isEmpty) return '';
    try {
      final file = File(widget.imagePath!);
      if (!await file.exists()) return '';
      final ext = widget.imagePath!.split('.').last.toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('grade_photos/$certId.$ext');
      final task = await ref.putFile(file);
      return await task.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Photo upload error: $e');
      return ''; // non-fatal — record is saved without photo
    }
  }

  // ── Save grade record to Firestore `grades` collection ────────
  Future<void> _saveGradeRecord() async {
    final certId = _generateCertId();
    try {
      final photoUrl = await _uploadPhoto(certId);
      if (mounted) setState(() => _uploadedPhotoUrl = photoUrl);

      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('grades').add({
        'certId': certId,
        'farmerName': widget.farmerName,
        'farmId': widget.farmId,
        'farmerDocId': widget.farmerDocId,
        'grade': widget.grade,
        'quality': widget.quality,
        'trashDiscount': widget.trashDiscount,
        'remarkCode': widget.remarkCode,
        'remarkFull': widget.remarkFull,
        'graderUid': user?.uid ?? '',
        'graderName': _graderName,
        'graderEmail': _graderEmail,
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccess = true;
          _savedCertId = certId;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveSuccess = false;
          _saveError = e.toString();
        });
      }
    }
  }

  String _generateCertId() {
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                        width: 40, height: 40, fit: BoxFit.cover,
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

            // ── Save Status Banner ────────────────────────────────
            _buildSaveBanner(),

            // ── Certificate Card ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
                      // ── Scanned Photo (if available) ──────────
                      if (widget.imagePath != null &&
                          widget.imagePath!.isNotEmpty)
                        _buildScannedPhoto(),

                      // ── Certificate Header ────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                        child: Column(
                          children: [
                            Container(
                              width: 56, height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFF11BD51).withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF11BD51), width: 2),
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
                            const Text('Sugarcane Quality Assessment Report',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFF888888))),
                            const SizedBox(height: 4),
                            Text(
                              _savedCertId.isNotEmpty
                                  ? 'Certificate ID: $_savedCertId'
                                  : _isSaving
                                      ? 'Generating Certificate ID…'
                                      : 'Certificate ID: (save failed)',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFFAAAAAA)),
                            ),
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
                                    height: 20, width: 20,
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF11BD51), strokeWidth: 2),
                                  )
                                : Column(
                                    children: [
                                      _buildInfoRow('Quality Grader', _graderName),
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
                            children: [
                              const Icon(Icons.workspace_premium,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              ),
                              GestureDetector(
                                onTap: _showClassificationsSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                      Icons.remove_red_eye_outlined,
                                      color: Colors.white, size: 20),
                                ),
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              child: Text(advisory,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF555555),
                                      height: 1.6)),
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
                                  .showSnackBar(
                                      _snackBar('Download feature coming soon!')),
                            ),
                            const SizedBox(height: 10),
                            _buildActionButton(
                              icon: Icons.send_outlined,
                              label: 'Send to Farmer',
                              onTap: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                      _snackBar('Send feature coming soon!')),
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

  // ── Save Status Banner ─────────────────────────────────────────
  Widget _buildSaveBanner() {
    if (_isSaving) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFFF39C12).withOpacity(0.4), width: 1),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  color: Color(0xFFF39C12), strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Saving grade record to database…',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A6914))),
          ],
        ),
      );
    }
    if (_saveSuccess) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8EF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: const Color(0xFF11BD51).withOpacity(0.4), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                size: 16, color: Color(0xFF11BD51)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _uploadedPhotoUrl.isNotEmpty
                    ? 'Grade record & photo saved — visible in Admin Dashboard.'
                    : 'Grade record saved — visible in Admin Dashboard.',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF1A6B3C)),
              ),
            ),
          ],
        ),
      );
    }
    // Error state
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEEEE),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.redAccent.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: Colors.redAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Could not save: $_saveError',
                style:
                    const TextStyle(fontSize: 11, color: Colors.redAccent)),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSaving = true;
                _saveError = '';
              });
              _saveGradeRecord();
            },
            child: const Text('Retry',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  // ── Scanned Photo Preview ──────────────────────────────────────
  Widget _buildScannedPhoto() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          Image.file(
            File(widget.imagePath!),
            width: double.infinity,
            height: 200,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 120,
              color: const Color(0xFFF0FBF5),
              child: const Center(
                child: Icon(Icons.broken_image_outlined,
                    size: 40, color: Color(0xFF11BD51)),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.grass, size: 12, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Scanned Sugarcane',
                      style: TextStyle(fontSize: 11, color: Colors.white)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      );

  // ── Grade Classifications Sheet ───────────────────────────────
  static const List<Map<String, dynamic>> _classifications = [
    {
      'grade': 'FA',
      'trashDiscount': '0%',
      'remarkCode': 'Cc',
      'remarkFull': 'Clean Canes',
      'color': 0xFF27AE60,
    },
    {
      'grade': 'FB',
      'trashDiscount': '1%',
      'remarkCode': 'SI',
      'remarkFull': 'Slight Leaves',
      'color': 0xFF2ECC71,
    },
    {
      'grade': 'FC',
      'trashDiscount': '2%',
      'remarkCode': 'MI',
      'remarkFull': 'Moderate Leaves',
      'color': 0xFFF39C12,
    },
    {
      'grade': 'FD',
      'trashDiscount': '3%',
      'remarkCode': 'PI',
      'remarkFull': 'Plenty of Leaves',
      'color': 0xFFE67E22,
    },
    {
      'grade': 'FE',
      'trashDiscount': '4%',
      'remarkCode': 'Mlpct',
      'remarkFull': 'Moderate Leaves and Plenty of Cane Tops',
      'color': 0xFFE74C3C,
    },
    {
      'grade': 'FF',
      'trashDiscount': '5%',
      'remarkCode': 'DD',
      'remarkFull': 'Dirty Canes',
      'color': 0xFF922B21,
    },
  ];

  void _showClassificationsSheet() {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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

            // Title
            Row(
              children: const [
                Icon(Icons.workspace_premium,
                    size: 18, color: Color(0xFF11BD51)),
                SizedBox(width: 8),
                Text('Grade Classifications',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Trash discount and remarks per grade',
                  style: TextStyle(fontSize: 12, color: Color(0xFF888888))),
            ),
            const SizedBox(height: 16),

            // Header row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('Grade',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF888888))),
                  ),
                  SizedBox(width: 10),
                  SizedBox(
                    width: 60,
                    child: Text('Discount',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF888888))),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Remarks',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF888888))),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Classification rows
            ..._classifications.map((c) {
              final isCurrentGrade =
                  widget.grade.toUpperCase() == c['grade'];
              final color = Color(c['color'] as int);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isCurrentGrade
                      ? color.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrentGrade
                      ? Border.all(color: color.withOpacity(0.4), width: 1.5)
                      : Border.all(color: Colors.transparent),
                ),
                child: Row(
                  children: [
                    // Grade badge
                    Container(
                      width: 36,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(c['grade'] as String,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                    ),
                    const SizedBox(width: 10),
                    // Trash discount
                    SizedBox(
                      width: 60,
                      child: Text(c['trashDiscount'] as String,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color)),
                    ),
                    const SizedBox(width: 10),
                    // Remark
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c['remarkCode'] as String,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A))),
                          Text(c['remarkFull'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF888888),
                                  height: 1.3)),
                        ],
                      ),
                    ),
                    // "Current" tag
                    if (isCurrentGrade)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Current',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

}