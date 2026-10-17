import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class GradeResult {
  final String label;       // "FC", "FC/FD" or "Not sugarcane"
  final double confidence;  // calibrated probability of the shown group
  final Map<String, double> probabilities; // per class, calibrated

  GradeResult(this.label, this.confidence, this.probabilities);
}

class ModelService {
  static final ModelService _instance = ModelService._internal();
  factory ModelService() => _instance;
  ModelService._internal();

  static const int inputSize = 320;
  static const double temperature = 0.5;
  static const double singleGradeIfShareAtLeast = 0.5;

  static const List<List<String>> groups = [
    ['FA', 'FB'],
    ['FC', 'FD'],
    ['FE', 'FF'],
    ['non canes'],
  ];

  Interpreter? _interpreter;
  List<String> _labels = [];

  bool get isLoaded => _interpreter != null;

  Interpreter get interpreter {
    if (_interpreter == null) throw Exception("Model not loaded");
    return _interpreter!;
  }

  Future<void> loadModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/sugarcane_grader.tflite',
      );
      final raw = await rootBundle.loadString('assets/models/labels.txt');
      _labels = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      debugPrint("Input shape: ${_interpreter!.getInputTensor(0).shape}");
      debugPrint("Output shape: ${_interpreter!.getOutputTensor(0).shape}");
      debugPrint("Labels: $_labels");
    } catch (e) {
      debugPrint("Failed to load model: $e");
    }
  }

  GradeResult classify(img.Image image) {
    // Plain resize to 320x320, RGB, float32, raw 0-255 (NO /255 division)
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_labels.length, 0.0));
    interpreter.run(input, output);

    // Temperature calibration: p_cal = softmax(log(p) / T)
    final raw = output[0];
    final logits =
        raw.map((p) => log(max(p, 1e-8)) / temperature).toList();
    final maxLogit = logits.reduce(max);
    final exps = logits.map((l) => exp(l - maxLogit)).toList();
    final sum = exps.reduce((a, b) => a + b);
    final probs = exps.map((e) => e / sum).toList();

    final byClass = {
      for (var i = 0; i < _labels.length; i++) _labels[i]: probs[i],
    };

    // Pick the group with the highest total probability
    List<String> bestGroup = groups.first;
    double bestP = -1;
    for (final g in groups) {
      final pg = g.fold<double>(0, (s, c) => s + (byClass[c] ?? 0));
      if (pg > bestP) {
        bestP = pg;
        bestGroup = g;
      }
    }

    if (bestGroup.length == 1 && bestGroup.first == 'non canes') {
      return GradeResult('Not sugarcane', bestP, byClass);
    }

    // Inside the group: single grade if its share >= 0.5, else show the group
    final pick = bestGroup.reduce(
        (a, b) => (byClass[a] ?? 0) >= (byClass[b] ?? 0) ? a : b);
    final share = (byClass[pick] ?? 0) / bestP;
    final label = share >= singleGradeIfShareAtLeast
        ? pick
        : bestGroup.join('/');

    return GradeResult(label, bestP, byClass);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}