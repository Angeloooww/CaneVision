import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  static final ModelService _instance = ModelService._internal();

  factory ModelService() {
    return _instance;
  }

  ModelService._internal();

  Interpreter? _interpreter;

  bool get isLoaded => _interpreter != null;

  Interpreter get interpreter {
    if (_interpreter == null) {
      throw Exception("Model not loaded");
    }
    return _interpreter!;
  }

  Future<void> loadModel() async {
    if (_interpreter != null) {
      debugPrint("Model already loaded");
      return;
    }

    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/canevision_v1_surgical_resnet.tflite',
      );

      debugPrint("TFLite model loaded successfully");

      debugPrint(
        "Input shape: ${_interpreter!.getInputTensor(0).shape}",
      );

      debugPrint(
        "Output shape: ${_interpreter!.getOutputTensor(0).shape}",
      );
    } catch (e) {
      debugPrint("Failed to load model: $e");
    }
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}