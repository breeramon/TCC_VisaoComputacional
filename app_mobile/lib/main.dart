import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/aviso_screen.dart';
import 'screens/camera_screen.dart';

const _chaveAvisoAceito = 'aviso_seguranca_aceito_v1';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Força orientação retrato
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const VozGuiaApp());
}

class VozGuiaApp extends StatelessWidget {
  const VozGuiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VozGuia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent.shade400,
        ),
      ),
      home: const InicioScreen(),
    );
  }
}

enum _Etapa { carregando, aviso, permissao, camera }

/// Decide o que mostrar ao abrir o app:
/// 1. Aviso de segurança (só na primeira vez)
/// 2. Pedido de permissão da câmera
/// 3. Câmera
///
/// Verifica a permissão de novo sempre que o app volta para a frente,
/// para o caso de o usuário ter liberado a câmera nas configurações.
class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen>
    with WidgetsBindingObserver {
  _Etapa _etapa = _Etapa.carregando;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _etapa == _Etapa.permissao) {
      _verificarPermissao(pedir: false);
    }
  }

  Future<void> _iniciar() async {
    bool aceito = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      aceito = prefs.getBool(_chaveAvisoAceito) ?? false;
    } catch (_) {
      // Se as preferências falharem, mostra o aviso de novo (mais seguro)
    }
    if (!mounted) return;
    if (!aceito) {
      setState(() => _etapa = _Etapa.aviso);
      return;
    }
    await _verificarPermissao(pedir: true);
  }

  Future<void> _aceitarAviso() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chaveAvisoAceito, true);
    } catch (_) {}
    await _verificarPermissao(pedir: true);
  }

  Future<void> _verificarPermissao({required bool pedir}) async {
    var status = await Permission.camera.status;
    if (!status.isGranted && pedir) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;
    setState(() {
      _etapa = status.isGranted ? _Etapa.camera : _Etapa.permissao;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_etapa) {
      case _Etapa.carregando:
        return const Scaffold(backgroundColor: Colors.black);
      case _Etapa.aviso:
        return AvisoScreen(onAceitar: _aceitarAviso);
      case _Etapa.permissao:
        return SemPermissaoScreen(
          onTentarDeNovo: () => _verificarPermissao(pedir: true),
        );
      case _Etapa.camera:
        return const CameraScreen();
    }
  }
}

class SemPermissaoScreen extends StatelessWidget {
  final VoidCallback onTentarDeNovo;

  const SemPermissaoScreen({super.key, required this.onTentarDeNovo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.no_photography,
                      color: Colors.redAccent, size: 64),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: const Text(
                    'Permissão de câmera necessária',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'O VozGuia precisa da câmera para identificar os objetos à sua volta. '
                  'As imagens ficam apenas no seu celular.',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 64,
                  child: ElevatedButton(
                    onPressed: onTentarDeNovo,
                    child: const Text('Permitir câmera',
                        style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 64,
                  child: OutlinedButton(
                    onPressed: openAppSettings,
                    child: const Text('Abrir configurações',
                        style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
