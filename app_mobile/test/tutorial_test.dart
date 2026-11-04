import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vozguia/screens/tutorial_screen.dart';

void main() {
  // Com navegação acessível (TalkBack) o tutorial não usa a voz do app,
  // então o teste não depende do plugin de TTS.
  Widget comTalkBack(Widget filho) => MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: MaterialApp(home: filho),
      );

  testWidgets('mostra todos os passos', (tester) async {
    await tester.pumpWidget(comTalkBack(TutorialScreen(onConcluir: () {})));
    expect(find.text('Como usar o VozGuia'), findsOneWidget);
    for (final passo in passosTutorial) {
      expect(find.text(passo), findsOneWidget);
    }
  });

  testWidgets('botão Começar conclui o tutorial uma vez só', (tester) async {
    var vezes = 0;
    await tester.pumpWidget(
      comTalkBack(TutorialScreen(onConcluir: () => vezes++)),
    );
    await tester.tap(find.text('Começar'));
    await tester.pump();
    await tester.tap(find.text('Começar'));
    await tester.pump();
    expect(vezes, 1);
  });
}
