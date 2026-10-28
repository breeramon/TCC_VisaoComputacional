import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _urlCodigo = 'https://github.com/breeramon/TCC_VisaoComputacional';

const _datasets = <(String, String)>[
  (
    'deteccao-de-objetos-faculdade (Breno Ramon)',
    'https://universe.roboflow.com/breno-s-workspace/deteccao-de-objetos-faculdade',
  ),
  (
    'indoor-navigation (akhash)',
    'https://universe.roboflow.com/akhash/indoor-navigation-xs4of',
  ),
  (
    'person-detection (titulacin)',
    'https://universe.roboflow.com/titulacin/person-detection-9a6mk',
  ),
  (
    'indoor-navigation-v8ctg (final-project-4152)',
    'https://universe.roboflow.com/final-project-4152/indoor-navigation-v8ctg',
  ),
  (
    'door-detection (cody-pwtvk)',
    'https://universe.roboflow.com/cody-pwtvk/door-detection-j97hy',
  ),
];

/// Tela "Sobre": licença, código-fonte, créditos dos datasets e privacidade.
class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  Future<void> _abrir(BuildContext context, String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não foi possível abrir $url')));
    }
  }

  Widget _titulo(String texto) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  static const _estilo = TextStyle(
    color: Colors.white70,
    fontSize: 18,
    height: 1.4,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Sobre o VozGuia'),
        backgroundColor: Colors.black,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'O VozGuia avisa por voz pessoas, portas, placas e outros objetos '
              'em ambientes internos, para apoiar pessoas com deficiência visual.',
              style: _estilo,
            ),
            _titulo('Segurança'),
            const Text(
              'O app é um apoio e pode deixar de ver obstáculos. Ele não '
              'substitui a bengala, o cão-guia ou a ajuda de outra pessoa.',
              style: _estilo,
            ),
            _titulo('Privacidade'),
            const Text(
              'As imagens da câmera são processadas só no seu celular. Nada é '
              'enviado para a internet nem guardado.',
              style: _estilo,
            ),
            _titulo('Código aberto'),
            const Text(
              'O VozGuia é gratuito e tem código aberto sob a licença '
              'GNU AGPL-3.0. Ele usa o Ultralytics YOLO, também AGPL-3.0.',
              style: _estilo,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: () => _abrir(context, _urlCodigo),
                child: const Text(
                  'Ver o código-fonte no GitHub',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            _titulo('Créditos dos dados'),
            const Text(
              'O modelo foi treinado com estes conjuntos de imagens, '
              'sob a licença CC BY 4.0:',
              style: _estilo,
            ),
            const SizedBox(height: 8),
            for (final (nome, url) in _datasets)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  nome,
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
                subtitle: const Text(
                  'Roboflow Universe',
                  style: TextStyle(color: Colors.white54),
                ),
                trailing: const ExcludeSemantics(
                  child: Icon(Icons.open_in_new, color: Colors.white54),
                ),
                onTap: () => _abrir(context, url),
              ),
            _titulo('Autor'),
            const Text('Breno Ramon Santana dos Santos', style: _estilo),
          ],
        ),
      ),
    );
  }
}
