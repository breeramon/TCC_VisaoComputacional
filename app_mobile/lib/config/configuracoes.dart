import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do usuário, guardadas só no aparelho.
class Configuracoes {
  /// Velocidade da fala no flutter_tts (Android: 0.0 a 1.0; 0.5 = normal).
  final double velocidadeFala;
  final bool vibracao;

  /// Diz "à sua esquerda / frente / direita" depois do nome do objeto.
  final bool anunciarPosicao;

  /// Placas: elevador, escada, saída, acessibilidade, banheiros.
  final bool anunciarSinalizacao;

  /// Extintor, alarme de incêndio e maçanetas.
  final bool anunciarEquipamentos;

  const Configuracoes({
    this.velocidadeFala = 0.5,
    this.vibracao = true,
    this.anunciarPosicao = true,
    this.anunciarSinalizacao = true,
    this.anunciarEquipamentos = true,
  });

  static const velocidadeMinima = 0.3;
  static const velocidadeMaxima = 1.0;

  /// Classes que podem ser desligadas, por grupo. Obstáculos (pessoa, porta,
  /// cadeira, mesa, lixeira, bebedouro, elevador) são sempre anunciados.
  static const classesSinalizacao = {
    'elevator sign',
    'stair sign',
    'exit sign',
    'acessibility',
    'men washroom',
    'women washrooom',
  };
  static const classesEquipamentos = {
    'fire extinguisher',
    'fire alarm',
    'handle',
    'push handle',
  };

  /// Se a classe deve ser anunciada com estas configurações.
  bool anuncia(String classe) {
    if (classesSinalizacao.contains(classe)) return anunciarSinalizacao;
    if (classesEquipamentos.contains(classe)) return anunciarEquipamentos;
    return true;
  }

  Configuracoes copyWith({
    double? velocidadeFala,
    bool? vibracao,
    bool? anunciarPosicao,
    bool? anunciarSinalizacao,
    bool? anunciarEquipamentos,
  }) {
    return Configuracoes(
      velocidadeFala: velocidadeFala ?? this.velocidadeFala,
      vibracao: vibracao ?? this.vibracao,
      anunciarPosicao: anunciarPosicao ?? this.anunciarPosicao,
      anunciarSinalizacao: anunciarSinalizacao ?? this.anunciarSinalizacao,
      anunciarEquipamentos: anunciarEquipamentos ?? this.anunciarEquipamentos,
    );
  }

  // ---------------------------------------------------------------------------
  // Persistência
  // ---------------------------------------------------------------------------

  static const _kVelocidade = 'config_velocidade_fala';
  static const _kVibracao = 'config_vibracao';
  static const _kPosicao = 'config_anunciar_posicao';
  static const _kSinalizacao = 'config_anunciar_sinalizacao';
  static const _kEquipamentos = 'config_anunciar_equipamentos';

  static Future<Configuracoes> carregar() async {
    const padrao = Configuracoes();
    try {
      final p = await SharedPreferences.getInstance();
      return Configuracoes(
        velocidadeFala: (p.getDouble(_kVelocidade) ?? padrao.velocidadeFala)
            .clamp(velocidadeMinima, velocidadeMaxima),
        vibracao: p.getBool(_kVibracao) ?? padrao.vibracao,
        anunciarPosicao: p.getBool(_kPosicao) ?? padrao.anunciarPosicao,
        anunciarSinalizacao:
            p.getBool(_kSinalizacao) ?? padrao.anunciarSinalizacao,
        anunciarEquipamentos:
            p.getBool(_kEquipamentos) ?? padrao.anunciarEquipamentos,
      );
    } catch (_) {
      return padrao;
    }
  }

  Future<void> salvar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kVelocidade, velocidadeFala);
      await p.setBool(_kVibracao, vibracao);
      await p.setBool(_kPosicao, anunciarPosicao);
      await p.setBool(_kSinalizacao, anunciarSinalizacao);
      await p.setBool(_kEquipamentos, anunciarEquipamentos);
    } catch (_) {
      // Se não salvar, a configuração vale só até fechar o app
    }
  }
}
