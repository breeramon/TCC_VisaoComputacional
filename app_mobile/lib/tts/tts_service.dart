import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/configuracoes.dart';
import '../detector/object_detector.dart';

/// Gerencia a síntese de voz com lógica de:
/// - Confirmação temporal (objeto precisa ser visível por X segundos)
/// - Tolerância a falhas de detecção (objeto só "sai" após sumir por um tempo)
/// - Reaviso periódico
/// - Alerta de proximidade crescente, com interrupção para alertas urgentes
/// - Prioridade por classe e limite de itens por aviso
/// - Concordância de gênero em português
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  bool _falandoUrgente = false;
  bool _ativo = true;
  Configuracoes _config = const Configuracoes();

  /// Chamado a cada aviso de detecção com o maior nível de proximidade dos
  /// objetos anunciados (0 = longe, 1 = próximo, 2 = muito próximo).
  /// Usado para disparar a vibração junto com a fala.
  void Function(int nivelProximidade)? aoAnunciar;

  // Chaves = nomes do modelo (inglês) — valores = (prioridade, segsConfirmação, segsReaviso)
  static const Map<String, (int, double, double)> _prioridades = {
    'person': (1, 0.4, 3.0),
    'door': (2, 0.4, 5.0),
    'Chair': (2, 0.4, 5.0),
    'table': (2, 0.4, 5.0),
    'elevator': (2, 0.4, 5.0),
    'elevator sign': (2, 0.8, 5.0),
    'stair sign': (2, 0.4, 5.0),
    'exit sign': (2, 0.8, 5.0),
    'fire extinguisher': (2, 0.4, 5.0),
    'acessibility': (2, 0.8, 5.0),
    'trash can': (2, 0.4, 5.0),
    'water dispenser': (2, 0.8, 5.0),
    'fire alarm': (3, 1.0, 5.0),
    'handle': (3, 0.8, 5.0),
    'push handle': (3, 0.8, 5.0),
    'men washroom': (3, 0.4, 5.0),
    'women washrooom': (3, 0.4, 5.0),
  };
  static const (int, double, double) _padrao = (3, 1.0, 8.0);

  // Nome em português falado pelo TTS (chave = nome do modelo em inglês)
  static const Map<String, String> _nomePt = {
    'person': 'Pessoa',
    'door': 'Porta',
    'Chair': 'Cadeira',
    'table': 'Mesa',
    'elevator': 'Elevador',
    'elevator sign': 'Placa de elevador',
    'stair sign': 'Placa de escada',
    'exit sign': 'Sinalização de saída',
    'fire extinguisher': 'Extintor de incêndio',
    'acessibility': 'Acessibilidade',
    'trash can': 'Lixeira',
    'water dispenser': 'Bebedouro',
    'fire alarm': 'Alarme de incêndio',
    'handle': 'Maçaneta',
    'push handle': 'Maçaneta de empurrar',
    'men washroom': 'Banheiro masculino',
    'women washrooom': 'Banheiro feminino',
  };

  // Gênero gramatical para concordância (chave = nome do modelo em inglês)
  static const Map<String, String> _genero = {
    'person': 'f', // Pessoa
    'door': 'f', // Porta
    'Chair': 'f', // Cadeira
    'table': 'f', // Mesa
    'elevator': 'm', // Elevador
    'elevator sign': 'f', // Placa
    'stair sign': 'f', // Placa
    'exit sign': 'f', // Sinalização
    'fire alarm': 'm', // Alarme
    'fire extinguisher': 'm', // Extintor
    'trash can': 'f', // Lixeira
    'water dispenser': 'm', // Bebedouro
    'handle': 'f', // Maçaneta
    'push handle': 'f', // Maçaneta
    'men washroom': 'm', // Banheiro
    'women washrooom': 'm', // Banheiro
    'acessibility': 'f', // Acessibilidade
  };

  // Limiares de proximidade por classe, em fração da área do quadro ocupada
  // pela caixa: (próximo, muito próximo). Objetos grandes (porta, elevador)
  // ocupam muito do quadro mesmo de longe; placas e maçanetas são pequenas.
  // `null` em "muito próximo" = a classe nunca vira alerta urgente (placas não
  // são obstáculos). Valores iniciais — calibrar com testes no celular.
  static const Map<String, (double, double?)> _limiaresProximidade = {
    // Obstáculos
    'person': (0.15, 0.30),
    'Chair': (0.10, 0.25),
    'table': (0.15, 0.35),
    'trash can': (0.06, 0.15),
    'water dispenser': (0.08, 0.20),
    'door': (0.35, 0.60),
    'elevator': (0.35, 0.60),
    // Referências na parede (nunca urgentes)
    'fire extinguisher': (0.04, null),
    'fire alarm': (0.02, null),
    'elevator sign': (0.03, null),
    'stair sign': (0.03, null),
    'exit sign': (0.03, null),
    'acessibility': (0.03, null),
    'men washroom': (0.03, null),
    'women washrooom': (0.03, null),
    'handle': (0.02, null),
    'push handle': (0.02, null),
  };
  static const (double, double?) _limiaresPadrao = (0.15, 0.30);

  /// Quantos objetos, no máximo, entram em um mesmo aviso.
  static const int _maxItensPorAviso = 2;

  /// Tempo que um objeto pode sumir do quadro sem perder a confirmação.
  static const Duration _toleranciaSumico = Duration(milliseconds: 500);

  // Estado interno de rastreamento
  final Map<String, DateTime> _emConfirmacao = {};
  final Map<String, DateTime> _vistoPorUltimo = {};
  final Map<String, DateTime> _ultimoAviso = {};
  final Map<String, int> _ultimoNivelProximo = {};

  Future<void> init() async {
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(_config.velocidadeFala);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    // Sem setCancelHandler de propósito: quando a fala é interrompida,
    // o próprio serviço atualiza o estado (ver _interromper).
    _tts.setCompletionHandler(_fimDaFala);
    _tts.setErrorHandler((_) => _fimDaFala());
  }

  void _fimDaFala() {
    _speaking = false;
    _falandoUrgente = false;
  }

  /// Aplica as configurações do usuário (velocidade da fala, classes, posição).
  Future<void> aplicarConfiguracoes(Configuracoes config) async {
    _config = config;
    await _tts.setSpeechRate(config.velocidadeFala);
  }

  /// Para de anunciar e esquece o que estava vendo.
  Future<void> pausar() async {
    _ativo = false;
    _limparEstado();
    await _interromper();
  }

  void retomar() {
    _limparEstado();
    _ativo = true;
  }

  /// Fala uma mensagem do sistema (ex.: "Detecção pausada"), interrompendo o que estiver falando.
  Future<void> falarAgora(String texto) async {
    await _interromper();
    _speaking = true;
    await _tts.speak(texto);
  }

  /// Recebe a lista de detecções do frame atual e decide o que falar.
  void processDetections(List<Detection> detections) {
    if (!_ativo) return;
    final now = DateTime.now();

    // Monta mapa: className (inglês) → (posicao, area, nivelProximidade)
    // Mantém apenas a maior bbox por classe (mais próxima)
    final Map<String, ({String posicao, double area, int nivelProx})> vistos =
        {};
    for (final d in detections) {
      // Classes desligadas nas configurações não são anunciadas
      if (!_config.anuncia(d.className)) continue;
      final posicao = _calcularPosicao(d.x1, d.x2);
      final area = (d.x2 - d.x1) * (d.y2 - d.y1);
      final nivelProx = nivelProximidade(d.className, area);

      if (!vistos.containsKey(d.className) ||
          area > vistos[d.className]!.area) {
        vistos[d.className] = (
          posicao: posicao,
          area: area,
          nivelProx: nivelProx,
        );
      }
    }

    // Registra quando cada objeto foi visto
    for (final obj in vistos.keys) {
      _vistoPorUltimo[obj] = now;
      _emConfirmacao.putIfAbsent(obj, () => now);
    }

    // Só considera que o objeto saiu depois de sumir por mais que a tolerância
    final sumidos = _vistoPorUltimo.entries
        .where((e) => now.difference(e.value) > _toleranciaSumico)
        .map((e) => e.key)
        .toList();
    for (final obj in sumidos) {
      _vistoPorUltimo.remove(obj);
      _emConfirmacao.remove(obj);
      _ultimoNivelProximo.remove(obj);
    }

    // Coleta candidatos sem modificar estado — timers só atualizam se o TTS falar
    final candidatos =
        <({int nivel, bool urgente, String texto, String obj})>[];

    for (final MapEntry(key: obj, value: info) in vistos.entries) {
      final inicio = _emConfirmacao[obj];
      if (inicio == null) continue;
      final (nivel, tConfirm, tReaviso) = _prioridades[obj] ?? _padrao;

      final estavel =
          now.difference(inicio).inMilliseconds >= (tConfirm * 1000).toInt();

      final ultimoAv = _ultimoAviso[obj];
      final naoRecente =
          ultimoAv == null ||
          now.difference(ultimoAv).inMilliseconds >= (tReaviso * 1000).toInt();

      // Proximidade aumentou — alerta imediato mesmo sem reaviso periódico
      final aproximou = info.nivelProx > (_ultimoNivelProximo[obj] ?? 0);

      if (estavel && (naoRecente || aproximou)) {
        final nomePt = _nomePt[obj] ?? obj;
        final prefixo = _prefixoProximidade(info.nivelProx);
        final sufixo = _sufixoProximidade(info.nivelProx, obj);
        candidatos.add((
          nivel: nivel,
          urgente: info.nivelProx == 2,
          texto: _config.anunciarPosicao
              ? '$prefixo$nomePt$sufixo ${info.posicao}'
              : '$prefixo$nomePt$sufixo',
          obj: obj,
        ));
      }
    }

    if (candidatos.isEmpty) return;

    final temUrgente = candidatos.any((c) => c.urgente);
    if (_speaking) {
      // Só um alerta urgente interrompe uma fala comum
      if (!temUrgente || _falandoUrgente) return;
    }

    // Urgentes primeiro, depois por prioridade (1 = mais urgente)
    candidatos.sort((a, b) {
      if (a.urgente != b.urgente) return a.urgente ? -1 : 1;
      return a.nivel.compareTo(b.nivel);
    });
    final escolhidos = candidatos.take(_maxItensPorAviso).toList();

    // Só aqui atualiza os timers — apenas dos objetos que serão falados
    for (final c in escolhidos) {
      _ultimoAviso[c.obj] = now;
      _ultimoNivelProximo[c.obj] = vistos[c.obj]!.nivelProx;
    }

    final textos = escolhidos.map((c) => c.texto).toList();
    final mensagem = textos.length == 1
        ? '${textos[0]}.'
        : '${textos.sublist(0, textos.length - 1).join(', ')} e ${textos.last}.';

    final nivelMaximo = escolhidos
        .map((c) => vistos[c.obj]!.nivelProx)
        .fold(0, (a, b) => a > b ? a : b);
    aoAnunciar?.call(nivelMaximo);

    _speak(mensagem, urgente: escolhidos.any((c) => c.urgente));
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _limparEstado() {
    _emConfirmacao.clear();
    _vistoPorUltimo.clear();
    _ultimoNivelProximo.clear();
  }

  Future<void> _interromper() async {
    if (_speaking) {
      await _tts.stop();
    }
    _fimDaFala();
  }

  String _calcularPosicao(double x1, double x2) {
    final centro = (x1 + x2) / 2;
    if (centro < 1 / 3) return 'à sua esquerda';
    if (centro < 2 / 3) return 'à sua frente';
    return 'à sua direita';
  }

  /// Nível de proximidade de um objeto: 0 = longe, 1 = próximo, 2 = muito próximo.
  /// [area] é a fração do quadro ocupada pela caixa (0 a 1).
  @visibleForTesting
  static int nivelProximidade(String classe, double area) {
    final (proximo, muitoProximo) =
        _limiaresProximidade[classe] ?? _limiaresPadrao;
    if (muitoProximo != null && area >= muitoProximo) return 2;
    if (area >= proximo) return 1;
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

  Future<void> _speak(String text, {required bool urgente}) async {
    if (_speaking) {
      // Chegou aqui com fala em andamento = alerta urgente interrompendo
      await _interromper();
    }
    _speaking = true;
    _falandoUrgente = urgente;
    await _tts.speak(text);
  }

  void dispose() => _tts.stop();
}
