import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/camera_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Força orientação retrato
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Solicita permissão de câmera
  final status = await Permission.camera.request();

  runApp(NavIndoorApp(cameraPermitida: status.isGranted));
}

class NavIndoorApp extends StatelessWidget {
  final bool cameraPermitida;

  const NavIndoorApp({super.key, required this.cameraPermitida});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navegação Indoor — TCC UNIT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: Colors.greenAccent.shade400,
        ),
      ),
      home: cameraPermitida ? const CameraScreen() : const _SemPermissaoScreen(),
    );
  }
}

class _SemPermissaoScreen extends StatelessWidget {
  const _SemPermissaoScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography, color: Colors.redAccent, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Permissão de câmera necessária',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Acesse as configurações do aplicativo e conceda a permissão de câmera para continuar.',
                style: TextStyle(color: Colors.white60),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: openAppSettings,
                child: const Text('Abrir Configurações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
