import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../config/configuracoes.dart';

/// Passos do tutorial, na ordem em que são falados e mostrados.
const passosTutorial = <String>[
  'Segure o celular na altura do peito, com a câmera traseira apontando para '
      'a frente. Ande devagar.',
  'O VozGuia avisa pessoas, portas, cadeiras, placas e outros objetos, e diz '
      'se estão à sua esquerda, à sua frente ou à sua direita.',
  'Quando algo está próximo, o celular vibra uma vez. Quando está muito '
      'próximo, vibra três vezes e o aviso começa com "Atenção!".',
  'Toque duas vezes em qualquer lugar da tela para pausar ou retomar os '
      'avisos. No canto de cima, à direita, ficam as configurações e as '
      'informações sobre o app.',
];

/// Tutorial mostrado na primeira abertura (e pela tela "Sobre").
///
/// Sem leitor de tela, o app fala os passos um a um, na velocidade escolhida
/// nas configurações. Com o TalkBack ligado, o app não fala: o próprio leitor
/// lê o texto, para não haver duas vozes ao mesmo tempo.
/// Toque duplo em qualquer lugar (ou o botão "Começar") encerra o tutorial.
class TutorialScreen extends StatefulWidget {
  final VoidCallback onConcluir;

  const TutorialScreen({super.key, required this.onConcluir});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final FlutterTts _tts = FlutterTts();
  int _passoAtual = -1; // -1 = ainda não começou a falar
  bool _encerrado = false;
  bool _iniciado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_iniciado) return;
    _iniciado = true;
    // Com TalkBack (navegação acessível), o leitor de tela lê o texto
    if (!MediaQuery.of(context).accessibleNavigation) _narrar();
  }

  Future<void> _narrar() async {
    final config = await Configuracoes.carregar();
    await _tts.setLanguage('pt-BR');
    await _tts.setSpeechRate(config.velocidadeFala);
    await _tts.awaitSpeakCompletion(true);

    for (var i = 0; i < passosTutorial.length; i++) {
      if (_encerrado || !mounted) return;
      setState(() => _passoAtual = i);
      await _tts.speak(passosTutorial[i]);
      if (_encerrado) return;
      await Future.delayed(const Duration(milliseconds: 400));
    }
    if (_encerrado || !mounted) return;
    setState(() => _passoAtual = passosTutorial.length);
    await _tts.speak('Toque duas vezes na tela para começar.');
  }

  void _concluir() {
    if (_encerrado) return;
    _encerrado = true;
    // Conclui na hora; parar a voz não pode travar a saída do tutorial
    _tts.stop().catchError((_) => null);
    widget.onConcluir();
  }

  @override
  void dispose() {
    _encerrado = true;
    _tts.stop().catchError((_) => null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Toque duplo só na área do texto: se cobrisse o botão, cada
              // toque no "Começar" esperaria ~300 ms por um possível 2º toque
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: _concluir,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          'Como usar o VozGuia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Coluna rolável (não ListView): todos os passos ficam
                      // montados, então o TalkBack lê todos, mesmo em telas pequenas
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < passosTutorial.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Text(
                                    passosTutorial[i],
                                    style: TextStyle(
                                      // Destaca o passo sendo falado; antes de
                                      // começar e no fim, todos ficam claros
                                      color:
                                          _passoAtual < 0 ||
                                              _passoAtual >=
                                                  passosTutorial.length ||
                                              _passoAtual == i
                                          ? Colors.white
                                          : Colors.white38,
                                      fontSize: 20,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Toque duas vezes no texto para pular.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 72,
                child: ElevatedButton(
                  onPressed: _concluir,
                  child: const Text('Começar', style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
