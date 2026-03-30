import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nav_indoor_tcc/main.dart';

void main() {
  testWidgets('App renderiza tela de sem permissão quando não há câmeras',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const NavIndoorApp(cameras: <CameraDescription>[], cameraPermitida: false),
    );
    expect(find.text('Permissão de câmera necessária'), findsOneWidget);
  });
}
