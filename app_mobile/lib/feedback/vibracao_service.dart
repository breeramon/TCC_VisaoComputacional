import 'package:vibration/vibration.dart';

/// Padrões de vibração que acompanham os avisos de voz.
///
/// Cada padrão é diferente o bastante para ser reconhecido sem ouvir a fala
/// (útil em lugares barulhentos ou para quem também tem perda auditiva).
class VibracaoService {
  bool _disponivel = false;

  /// Liga/desliga pela tela de configurações.
  bool ativo = true;

  // Padrões: [espera, vibra, espera, vibra, ...] em milissegundos
  static const List<int> _padraoProximo = [0, 120];
  static const List<int> _padraoMuitoProximo = [0, 150, 100, 150, 100, 150];
  static const List<int> _padraoPausa = [0, 400];
  static const List<int> _padraoRetomada = [0, 80, 80, 80];

  Future<void> init() async {
    try {
      _disponivel = (await Vibration.hasVibrator()) == true;
    } catch (_) {
      _disponivel = false;
    }
  }

  /// Vibra conforme o nível de proximidade do aviso: 1 = próximo, 2 = muito próximo.
  /// Nível 0 (longe) não vibra.
  void proximidade(int nivel) {
    if (nivel >= 2) {
      _vibrar(_padraoMuitoProximo);
    } else if (nivel == 1) {
      _vibrar(_padraoProximo);
    }
  }

  void pausa() => _vibrar(_padraoPausa);

  void retomada() => _vibrar(_padraoRetomada);

  void _vibrar(List<int> padrao) {
    if (!_disponivel || !ativo) return;
    try {
      Vibration.vibrate(pattern: padrao);
    } catch (_) {
      // Vibração é complemento: se falhar, os avisos de voz continuam
    }
  }

  void dispose() {
    if (!_disponivel) return;
    try {
      Vibration.cancel();
    } catch (_) {}
  }
}
