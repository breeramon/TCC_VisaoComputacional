import 'package:flutter_test/flutter_test.dart';
import 'package:vozguia/detector/limiares_confianca.dart';

void main() {
  group('passaConfianca', () {
    test('pessoa é aceita com confiança mais baixa que placa', () {
      expect(passaConfianca('person', 0.45), isTrue);
      expect(passaConfianca('exit sign', 0.45), isFalse);
    });

    test('limiar exato é aceito', () {
      expect(passaConfianca('door', 0.50), isTrue);
      expect(passaConfianca('door', 0.49), isFalse);
    });

    test('classe desconhecida usa o limiar padrão', () {
      expect(passaConfianca('xyz', limiarConfiancaPadrao), isTrue);
      expect(passaConfianca('xyz', limiarConfiancaPadrao - 0.01), isFalse);
    });

    test('limiar mínimo é o menor da tabela', () {
      expect(limiarConfiancaMinimo, 0.40);
    });
  });
}
