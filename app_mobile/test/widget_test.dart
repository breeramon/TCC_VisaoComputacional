import 'package:flutter_test/flutter_test.dart';
import 'package:nav_indoor_tcc/main.dart';

void main() {
  testWidgets('Mostra tela de sem permissão quando câmera negada', (tester) async {
    await tester.pumpWidget(
      const NavIndoorApp(cameraPermitida: false),
    );
    expect(find.text('Permissão de câmera necessária'), findsOneWidget);
  });
}
