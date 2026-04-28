import 'package:flutter_tts/flutter_tts.dart';
import '../detector/object_detector.dart';

/// Gerencia a síntese de voz com lógica de:
/// - Confirmação temporal (objeto precisa ser visível por X segundos)
/// - Reaviso periódico
/// - Alerta de proximidade crescente
/// - Prioridade por classe
/// - Concordância de gênero em português
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  // Chaves = nomes do modelo (inglês) — valores = (prioridade, segsConfirmação, segsReaviso)
  static const Map<String, (int, double, double)> _prioridades = {
    'person':            (1, 0.4, 3.0),
    'door':              (2, 0.4, 5.0),
    'elevator':          (2, 0.4, 5.0),
    'elevator sign':     (2, 0.8, 5.0),
    'stair sign':        (2, 0.4, 5.0),
    'exit sign':         (2, 0.8, 5.0),
    'fire alarm':        (3, 1.0, 5.0),
    'fire extinguisher': (2, 0.4, 5.0),
    'trash can':         (2, 0.4, 5.0),
    'water dispenser':   (2, 0.8, 5.0),
    'handle':            (3, 1.0, 5.0),
    'push handle':       (3, 1.0, 5.0),
    'men washroom':      (3, 1.0, 5.0),
    'women washrooom':   (3, 1.0, 5.0),
    'acessibility':      (2, 0.8, 5.0),
  };
  static const (int, double, double) _padrao = (3, 1.0, 8.0);

  // Nome em português falado pelo TTS (chave = nome do modelo em inglês)
  static const Map<String, String> _nomePt = {
    'person':            'Pessoa',
    'door':              'Porta',
    'elevator':          'Elevador',
    'elevator sign':     'Placa de elevador',
    'stair sign':        'Placa de escada',
    'exit sign':         'Sinalização de saída',
    'fire alarm':        'Alarme de incêndio',
    'fire extinguisher': 'Extintor de incêndio',
    'trash can':         'Lixeira',
    'water dispenser':   'Bebedouro',
    'handle':            'Maçaneta',
    'push handle':       'Maçaneta de empurrar',
    'men washroom':      'Banheiro masculino',
    'women washrooom':   'Banheiro feminino',
    'acessibility':      'Acessibilidade',
  };

  // Gênero gramatical para concordância (chave = nome do modelo em inglês)
  static const Map<String, String> _genero = {
    'person':            'f', // Pessoa
    'door':              'f', // Porta
    'elevator':          'm', // Elevador
    'elevator sign':     'f', // Placa
    'stair sign':        'f', // Placa
    'exit sign':         'f', // Sinalização
    'fire alarm':        'm', // Alarme
    'fire extinguisher': 'm', // Extintor
    'trash can':         'f', // Lixeira
    'water dispenser':   'm', // Bebedouro
    'handle':            'f', // Maçaneta
    'push handle':       'f', // Maçaneta
    'men washroom':      'm', // Banheiro
    'women washrooom':   'm', // Banheiro
    'acessibility':      'f', // Acessibilidade
  };

  static const double _limiarProximo = 0.15;
  static const double _limiarMuitoProximo = 0.30;

  // Estado interno de rastreamento
  final Map<String, DateTime> _emConfirmacao = {};
  final Map<String, DateTime> _ultimoAviso = {};
  final Map<String, int> _ultimoNivelProximo = {};

  Future<void> init() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setErrorHandler((_) => _speaking = false);
  }

  /// Recebe a lista de detecções do frame atual e decide o que falar.
  void processDetections(List<Detection> detections) {
    final now = DateTime.now();

    // Monta mapa: className (inglês) → (posicao, area, nivelProximidade)
    // Mantém apenas a maior bbox por classe (mais próxima)
    final Map<String, ({String posicao, double area, int nivelProx})> vistos = {};
    for (final d in detections) {
      final posicao = _calcularPosicao(d.x1, d.x2);
      final area = (d.x2 - d.x1) * (d.y2 - d.y1);
      final nivelProx = _calcularProximidade(area);

      if (!vistos.containsKey(d.className) || area > vistos[d.className]!.area) {
        vistos[d.className] = (posicao: posicao, area: area, nivelProx: nivelProx);
      }
    }

    // Remove do estado objetos que saíram do frame (reset dos timers)
    _emConfirmacao.removeWhere((k, _) => !vistos.containsKey(k));
    _ultimoNivelProximo.removeWhere((k, _) => !vistos.containsKey(k));

    // Registra primeira vez que cada objeto apareceu
    for (final obj in vistos.keys) {
      _emConfirmacao.putIfAbsent(obj, () => now);
    }

    // Monta lista de anúncios (prioridade, texto)
    final anuncios = <(int, String)>[];

    for (final entry in _emConfirmacao.entries) {
      final obj = entry.key;
      final info = vistos[obj]!;
      final (nivel, tConfirm, tReaviso) = _prioridades[obj] ?? _padrao;

      final estavel = now.difference(entry.value).inMilliseconds >=
          (tConfirm * 1000).toInt();

      final ultimoAv = _ultimoAviso[obj];
      final naoRecente = ultimoAv == null ||
          now.difference(ultimoAv).inMilliseconds >= (tReaviso * 1000).toInt();

      final nomePt = _nomePt[obj] ?? obj;
      final prefixo = _prefixoProximidade(info.nivelProx);
      final sufixo = _sufixoProximidade(info.nivelProx, obj);
      final texto = '$prefixo$nomePt$sufixo ${info.posicao}';

      if (estavel && naoRecente) {
        anuncios.add((nivel, texto));
        _ultimoAviso[obj] = now;
        _ultimoNivelProximo[obj] = info.nivelProx;
      } else if (estavel && info.nivelProx > (_ultimoNivelProximo[obj] ?? 0)) {
        // Proximidade aumentou — alerta imediato mesmo sem reaviso periódico
        anuncios.add((nivel, texto));
        _ultimoAviso[obj] = now;
        _ultimoNivelProximo[obj] = info.nivelProx;
      }
    }

    if (anuncios.isEmpty || _speaking) return;

    // Ordena por prioridade (1 = mais urgente)
    anuncios.sort((a, b) => a.$1.compareTo(b.$1));
    final textos = anuncios.map((e) => e.$2).toList();

    final mensagem = textos.length == 1
        ? '${textos[0]}.'
        : '${textos.sublist(0, textos.length - 1).join(', ')} e ${textos.last}.';

    _speak(mensagem);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _calcularPosicao(double x1, double x2) {
    final centro = (x1 + x2) / 2;
    if (centro < 1 / 3) return 'à sua esquerda';
    if (centro < 2 / 3) return 'à sua frente';
    return 'à sua direita';
  }

  int _calcularProximidade(double area) {
    if (area >= _limiarMuitoProximo) return 2;
    if (area >= _limiarProximo) return 1;
    return 0;
  }

  String _prefixoProximidade(int nivel) {
    if (nivel == 2) return 'Atenção! ';
    if (nivel == 1) return 'Atenção, ';
    return '';
  }

  String _sufixoProximidade(int nivel, String obj) {
    if (nivel == 0) return '';
    final feminino = (_genero[obj] ?? 'm') == 'f';
    if (nivel == 2) return feminino ? ' muito próxima' : ' muito próximo';
    return feminino ? ' próxima' : ' próximo';
  }

  Future<void> _speak(String text) async {
    if (_speaking) return;
    _speaking = true;
    await _tts.speak(text);
  }

  void dispose() => _tts.stop();
}
