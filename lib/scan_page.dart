import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'analysis_page.dart';

class ScanPage extends StatefulWidget {
  final String farmerName;
  final String farmId;
  final String farmerDocId;

  const ScanPage({
    super.key,
    required this.farmerName,
    required this.farmId,
    required this.farmerDocId,
  });

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;

  // Roboflow API config
  static const String _apiUrl =
      'https://serverless.roboflow.com/canevision-5nrlh/1';
  static const String _apiKey = 'gTM1eaFDdxuiC0P4h4J6';

  // ── Take Photo using Camera ───────────────────────────────────
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        setState(() => _selectedImage = File(photo.path));
        _showImagePreview();
      }
    } catch (e) {
      _showError('Could not access camera. Please check permissions.');
    }
  }

  // ── Pick Photo from Gallery ───────────────────────────────────
  Future<void> _uploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() => _selectedImage = File(image.path));
        _showImagePreview();
      }
    } catch (e) {
      _showError('Could not access photo library. Please check permissions.');
    }
  }

  // ── Send image to Roboflow API ────────────────────────────────
  Future<Map<String, dynamic>?> _callRoboflowAPI(File imageFile) async {
    try {
      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // POST base64 image to Roboflow
      final response = await http.post(
        Uri.parse('$_apiUrl?api_key=$_apiKey'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: base64Image,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        _showError('API error: ${response.statusCode}. Please try again.');
        return null;
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
      return null;
    }
  }

  // ── Parse grade from Roboflow response ───────────────────────
  String _parseGrade(Map<String, dynamic> result) {
    try {
      // Roboflow returns predictions array — get top prediction class
      final predictions = result['predictions'] as List<dynamic>?;
      if (predictions != null && predictions.isNotEmpty) {
        // Sort by confidence descending and take the top result
        predictions.sort((a, b) =>
            (b['confidence'] as double).compareTo(a['confidence'] as double));
        return predictions[0]['class'].toString().toUpperCase();
      }
      // Fallback: check top-level class field
      if (result.containsKey('class')) {
        return result['class'].toString().toUpperCase();
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  // ── Parse confidence from Roboflow response ───────────────────
  double _parseConfidence(Map<String, dynamic> result) {
    try {
      final predictions = result['predictions'] as List<dynamic>?;
      if (predictions != null && predictions.isNotEmpty) {
        predictions.sort((a, b) =>
            (b['confidence'] as double).compareTo(a['confidence'] as double));
        return ((predictions[0]['confidence'] as double) * 100);
      }
      if (result.containsKey('confidence')) {
        return ((result['confidence'] as double) * 100);
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  // ── Analyze image via Roboflow then navigate to AnalysisPage ───
  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    final result = await _callRoboflowAPI(_selectedImage!);

    if (result != null && mounted) {
      final grade = _parseGrade(result);

      // Derive quality label from grade
      String quality;
      if (grade.contains('A')) {
        quality = 'Very Good';
      } else if (grade.contains('B')) {
        quality = 'Good';
      } else if (grade.contains('C')) {
        quality = 'Fair';
      } else {
        quality = 'Poor';
      }

      // Parse trash/mud from predictions if available, else default to 0
      double trashDiscount = 0;
      double mud = 0;
      String cleanCanes = 'Clean Canes';
      String remarks = 'No Mud';

      try {
        final predictions = result['predictions'] as List<dynamic>?;
        if (predictions != null && predictions.isNotEmpty) {
          predictions.sort((a, b) =>
              (b['confidence'] as double).compareTo(a['confidence'] as double));
          final top = predictions[0];
          // If your model returns trash/mud values in the prediction object
          trashDiscount = (top['trash_discount'] as num?)?.toDouble() ?? 0;
          mud = (top['mud'] as num?)?.toDouble() ?? 0;
          cleanCanes = trashDiscount == 0 ? 'Clean Canes' : 'Slight Trash';
          remarks = mud == 0 ? 'No Mud' : mud <= 5 ? 'Slight Mud' : 'Heavy Mud';
        }
      } catch (_) {}

      // Save grade back to Firestore farmer document
      await FirebaseFirestore.instance
          .collection('farmers')
          .doc(widget.farmerDocId)
          .update({
        'grade': grade,
        'lastScannedAt': FieldValue.serverTimestamp(),
        'lastScannedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });

      setState(() => _isProcessing = false);

      if (mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => AnalysisPage(
              farmerName: widget.farmerName,
              farmId: widget.farmId,
              farmerDocId: widget.farmerDocId,
              grade: grade,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      }
    } else {
      setState(() => _isProcessing = false);
    }
  }

  // ── Result Dialog ─────────────────────────────────────────────
  void _showResultDialog(
      String grade, double confidence, Map<String, dynamic> rawResult) {
    // Pick badge color based on grade
    Color gradeColor;
    if (['A', 'A+', 'GRADE A'].contains(grade)) {
      gradeColor = const Color(0xFF11BD51);
    } else if (['B', 'B+', 'GRADE B'].contains(grade)) {
      gradeColor = const Color(0xFFF39C12);
    } else {
      gradeColor = const Color(0xFFE74C3C);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // Grade circle
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: gradeColor, width: 3),
              ),
              alignment: Alignment.center,
              child: Text(
                grade,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: gradeColor),
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Scan Complete!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),

            const SizedBox(height: 6),

            Text(
              widget.farmerName,
              style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  fontWeight: FontWeight.w500),
            ),
            Text(
              'Farm ID: ${widget.farmId}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF888888)),
            ),

            const SizedBox(height: 20),

            // Confidence bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Confidence',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF888888))),
                      Text('${confidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: gradeColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: confidence / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Info note
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: gradeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: gradeColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline,
                      color: gradeColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Grade saved to ${widget.farmerName}\'s profile.',
                      style: TextStyle(
                          fontSize: 12,
                          color: gradeColor,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF11BD51),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ── Image Preview Bottom Sheet ────────────────────────────────
  void _showImagePreview() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 16),

              const Text('Preview',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A))),

              const SizedBox(height: 4),

              Text('Scanning for: ${widget.farmerName}',
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF888888))),

              const SizedBox(height: 16),

              // Image
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _selectedImage != null
                        ? Image.file(_selectedImage!,
                            fit: BoxFit.cover, width: double.infinity)
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Icon(Icons.image_outlined,
                                size: 60, color: Color(0xFFCCCCCC)),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Retake
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _selectedImage = null);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retake',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF11BD51),
                          side: const BorderSide(
                              color: Color(0xFF11BD51), width: 1.5),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Analyze
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () {
                                Navigator.pop(context);
                                _analyzeImage();
                              },
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.analytics_outlined,
                                size: 18),
                        label: Text(
                            _isProcessing ? 'Analyzing...' : 'Analyze',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF11BD51),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Grader';

    return Scaffold(
      backgroundColor: const Color(0xFFE8F8EF),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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

            // ── Welcome Text ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Welcome, $displayName!',
                style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF444444),
                    fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 14),

            // ── Scan / Farmers Tab Buttons ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF11BD51), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.home_outlined,
                              size: 18, color: Color(0xFF11BD51)),
                          SizedBox(width: 6),
                          Text('Scan',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.transparent),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 18, color: Color(0xFF888888)),
                            SizedBox(width: 6),
                            Text('Farmers',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF888888))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Stats Row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildStatCard(
                      label: "Today's Score",
                      value: '--',
                      showArrow: false),
                  const SizedBox(width: 10),
                  _buildStatCard(
                      label: 'Avg Grade', value: '--', showArrow: true),
                  const SizedBox(width: 10),
                  _buildStatCard(
                      label: 'Farmers', value: '--', showArrow: false),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Scanning For Card ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF11BD51).withOpacity(0.4),
                      width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Scanning for:',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF888888))),
                          const SizedBox(height: 3),
                          Text(widget.farmerName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 2),
                          Text('Farm ID: ${widget.farmId}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF888888))),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Change Farmer',
                          style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF11BD51),
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── White Bottom Card ─────────────────────────────────
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
                child: _isProcessing
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFF11BD51), strokeWidth: 3),
                          SizedBox(height: 20),
                          Text('Analyzing sugarcane...',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A))),
                          SizedBox(height: 6),
                          Text('Please wait',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF888888))),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFF11BD51),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined,
                                color: Colors.white, size: 36),
                          ),
                          const SizedBox(height: 20),
                          const Text('Scan Sugarcane',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A))),
                          const SizedBox(height: 10),
                          const Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              'Take a photo or upload an image of the sugarcane to analyze its grade',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF888888),
                                  height: 1.5),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Take Photo
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 20),
                                label: const Text('Take Photo',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF11BD51),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Upload Photo
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 30),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: _uploadPhoto,
                                icon: const Icon(
                                    Icons.photo_library_outlined,
                                    size: 20),
                                label: const Text('Upload Photo',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      const Color(0xFF11BD51),
                                  side: const BorderSide(
                                      color: Color(0xFF11BD51),
                                      width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required bool showArrow,
  }) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 9, color: Color(0xFF888888))),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A))),
                if (showArrow) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_outward,
                      size: 13, color: Color(0xFF11BD51)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}