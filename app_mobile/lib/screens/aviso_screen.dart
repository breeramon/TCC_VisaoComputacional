import 'package:flutter/material.dart';

/// Aviso de segurança mostrado na primeira abertura do app.
class AvisoScreen extends StatelessWidget {
  final VoidCallback onAceitar;

  const AvisoScreen({super.key, required this.onAceitar});

  static const _estilo = TextStyle(
    color: Colors.white,
    fontSize: 20,
    height: 1.4,
  );

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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: const Text(
                          'Bem-vindo ao VozGuia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'O VozGuia usa a câmera do celular para avisar, por voz, '
                        'pessoas, portas, placas e outros objetos à sua volta.',
                        style: _estilo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Importante: o app é um apoio. Ele pode deixar de ver '
                        'obstáculos, como degraus e buracos, e não substitui a '
                        'bengala, o cão-guia ou a ajuda de outra pessoa.',
                        style: _estilo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Segure o celular na altura do peito, com a câmera '
                        'traseira virada para a frente. Toque duas vezes na tela '
                        'para pausar ou retomar os avisos.',
                        style: _estilo,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'As imagens são processadas só no seu celular. Nada é '
                        'enviado ou guardado.',
                        style: _estilo,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 72,
                child: ElevatedButton(
                  onPressed: onAceitar,
                  child: const Text(
                    'Entendi, começar',
                    style: TextStyle(fontSize: 22),
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
