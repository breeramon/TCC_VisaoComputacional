import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vozguia/config/configuracoes.dart';

void main() {
  test('padrões quando não há nada salvo', () async {
    SharedPreferences.setMockInitialValues({});
    final c = await Configuracoes.carregar();
    expect(c.velocidadeFala, 0.5);
    expect(c.vibracao, isTrue);
    expect(c.anunciarPosicao, isTrue);
  });

  test('salva e carrega de volta', () async {
    SharedPreferences.setMockInitialValues({});
    await const Configuracoes(
      velocidadeFala: 0.7,
      vibracao: false,
      anunciarSinalizacao: false,
    ).salvar();
    final c = await Configuracoes.carregar();
    expect(c.velocidadeFala, 0.7);
    expect(c.vibracao, isFalse);
    expect(c.anunciarSinalizacao, isFalse);
    expect(c.anunciarEquipamentos, isTrue);
  });

  test('obstáculos são sempre anunciados', () {
    const c = Configuracoes(
        anunciarSinalizacao: false, anunciarEquipamentos: false);
    expect(c.anuncia('person'), isTrue);
    expect(c.anuncia('door'), isTrue);
    expect(c.anuncia('exit sign'), isFalse);
    expect(c.anuncia('handle'), isFalse);
  });
}
