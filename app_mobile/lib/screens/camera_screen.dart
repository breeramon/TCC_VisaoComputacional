import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../detector/object_detector.dart';
import '../tts/tts_service.dart';

// Cores por prioridade (espelha a lógica do script Python)
const _corAlta  = Color(0xFFFF3B30); // vermelho — Pessoa
const _corMedia = Color(0xFFFF9500); // laranja  — Portas, Elevadores, Placas
const _corBaixa = Color(0xFF34C759); // verde    — Referências

const _classesAlta  = {'person'};
const _classesMedia = {
  'door', 'elevator', 'elevator sign', 'stair sign',
  'exit sign', 'fire alarm',
};

Color _corParaClasse(String className) {
  if (_classesAlta.contains(className)) return _corAlta;
  if (_classesMedia.contains(className)) return _corMedia;
  return _corBaixa;
}

const _useGpu = true;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final TtsService _tts = TtsService();

  List<YOLOResult> _results = [];
  int _fps = 0;
  int _frameCount = 0;
  DateTime _fpsTimer = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tts.init();
  }

  void _onResults(List<YOLOResult> results) {
    // Calcula FPS
    _frameCount++;
    final agora = DateTime.now();
    final diff = agora.difference(_fpsTimer).inMilliseconds;
    if (diff >= 1000) {
      _fps = (_frameCount * 1000 / diff).round();
      _frameCount = 0;
      _fpsTimer = agora;
    }

    // Converte YOLOResult → Detection para o TtsService
    // normalizedBox contém coordenadas [0,1] relativas ao frame
    final detections = results.map((r) => Detection(
      classIndex: r.classIndex,
      className: r.className,
      confidence: r.confidence,
      x1: r.normalizedBox.left,
      y1: r.normalizedBox.top,
      x2: r.normalizedBox.right,
      y2: r.normalizedBox.bottom,
    )).toList();

    _tts.processDetections(detections);
    if (mounted) setState(() => _results = results);
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // YOLOView: câmera + inferência nativa com GPU automático
          YOLOView(
            modelPath: 'best_float16',
            task: YOLOTask.detect,
            confidenceThreshold: 0.6,
            iouThreshold: 0.45,
            useGpu: _useGpu,
            showOverlays: false,   // usa nosso overlay customizado abaixo
            showNativeUI: false,
            onResult: _onResults,
          ),

          // Overlay com bounding boxes coloridas por prioridade
          if (_results.isNotEmpty)
            CustomPaint(
              painter: _DetectionPainter(results: _results),
            ),

          // Barra de status no topo
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.fiber_manual_record,
                color: Colors.greenAccent, size: 10),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _results.isEmpty
                    ? 'Nenhum objeto detectado'
                    : '${_results.length} objeto(s) detectado(s)',
                style: const TextStyle(color: Colors.white, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${_useGpu ? "GPU" : "CPU"} · $_fps fps',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter das bounding boxes com cores por prioridade
// ---------------------------------------------------------------------------

class _DetectionPainter extends CustomPainter {
  final List<YOLOResult> results;

  const _DetectionPainter({required this.results});

  @override
  void paint(Canvas canvas, Size size) {
    for (final r in results) {
      final cor = _corParaClasse(r.className);
      final paint = Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      // normalizedBox em [0,1] → converte para pixels da tela
      final rect = Rect.fromLTRB(
        r.normalizedBox.left   * size.width,
        r.normalizedBox.top    * size.height,
        r.normalizedBox.right  * size.width,
        r.normalizedBox.bottom * size.height,
      );

      canvas.drawRect(rect, paint);

      final label = '${r.className} ${(r.confidence * 100).toStringAsFixed(0)}%';
      final tp = TextPainter(
        text: TextSpan(
          text: ' $label ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            backgroundColor: cor.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(rect.left, rect.top - 18));
    }
  }

  @override
  bool shouldRepaint(_DetectionPainter old) => old.results != results;
}
