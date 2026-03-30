import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Detection {
  final int classIndex;
  final String className;
  final double confidence;
  // Bounding box normalizada [0,1] relativa ao frame
  final double x1, y1, x2, y2;

  const Detection({
    required this.classIndex,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
}

class ObjectDetector {
  static const int inputSize = 640;
  static const double confThreshold = 0.6;
  static const double iouThreshold = 0.45;

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/labels.txt');
    _labels = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();

    _interpreter = await Interpreter.fromAsset(
      'assets/model/best_float32.tflite',
      options: InterpreterOptions()..threads = 4,
    );
    _isLoaded = true;
  }

  /// Processa um frame da câmera e retorna as detecções.
  List<Detection> detect(CameraImage image) {
    if (!_isLoaded || _interpreter == null) return [];

    // Converte YUV420 → RGB → resize 640x640 → normaliza [0,1]
    final input = _buildInputTensor(image);

    // Output shape: [1, 21, 8400]
    final outShape = _interpreter!.getOutputTensor(0).shape;
    final numFeatures = outShape[1]; // 21
    final numAnchors = outShape[2];  // 8400

    final output = [
      List.generate(numFeatures, (_) => List<double>.filled(numAnchors, 0.0))
    ];

    _interpreter!.run(input, output);

    return _parseAndNms(output[0], numFeatures - 4, numAnchors);
  }

  // ---------------------------------------------------------------------------
  // Pré-processamento
  // ---------------------------------------------------------------------------

  List<List<List<List<double>>>> _buildInputTensor(CameraImage image) {
    final rgb = _yuv420ToRgb(image);
    final resized = _resizeNearestNeighbor(
        rgb, image.width, image.height, inputSize, inputSize);
    return [resized]; // shape [1, 640, 640, 3]
  }

  /// Converte CameraImage YUV420 (formato padrão do Android) para lista RGB.
  List<int> _yuv420ToRgb(CameraImage image) {
    final w = image.width;
    final h = image.height;
    final rgb = List<int>.filled(w * h * 3, 0);

    final yBytes = image.planes[0].bytes;
    final uBytes = image.planes[1].bytes;
    final vBytes = image.planes[2].bytes;

    final yRowStride = image.planes[0].bytesPerRow;
    final uvRowStride = image.planes[1].bytesPerRow;
    final uvPixelStride = image.planes[1].bytesPerPixel ?? 2;

    for (int row = 0; row < h; row++) {
      for (int col = 0; col < w; col++) {
        final yIdx = row * yRowStride + col;
        final uvIdx = (row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride;

        final yVal = yBytes[yIdx] & 0xFF;
        final uVal = (uBytes[uvIdx] & 0xFF) - 128;
        final vVal = (vBytes[uvIdx] & 0xFF) - 128;

        final r = (yVal + 1.402 * vVal).clamp(0, 255).toInt();
        final g = (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0, 255).toInt();
        final b = (yVal + 1.772 * uVal).clamp(0, 255).toInt();

        final i = (row * w + col) * 3;
        rgb[i] = r;
        rgb[i + 1] = g;
        rgb[i + 2] = b;
      }
    }
    return rgb;
  }

  /// Resize por nearest-neighbor e normaliza para [0,1].
  List<List<List<double>>> _resizeNearestNeighbor(
      List<int> rgb, int srcW, int srcH, int dstW, int dstH) {
    final xScale = srcW / dstW;
    final yScale = srcH / dstH;

    return List.generate(dstH, (y) {
      final srcY = (y * yScale).toInt().clamp(0, srcH - 1);
      return List.generate(dstW, (x) {
        final srcX = (x * xScale).toInt().clamp(0, srcW - 1);
        final i = (srcY * srcW + srcX) * 3;
        return [rgb[i] / 255.0, rgb[i + 1] / 255.0, rgb[i + 2] / 255.0];
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Parsing + NMS
  // ---------------------------------------------------------------------------

  List<Detection> _parseAndNms(
      List<List<double>> output, int numClasses, int numAnchors) {
    final candidates = <Detection>[];

    for (int i = 0; i < numAnchors; i++) {
      double maxScore = 0;
      int maxClass = 0;

      for (int c = 0; c < numClasses; c++) {
        final score = output[4 + c][i];
        if (score > maxScore) {
          maxScore = score;
          maxClass = c;
        }
      }

      if (maxScore < confThreshold) continue;

      // YOLOv8 output: cx, cy, w, h em pixels relativos ao inputSize (640)
      final cx = output[0][i] / inputSize;
      final cy = output[1][i] / inputSize;
      final w  = output[2][i] / inputSize;
      final h  = output[3][i] / inputSize;

      final x1 = (cx - w / 2).clamp(0.0, 1.0);
      final y1 = (cy - h / 2).clamp(0.0, 1.0);
      final x2 = (cx + w / 2).clamp(0.0, 1.0);
      final y2 = (cy + h / 2).clamp(0.0, 1.0);

      final name = maxClass < _labels.length
          ? _labels[maxClass]
          : 'Objeto $maxClass';

      candidates.add(Detection(
        classIndex: maxClass,
        className: name,
        confidence: maxScore,
        x1: x1, y1: y1, x2: x2, y2: y2,
      ));
    }

    return _nms(candidates);
  }

  List<Detection> _nms(List<Detection> dets) {
    if (dets.isEmpty) return [];
    dets.sort((a, b) => b.confidence.compareTo(a.confidence));

    final kept = <Detection>[];
    final suppressed = List<bool>.filled(dets.length, false);

    for (int i = 0; i < dets.length; i++) {
      if (suppressed[i]) continue;
      kept.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (!suppressed[j] && _iou(dets[i], dets[j]) > iouThreshold) {
          suppressed[j] = true;
        }
      }
    }
    return kept;
  }

  double _iou(Detection a, Detection b) {
    final ix1 = math.max(a.x1, b.x1);
    final iy1 = math.max(a.y1, b.y1);
    final ix2 = math.min(a.x2, b.x2);
    final iy2 = math.min(a.y2, b.y2);
    if (ix2 <= ix1 || iy2 <= iy1) return 0.0;
    final inter = (ix2 - ix1) * (iy2 - iy1);
    final aArea = (a.x2 - a.x1) * (a.y2 - a.y1);
    final bArea = (b.x2 - b.x1) * (b.y2 - b.y1);
    return inter / (aArea + bArea - inter);
  }

  void dispose() => _interpreter?.close();
}
