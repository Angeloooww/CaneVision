import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
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

  // ── TFLite config ─────────────────────────────────────────────
  // Model is a ResNet50-based classifier with 6 output classes.
  // Input:  [1, 224, 224, 3]  float32  (ResNet50 preprocessing)
  // Output: [1, 6]            float32  (softmax probabilities)
  static const String _modelPath =
      'assets/models/canevision_v1_surgical_resnet.tflite';
  static const int _inputSize = 224;

  // Class labels — must match your training label order
  static const List<String> _classLabels = [
    'FA',   // index 0
    'FB',  // index 1
    'FC',   // index 2
    'FD',  // index 3
    'FE',   // index 4
    'FF',   // index 5
  ];

  Interpreter? _interpreter;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }

  // ── Load TFLite model from assets ────────────────────────────
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
    }
  }

  // ── Pre-process image → [1, 224, 224, 3] float32 tensor ──────
  // Uses ResNet50 Keras preprocess_input: subtract ImageNet channel means.
  // Compatible with image package v4.x (pixel accessors via .r .g .b).
  Float32List _preprocessImage(File imageFile) {
    final rawBytes = imageFile.readAsBytesSync();
    final img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Could not decode image');

    // Resize to 224×224
    final image = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    // Fill [1, 224, 224, 3] float32 buffer
    final input = Float32List(_inputSize * _inputSize * 3);
    int idx = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = image.getPixel(x, y);
        // image v4.x: use .r .g .b (num) instead of deprecated getRed/getGreen/getBlue
        input[idx++] = pixel.r.toDouble() - 123.68;
        input[idx++] = pixel.g.toDouble() - 116.779;
        input[idx++] = pixel.b.toDouble() - 103.939;
      }
    }
    return input;
  }

  // ── Build nested List for tflite_flutter input ────────────────
  // tflite_flutter expects List<List<List<List<double>>>> shaped [1,H,W,3].
  // We avoid the .reshape() extension (requires tflite_flutter import context)
  // and build the structure manually from the flat Float32List.
  List<List<List<List<double>>>> _buildInputTensor(Float32List flat) {
    return List.generate(1, (_) =>
      List.generate(_inputSize, (y) =>
        List.generate(_inputSize, (x) {
          final base = (y * _inputSize + x) * 3;
          return [flat[base], flat[base + 1], flat[base + 2]];
        })
      )
    );
  }

  // ── Run on-device TFLite inference ───────────────────────────
  Future<Map<String, dynamic>?> _runInference(File imageFile) async {
    if (_interpreter == null) {
      await _loadModel();
      if (_interpreter == null) {
        _showError('Model not loaded. Please restart the app.');
        return null;
      }
    }

    try {
      final flat = _preprocessImage(imageFile);
      final inputTensor = _buildInputTensor(flat);

      // Output: [1, numClasses] — plain nested list
      final outputTensor = List.generate(
        1,
        (_) => List.filled(_classLabels.length, 0.0),
      );

      _interpreter!.run(inputTensor, outputTensor);

      final probabilities = outputTensor[0]; // List<double> length 6

      // Find top prediction
      int topIndex = 0;
      double topProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > topProb) {
          topProb = probabilities[i];
          topIndex = i;
        }
      }

      final predictions = List.generate(
        _classLabels.length,
        (i) => {'class': _classLabels[i], 'confidence': probabilities[i]},
      )..sort(
          (a, b) => (b['confidence'] as double)
              .compareTo(a['confidence'] as double),
        );

      return {
        'predictions': predictions,
        'topClass': _classLabels[topIndex],
        'topConfidence': topProb,
      };
    } catch (e) {
      _showError('Inference error: $e');
      return null;
    }
  }

  // ── Parse grade from inference result ────────────────────────
  String _parseGrade(Map<String, dynamic> result) {
    try {
      return (result['topClass'] as String? ?? 'N/A').toUpperCase();
    } catch (_) {
      return 'N/A';
    }
  }

  // ── Parse confidence from inference result ────────────────────
  double _parseConfidence(Map<String, dynamic> result) {
    try {
      return (result['topConfidence'] as double? ?? 0.0) * 100;
    } catch (_) {
      return 0.0;
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

  // ── Analyze image via on-device TFLite then navigate ─────────
  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    final result = await _runInference(_selectedImage!);

    if (result != null && mounted) {
      final grade = _parseGrade(result);

      // Derive quality label from grade
      String quality;
      if (grade == 'FA') {
        quality = 'Excellent';
      } else if (grade == 'FB') {
        quality = 'Very Good';
      } else if (grade == 'FC') {
        quality = 'Good';
      } else if (grade == 'FD') {
        quality = 'Fair';
      } else if (grade == 'FE') {
        quality = 'Below Average';
      } else {
        quality = 'Poor';
      }

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
    Color gradeColor;
    if (grade == 'FA' || grade == 'FB') {
      gradeColor = const Color(0xFF11BD51); // Green
    } else if (grade == 'FC' || grade == 'FD') {
      gradeColor = const Color(0xFFF39C12); // Orange
    } else {
      gradeColor = const Color(0xFFE74C3C); // Red
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
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
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
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF888888))),
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
                  Icon(Icons.check_circle_outline, color: gradeColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Grade saved to ${widget.farmerName}'s profile.",
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
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF888888))),
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required bool showArrow,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                style:
                    const TextStyle(fontSize: 9, color: Color(0xFF888888))),
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