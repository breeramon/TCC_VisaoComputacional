import 'package:flutter_test/flutter_test.dart';
import 'package:vozguia/tts/tts_service.dart';

void main() {
  group('nivelProximidade', () {
    test('pessoa: longe, próxima e muito próxima', () {
      expect(TtsService.nivelProximidade('person', 0.05), 0);
      expect(TtsService.nivelProximidade('person', 0.20), 1);
      expect(TtsService.nivelProximidade('person', 0.40), 2);
    });

    test('porta grande no quadro ainda não é "próxima"', () {
      expect(TtsService.nivelProximidade('door', 0.25), 0);
      expect(TtsService.nivelProximidade('door', 0.40), 1);
      expect(TtsService.nivelProximidade('door', 0.70), 2);
    });

    test('placa nunca vira alerta urgente', () {
      expect(TtsService.nivelProximidade('exit sign', 0.01), 0);
      expect(TtsService.nivelProximidade('exit sign', 0.05), 1);
      expect(TtsService.nivelProximidade('exit sign', 0.90), 1);
    });

    test('classe desconhecida usa o limiar padrão', () {
      expect(TtsService.nivelProximidade('xyz', 0.10), 0);
      expect(TtsService.nivelProximidade('xyz', 0.20), 1);
      expect(TtsService.nivelProximidade('xyz', 0.35), 2);
    });
  });
}
