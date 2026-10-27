import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vozguia/main.dart';
import 'package:vozguia/screens/aviso_screen.dart';

void main() {
  testWidgets('Tela de sem permissão mostra a explicação e os botões', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: SemPermissaoScreen(onTentarDeNovo: () {})),
    );
    expect(find.text('Permissão de câmera necessária'), findsOneWidget);
    expect(find.text('Permitir câmera'), findsOneWidget);
    expect(find.text('Abrir configurações'), findsOneWidget);
  });

  testWidgets('Aviso de segurança chama onAceitar ao tocar no botão', (tester) async {
    var aceitou = false;
    await tester.pumpWidget(
      MaterialApp(home: AvisoScreen(onAceitar: () => aceitou = true)),
    );
    expect(find.textContaining('não substitui a bengala'), findsOneWidget);
    await tester.tap(find.text('Entendi, começar'));
    expect(aceitou, isTrue);
  });
}
