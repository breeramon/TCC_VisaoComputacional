import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../detector/object_detector.dart';
import '../tts/tts_service.dart';

// Cores por prioridade (espelha a lógica do script Python)
const _corAlta   = Color(0xFFFF3B30); // vermelho  — Pessoa
const _corMedia  = Color(0xFFFF9500); // laranja   — Portas, Elevadores, Placas
const _corBaixa  = Color(0xFF34C759); // verde     — Referências

const _classesAlta  = {'Pessoa'};
const _classesMedia = {
  'Porta', 'Elevador', 'Placa de elevador', 'Placa de escada',
  'Sinalização de saída', 'Alarme de incêndio',
};

Color _corParaClasse(String className) {
  if (_classesAlta.contains(className)) return _corAlta;
  if (_classesMedia.contains(className)) return _corMedia;
  return _corBaixa;
}

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  final ObjectDetector _detector = ObjectDetector();
  final TtsService _tts = TtsService();

  List<Detection> _detections = [];
  bool _processing = false;
  bool _ready = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializar();
  }

  Future<void> _inicializar() async {
    try {
      await _detector.load();
      await _tts.init();

      _controller = CameraController(
        widget.cameras.first,
        ResolutionPreset.medium, // 720p — equilíbrio entre qualidade e performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller.initialize();

      _controller.startImageStream(_onFrame);

      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _erro = e.toString());
    }
  }

  void _onFrame(CameraImage image) {
    // Pula o frame se ainda estiver processando o anterior
    if (_processing || !_detector.isLoaded) return;
    _processing = true;

    // Roda a inferência fora da UI thread
    Future(() => _detector.detect(image)).then((dets) {
      if (!mounted) return;
      _tts.processDetections(dets);
      setState(() => _detections = dets);
      _processing = false;
    }).catchError((Object _) {
      _processing = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller.stopImageStream();
    } else if (state == AppLifecycleState.resumed) {
      _controller.startImageStream(_onFrame);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _detector.dispose();
    _tts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_erro != null) return _buildErro();
    if (!_ready) return _buildCarregando();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview da câmera
          CameraPreview(_controller),

          // Caixas de detecção sobrepostas
          if (_detections.isNotEmpty)
            CustomPaint(
              painter: _DetectionPainter(
                detections: _detections,
                previewSize: _controller.value.previewSize!,
                screenSize: MediaQuery.of(context).size,
              ),
            ),

          // Indicador de status no topo
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
            const Icon(Icons.fiber_manual_record, color: Colors.greenAccent, size: 10),
            const SizedBox(width: 6),
            Text(
              _detections.isEmpty
                  ? 'Nenhum objeto detectado'
                  : '${_detections.length} objeto(s) detectado(s)',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarregando() => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Carregando modelo de IA...',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );

  Widget _buildErro() => Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erro ao inicializar a câmera:\n\n$_erro',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Painter das bounding boxes
// ---------------------------------------------------------------------------

class _DetectionPainter extends CustomPainter {
  final List<Detection> detections;
  final Size previewSize;
  final Size screenSize;

  const _DetectionPainter({
    required this.detections,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final cor = _corParaClasse(det.className);
      final paint = Paint()
        ..color = cor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      // Converte coordenadas normalizadas [0,1] para pixels na tela
      // A câmera pode estar rodada 90°, então invertemos w/h
      final scaleX = size.width / previewSize.height;
      final scaleY = size.height / previewSize.width;

      final rect = Rect.fromLTRB(
        det.x1 * previewSize.height * scaleX,
        det.y1 * previewSize.width * scaleY,
        det.x2 * previewSize.height * scaleX,
        det.y2 * previewSize.width * scaleY,
      );

      canvas.drawRect(rect, paint);

      // Label com fundo colorido
      final label = '${det.className} ${(det.confidence * 100).toStringAsFixed(0)}%';
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
  bool shouldRepaint(_DetectionPainter old) => old.detections != detections;
}
