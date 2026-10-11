import 'package:flutter/material.dart';
import 'certificate_page.dart';

// ── Fixed grade lookup table ──────────────────────────────────────
// Grade → { trashDiscount, remarkCode, remarkFull }
const Map<String, Map<String, dynamic>> kGradeLookup = {
  'FA': {'trash': 0,  'code': 'Cc',    'remark': 'Clean canes',                                  'advisory': 'Maintain current harvesting practices and prioritize immediate delivery to preserve sugar content.'},
  'FB': {'trash': 1,  'code': 'Sl',    'remark': 'Slight leaves',                                'advisory': 'Implement light cleaning before transport and encourage harvesters to remove loose leaves during bundling.'},
  'FC': {'trash': 2,  'code': 'Ml',    'remark': 'Moderate leaves',                              'advisory': 'Apply additional manual cleaning before loading and train harvesters to strip leaves more thoroughly during cutting.'},
  'FD': {'trash': 3,  'code': 'Pl',    'remark': 'Plenty of leaves',                             'advisory': 'Conduct pre-delivery leaf stripping operations and have supervisors inspect harvesting teams to ensure proper cane preparation.'},
  'FE': {'trash': 4,  'code': 'Mlpct', 'remark': 'Moderate leaves and plenty of cane tops',     'advisory': 'Require trimming of cane tops and removal of excess leaves, and implement stricter grading checks at the collection point.'},
  'FF': {'trash': 5,  'code': 'Dc',    'remark': 'Dirty canes',                                  'advisory': 'Investigate harvesting conditions and introduce corrective actions like cleaning stations and stricter field supervision.'},
};

// Returns quality label per grade
String gradeQuality(String grade) {
  switch (grade) {
    case 'FA': return 'Excellent';
    case 'FB': return 'Very Good';
    case 'FC': return 'Good';
    case 'FD': return 'Fair';
    case 'FE': return 'Below Average';
    case 'FF': return 'Poor';
    default:   return 'Unknown';
  }
}

class AnalysisPage extends StatelessWidget {
  final String farmerName;
  final String farmId;
  final String farmerDocId;
  final String grade;

  /// Local file path of the scanned sugarcane photo.
  /// Passed on to CertificatePage so the photo appears on the
  /// certificate, in the PDF, and in the admin dashboard.
  final String? imagePath;

  const AnalysisPage({
    super.key,
    required this.farmerName,
    required this.farmId,
    required this.farmerDocId,
    required this.grade,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve values from lookup — default to FF if grade not found
    final gradeKey = grade.toUpperCase();
    final info = kGradeLookup[gradeKey] ?? kGradeLookup['FF']!;
    final int trashDiscount = info['trash'] as int;
    final String remarkCode  = info['code'] as String;
    final String remarkFull  = info['remark'] as String;
    final String advisory    = info['advisory'] as String;
    final String quality     = gradeQuality(gradeKey);

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

            // ── Assessment For Card ───────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF11BD51).withOpacity(0.3), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assessment for:',
                        style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
                    const SizedBox(height: 4),
                    Text(farmerName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text('Farm ID: $farmId',
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF888888))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── White Result Card ─────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Analysis Complete Header ───────────────
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFF11BD51),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 10),
                          const Text('Analysis Complete',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Grade Badge Row ───────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF11BD51).withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF11BD51), width: 2),
                            ),
                            child: const Icon(Icons.workspace_premium,
                                color: Color(0xFF11BD51), size: 26),
                          ),
                          const SizedBox(width: 14),
                          Text(gradeKey,
                              style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Text('Quality:  ',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF555555))),
                          Text(quality,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF11BD51))),
                        ],
                      ),

                      const SizedBox(height: 24),
                      const Divider(color: Color(0xFFF0F0F0)),
                      const SizedBox(height: 20),

                      // ── Trash Discount + Remarks (side by side) ─
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Trash Discount
                          Expanded(
                            child: _buildParamCard(
                              icon: Icons.delete_outline,
                              label: 'Trash Discount',
                              value: '$trashDiscount%',
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Remarks
                          Expanded(
                            child: _buildRemarkCard(
                              code: remarkCode,
                              remark: remarkFull,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Operational Advisory Card ─────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBF0),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFF39C12).withOpacity(0.4)),
                        ),
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
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFF39C12))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(advisory,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF555555),
                                    height: 1.5)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Generate Certificate Button ────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, animation, __) =>
                                    CertificatePage(
                                  farmerName: farmerName,
                                  farmId: farmId,
                                  farmerDocId: farmerDocId,
                                  grade: gradeKey,
                                  quality: quality,
                                  trashDiscount: trashDiscount,
                                  remarkCode: remarkCode,
                                  remarkFull: remarkFull,
                                  imagePath: imagePath, // ← scanned photo
                                ),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(opacity: animation, child: child),
                                transitionDuration:
                                    const Duration(milliseconds: 250),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF11BD51),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Generate Certificate',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Scan Another Button ────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF11BD51),
                            side: const BorderSide(
                                color: Color(0xFF11BD51), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Scan Another',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Trash Discount Card ───────────────────────────────────────
  Widget _buildParamCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: const Color(0xFF888888)),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  // ── Remarks Card ──────────────────────────────────────────────
  Widget _buildRemarkCard({
    required String code,
    required String remark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: Color(0xFF11BD51)),
              const SizedBox(width: 5),
              const Text('Remarks',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888888))),
            ],
          ),
          const SizedBox(height: 10),
          Text(code,
              style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text(remark,
              style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF888888),
                  height: 1.4)),
        ],
      ),
    );
  }
}