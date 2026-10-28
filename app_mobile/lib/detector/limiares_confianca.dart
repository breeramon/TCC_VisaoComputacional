/// Confiança mínima para anunciar cada classe.
///
/// Obstáculos usam limiares mais baixos: deixar de avisar uma pessoa ou uma
/// cadeira no caminho é pior que um aviso falso (que o buffer de confirmação
/// temporal do TtsService já ajuda a filtrar). Placas e referências usam
/// limiares mais altos, porque um aviso errado só atrapalha.
///
/// Valores iniciais — calibrar com testes no celular.
const Map<String, double> limiaresConfianca = {
  // Obstáculos
  'person': 0.40,
  'Chair': 0.45,
  'table': 0.45,
  'trash can': 0.45,
  'water dispenser': 0.50,
  'door': 0.50,
  'elevator': 0.55,
  // Referências
  'fire extinguisher': 0.60,
  'elevator sign': 0.60,
  'stair sign': 0.60,
  'exit sign': 0.60,
  'acessibility': 0.60,
  'men washroom': 0.60,
  'women washrooom': 0.60,
  'handle': 0.60,
  'push handle': 0.60,
  'fire alarm': 0.65,
};

/// Limiar para classes que não estão na tabela.
const double limiarConfiancaPadrao = 0.60;

/// Menor limiar da tabela. O modelo nativo filtra por este valor, e o app
/// aplica o limiar de cada classe depois.
final double limiarConfiancaMinimo = limiaresConfianca.values.fold(
  limiarConfiancaPadrao,
  (a, b) => a < b ? a : b,
);

/// Se a detecção tem confiança suficiente para a sua classe.
bool passaConfianca(String classe, double confianca) =>
    confianca >= (limiaresConfianca[classe] ?? limiarConfiancaPadrao);
