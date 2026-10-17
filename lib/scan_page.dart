import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'analysis_page.dart';
import 'model_service.dart';

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
  ImageSource? _lastSource; // remembers camera/gallery for "Scan Again"

  @override
  void initState() {
    super.initState();
    // Ensure model is loaded when the page opens
    _ensureModelLoaded();
  }

  Future<void> _ensureModelLoaded() async {
    if (!ModelService().isLoaded) {
      await ModelService().loadModel();
    }
  }

  // ── Run on-device TFLite inference via ModelService ──────────
  // Preprocessing (320x320, RGB, raw 0-255), temperature calibration
  // and grouping all happen inside ModelService.classify().
  Future<GradeResult?> _runInference(File imageFile) async {
    if (!ModelService().isLoaded) {
      await ModelService().loadModel();
      if (!ModelService().isLoaded) {
        _showError('Model not loaded. Please restart the app.');
        return null;
      }
    }

    try {
      final decoded = img.decodeImage(imageFile.readAsBytesSync());
      if (decoded == null) throw Exception('Could not decode image');

      // Fixes rotated phone photos (EXIF orientation)
      final oriented = img.bakeOrientation(decoded);

      return ModelService().classify(oriented);
    } catch (e) {
      _showError('Inference error: $e');
      return null;
    }
  }

  // ── Take Photo using Camera ───────────────────────────────────
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo != null) {
        _lastSource = ImageSource.camera;
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
        _lastSource = ImageSource.gallery;
        setState(() => _selectedImage = File(image.path));
        _showImagePreview();
      }
    } catch (e) {
      _showError('Could not access photo library. Please check permissions.');
    }
  }

  // ── Analyze image via on-device TFLite then navigate ─────────
  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    // Keep the photo path so it can be passed on to the certificate
    final String photoPath = _selectedImage!.path;

    setState(() => _isProcessing = true);

    final result = await _runInference(_selectedImage!);

    if (result != null && mounted) {
      // Top class is "non canes": don't save a grade or make a certificate
      if (result.label == 'Not sugarcane') {
        setState(() => _isProcessing = false);
        await _showNotSugarcaneDialog();
        return;
      }

      final grade = result.label; // "FA".."FF" or a group like "FC/FD"

      // Save grade to Firestore
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
              imagePath: photoPath, // ← scanned photo
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

  // ── "Not sugarcane" pop-up with Scan Again button ────────────
  Future<void> _showNotSugarcaneDialog() async {
    if (!mounted) return;

    final bool? scanAgain = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 34),
            ),
            const SizedBox(height: 16),
            const Text(
              'Not Sugarcane',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            const Text(
              'This photo is not a sugarcane. Please scan again using a clear photo of the sugarcane bundle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: Color(0xFF666666), height: 1.5),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF888888),
                    side: const BorderSide(color: Color(0xFFDDDDDD)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Scan Again',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF11BD51),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!mounted) return;

    // Clear the rejected photo either way
    setState(() => _selectedImage = null);

    // Scan Again → reopen the same source (camera or gallery)
    if (scanAgain == true) {
      if (_lastSource == ImageSource.gallery) {
        await _uploadPhoto();
      } else {
        await _takePhoto();
      }
    }
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
              const Text(
                'Preview',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A)),
              ),
              const SizedBox(height: 4),
              Text(
                'Scanning for: ${widget.farmerName}',
                style:
                    const TextStyle(fontSize: 12, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 16),
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
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _selectedImage = null);
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retake',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF11BD51),
                          side: const BorderSide(
                              color: Color(0xFF11BD51), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                            : const Icon(Icons.analytics_outlined, size: 18),
                        label: Text(
                            _isProcessing ? 'Analyzing...' : 'Analyze',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF11BD51),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
    if (!mounted) return;
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

            // ── Scanning For Card ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                  fontSize: 12, color: Color(0xFF888888))),
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
                                  fontSize: 13, color: Color(0xFF888888))),
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
                            padding: EdgeInsets.symmetric(horizontal: 40),
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
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 30),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _takePhoto,
                                icon: const Icon(Icons.camera_alt_outlined,
                                    size: 20),
                                label: const Text('Take Photo',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF11BD51),
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
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 30),
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
                                  foregroundColor: const Color(0xFF11BD51),
                                  side: const BorderSide(
                                      color: Color(0xFF11BD51), width: 1.5),
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
}