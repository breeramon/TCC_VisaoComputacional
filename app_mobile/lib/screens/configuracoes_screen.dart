import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/configuracoes.dart';

/// Tela de configurações. Cada mudança é salva na hora.
/// Ao sair, devolve as configurações atuais pelo Navigator.pop.
class ConfiguracoesScreen extends StatefulWidget {
  final Configuracoes inicial;

  const ConfiguracoesScreen({super.key, required this.inicial});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen> {
  late Configuracoes _config = widget.inicial;
  final FlutterTts _teste = FlutterTts();

  // Passos da velocidade da fala, com nome para o leitor de tela
  static const _passos = <(double, String)>[
    (0.3, 'Muito lenta'),
    (0.4, 'Lenta'),
    (0.5, 'Normal'),
    (0.6, 'Um pouco rápida'),
    (0.7, 'Rápida'),
    (0.85, 'Muito rápida'),
    (1.0, 'Máxima'),
  ];

  int get _indiceVelocidade {
    var melhor = 0;
    for (var i = 0; i < _passos.length; i++) {
      if ((_passos[i].$1 - _config.velocidadeFala).abs() <
          (_passos[melhor].$1 - _config.velocidadeFala).abs()) {
        melhor = i;
      }
    }
    return melhor;
  }

  @override
  void initState() {
    super.initState();
    _teste.setLanguage('pt-BR');
  }

  @override
  void dispose() {
    _teste.stop();
    super.dispose();
  }

  void _atualizar(Configuracoes nova) {
    setState(() => _config = nova);
    nova.salvar();
  }

  Future<void> _testarVelocidade() async {
    await _teste.stop();
    await _teste.setSpeechRate(_config.velocidadeFala);
    await _teste.speak('Porta à sua frente.');
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
    child: Semantics(
      header: true,
      child: Text(
        texto,
        style: TextStyle(
          color: Colors.greenAccent.shade400,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  Widget _chave({
    required String titulo,
    required String descricao,
    required bool valor,
    required ValueChanged<bool> aoMudar,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(
        titulo,
        style: const TextStyle(color: Colors.white, fontSize: 20),
      ),
      subtitle: Text(
        descricao,
        style: const TextStyle(color: Colors.white60, fontSize: 16),
      ),
      value: valor,
      onChanged: aoMudar,
    );
  }

  @override
  Widget build(BuildContext context) {
    final indice = _indiceVelocidade;
    final nomeVelocidade = _passos[indice].$2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_config);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Configurações'),
          backgroundColor: Colors.black,
        ),
        body: SafeArea(
          child: ListView(
            children: [
              _titulo('Voz'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ExcludeSemantics(
                  child: Text(
                    'Velocidade da fala: $nomeVelocidade',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Semantics(
                  label: 'Velocidade da fala',
                  child: Slider(
                    value: indice.toDouble(),
                    min: 0,
                    max: (_passos.length - 1).toDouble(),
                    divisions: _passos.length - 1,
                    label: nomeVelocidade,
                    semanticFormatterCallback: (v) => _passos[v.round()].$2,
                    onChanged: (v) => _atualizar(
                      _config.copyWith(velocidadeFala: _passos[v.round()].$1),
                    ),
                    onChangeEnd: (_) => _testarVelocidade(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _testarVelocidade,
                    icon: const ExcludeSemantics(child: Icon(Icons.volume_up)),
                    label: const Text(
                      'Ouvir exemplo',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
              _chave(
                titulo: 'Dizer a posição',
                descricao: 'Ex.: "à sua esquerda", "à sua frente"',
                valor: _config.anunciarPosicao,
                aoMudar: (v) =>
                    _atualizar(_config.copyWith(anunciarPosicao: v)),
              ),
              _titulo('O que anunciar'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Pessoas, portas, cadeiras, mesas, lixeiras, bebedouros e '
                  'elevadores são sempre anunciados.',
                  style: TextStyle(color: Colors.white60, fontSize: 16),
                ),
              ),
              _chave(
                titulo: 'Placas e sinalização',
                descricao:
                    'Elevador, escada, saída, acessibilidade e banheiros',
                valor: _config.anunciarSinalizacao,
                aoMudar: (v) =>
                    _atualizar(_config.copyWith(anunciarSinalizacao: v)),
              ),
              _chave(
                titulo: 'Equipamentos',
                descricao: 'Extintor, alarme de incêndio e maçanetas',
                valor: _config.anunciarEquipamentos,
                aoMudar: (v) =>
                    _atualizar(_config.copyWith(anunciarEquipamentos: v)),
              ),
              _titulo('Vibração'),
              _chave(
                titulo: 'Vibrar nos avisos',
                descricao: 'Quando um objeto está próximo e ao pausar',
                valor: _config.vibracao,
                aoMudar: (v) => _atualizar(_config.copyWith(vibracao: v)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  height: 56,
                  child: TextButton(
                    onPressed: () => _atualizar(const Configuracoes()),
                    child: const Text(
                      'Restaurar padrões',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
