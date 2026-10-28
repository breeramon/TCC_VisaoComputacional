import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../detector/object_detector.dart';
import '../tts/tts_service.dart';
import 'sobre_screen.dart';

// Cores por prioridade (espelha a lógica do script Python)
const _corAlta = Color(0xFFFF3B30); // vermelho — Pessoa
const _corMedia = Color(0xFFFF9500); // laranja  — Portas, Elevadores, Placas
const _corBaixa = Color(0xFF34C759); // verde    — Banheiros, Maçanetas, Outros

const _classesAlta = {'person'};
const _classesMedia = {
  'door',
  'Chair',
  'table',
  'elevator',
  'elevator sign',
  'stair sign',
  'exit sign',
  'fire extinguisher',
  'trash can',
  'water dispenser',
  'acessibility',
};

Color _corParaClasse(String className) {
  if (_classesAlta.contains(className)) return _corAlta;
  if (_classesMedia.contains(className)) return _corMedia;
  return _corBaixa;
}

// Pedido de GPU — o plugin cai para CPU sozinho se o delegate falhar.
// Para saber o que foi usado de fato: adb logcat | findstr ObjectDetector
const _useGpu = true;

const _confianca = 0.6;
const _iou = 0.45;
// Limita a 7 detecções por frame — evita processar dezenas de bboxes desnecessárias
const _maxDeteccoes = 7;

// Limita a 15 inferências/segundo — suficiente para navegação e
// reduz consumo de CPU/bateria em dispositivos fracos
const _streamingConfig = YOLOStreamingConfig(inferenceFrequency: 15);

// Durante a pausa a câmera continua aberta (ver comentário em _CameraScreenState),
// então reduz a inferência a 1 por segundo para economizar bateria
const _streamingConfigPausado = YOLOStreamingConfig(inferenceFrequency: 1);

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final TtsService _tts = TtsService();
  final YOLOViewController _yoloController = YOLOViewController();

  List<YOLOResult> _results = [];
  int _fps = 0;
  int _frameCount = 0;
  DateTime _fpsTimer = DateTime.now();

  bool _pausado = false;
  bool _emSegundoPlano = false;

  // Uma única YOLOView fica montada o tempo todo. No ultralytics_yolo 0.2.0:
  // - controller.stop() descarta o modelo e os callbacks, e restartCamera()
  //   religa só a câmera (a detecção não volta);
  // - cada YOLOView se registra no ciclo de vida da Activity e nunca se
  //   desregistra; recriar a view deixa "zumbis" que roubam a câmera quando
  //   o app volta do segundo plano (tela preta ou congelada).
  // Por isso a pausa só ignora os resultados e reduz a frequência de inferência.
  // Rever ao atualizar o plugin (0.7.x já remove o observer no dispose).

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tts.init();
    // Guardados no controller e aplicados quando a câmera nativa inicializa
    _yoloController.setThresholds(
      confidenceThreshold: _confianca,
      iouThreshold: _iou,
      numItemsThreshold: _maxDeteccoes,
    );
    // Mantém a tela ligada: se ela apagar, a câmera para
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _emSegundoPlano = false;
      if (!_pausado) {
        _tts.retomar();
        WakelockPlus.enable();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (!_emSegundoPlano) {
        _emSegundoPlano = true;
        _tts.pausar();
      }
    }
  }

  Future<void> _alternarPausa() async {
    if (_pausado) {
      setState(() {
        _pausado = false;
        _frameCount = 0;
        _fps = 0;
        _fpsTimer = DateTime.now();
      });
      await _yoloController.setStreamingConfig(_streamingConfig);
      _tts.retomar();
      WakelockPlus.enable();
      await _tts.falarAgora('Detecção retomada');
    } else {
      setState(() {
        _pausado = true;
        _results = [];
      });
      await _yoloController.setStreamingConfig(_streamingConfigPausado);
      await _tts.pausar();
      WakelockPlus.disable();
      await _tts.falarAgora('Detecção pausada. Toque duas vezes para retomar.');
    }
  }

  Future<void> _abrirSobre() async {
    final estavaPausado = _pausado;
    if (!estavaPausado) await _alternarPausa();
    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SobreScreen()));
    if (!mounted) return;
    if (!estavaPausado) await _alternarPausa();
  }

  void _onResults(List<YOLOResult> results) {
    if (_pausado || _emSegundoPlano) return;

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
    final detections = results
        .map(
          (r) => Detection(
            classIndex: r.classIndex,
            className: r.className,
            confidence: r.confidence,
            x1: r.normalizedBox.left,
            y1: r.normalizedBox.top,
            x2: r.normalizedBox.right,
            y2: r.normalizedBox.bottom,
          ),
        )
        .toList();

    _tts.processDetections(detections);
    if (mounted) setState(() => _results = results);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
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
          // YOLOView: câmera + inferência nativa com GPU (sempre montada)
          ExcludeSemantics(
            child: YOLOView(
              modelPath: 'best_int8',
              task: YOLOTask.detect,
              controller: _yoloController,
              streamingConfig: _streamingConfig,
              confidenceThreshold: _confianca,
              iouThreshold: _iou,
              useGpu: _useGpu,
              showOverlays: false,
              showNativeUI: false,
              onResult: _onResults,
            ),
          ),

          // Overlay com bounding boxes coloridas por prioridade
          if (_results.isNotEmpty && !_pausado)
            ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DetectionPainter(results: _results),
                ),
              ),
            ),

          // Área de toque da tela inteira: toque duplo pausa/retoma.
          // Com TalkBack, o leitor anuncia o rótulo e o toque duplo ativa onTap.
          Semantics(
            button: true,
            label: _pausado ? 'Retomar detecção' : 'Pausar detecção',
            hint: _pausado
                ? 'Os avisos estão pausados'
                : 'Os avisos estão ativos',
            onTap: _alternarPausa,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _alternarPausa,
              child: _pausado ? _buildPausado() : const SizedBox.expand(),
            ),
          ),

          // Barra de status no topo
          _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildPausado() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_circle_filled, color: Colors.white, size: 96),
          SizedBox(height: 24),
          Text(
            'Pausado\nToque duas vezes para retomar',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24),
          ),
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
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.fiber_manual_record,
                color: _pausado ? Colors.white54 : Colors.greenAccent,
                size: 10,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  _pausado
                      ? 'Pausado'
                      : _results.isEmpty
                      ? 'Nenhum objeto detectado'
                      : '${_results.length} objeto(s) detectado(s)',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                '${_useGpu ? "GPU" : "CPU"} · $_fps fps',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
            IconButton(
              onPressed: _abrirSobre,
              icon: const Icon(Icons.info_outline, color: Colors.white),
              tooltip: 'Sobre o VozGuia',
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
        r.normalizedBox.left * size.width,
        r.normalizedBox.top * size.height,
        r.normalizedBox.right * size.width,
        r.normalizedBox.bottom * size.height,
      );

      canvas.drawRect(rect, paint);

      final label =
          '${r.className} ${(r.confidence * 100).toStringAsFixed(0)}%';
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
