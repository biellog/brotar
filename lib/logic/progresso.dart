import 'dart:math';

/// Níveis: XP necessário para o nível n = 50 * n * (n - 1)
class Nivel {
  final int numero;
  final String titulo;
  final int xpInicioNivel;
  final int xpProximoNivel;
  final int xp;
  const Nivel(this.numero, this.titulo, this.xpInicioNivel, this.xpProximoNivel, this.xp);

  double get progresso =>
      ((xp - xpInicioNivel) / (xpProximoNivel - xpInicioNivel)).clamp(0.0, 1.0);
  int get faltam => max(0, xpProximoNivel - xp);
}

const _titulos = [
  'Semente',
  'Broto',
  'Raiz Firme',
  'Tronco Forte',
  'Árvore',
  'Guardião',
  'Mestre da Calma',
  'Inabalável',
  'Lenda Sóbria',
];

int _xpParaNivel(int n) => 50 * n * (n - 1);

Nivel nivelDe(int xp) {
  var n = 1;
  while (xp >= _xpParaNivel(n + 1)) {
    n++;
  }
  final titulo = _titulos[min(n - 1, _titulos.length - 1)];
  return Nivel(n, titulo, _xpParaNivel(n), _xpParaNivel(n + 1), xp);
}

Duration tempoSobrio(DateTime inicio) {
  final d = DateTime.now().difference(inicio);
  return d.isNegative ? Duration.zero : d;
}

String dinheiro(num v) {
  final s = v.toStringAsFixed(2).split('.');
  final inteiro = s[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return 'R\$ $inteiro,${s[1]}';
}

// ---------------- Conquistas ----------------
class Contexto {
  final int dias;
  final int recorde;
  final int partidas;
  final int fissurasVencidas;
  final bool convidou;
  const Contexto({
    required this.dias,
    required this.recorde,
    required this.partidas,
    required this.fissurasVencidas,
    required this.convidou,
  });
}

class Conquista {
  final String codigo;
  final String emoji;
  final String titulo;
  final String descricao;
  final bool Function(Contexto c) regra;
  const Conquista(this.codigo, this.emoji, this.titulo, this.descricao, this.regra);
}

final conquistasLista = <Conquista>[
  Conquista('dia1', '🌱', 'Primeiro Passo', '24 horas sóbrio', (c) => c.dias >= 1),
  Conquista('dia3', '🔥', 'Três Dias', '72 horas de força', (c) => c.dias >= 3),
  Conquista('dia7', '🛡️', 'Uma Semana', '7 dias sóbrio', (c) => c.dias >= 7),
  Conquista('dia14', '⚡', 'Duas Semanas', '14 dias sóbrio', (c) => c.dias >= 14),
  Conquista('dia30', '🏅', 'Um Mês', '30 dias sóbrio', (c) => c.dias >= 30),
  Conquista('dia60', '💎', 'Dois Meses', '60 dias sóbrio', (c) => c.dias >= 60),
  Conquista('dia90', '🏆', 'Noventa Dias', 'O marco dos 90 dias', (c) => c.dias >= 90),
  Conquista('dia180', '🌳', 'Meio Ano', '180 dias sóbrio', (c) => c.dias >= 180),
  Conquista('dia365', '👑', 'Um Ano!', '365 dias de vitória', (c) => c.dias >= 365),
  Conquista('jogo1', '🎮', 'Jogador', 'Jogou o primeiro jogo', (c) => c.partidas >= 1),
  Conquista('pontos500', '⭐', 'Reflexo de Aço', '500 pontos em um jogo', (c) => c.recorde >= 500),
  Conquista('pontos1500', '🌟', 'Imparável', '1500 pontos em um jogo', (c) => c.recorde >= 1500),
  Conquista('sos1', '🌊', 'Surfou a Onda', 'Venceu uma fissura', (c) => c.fissurasVencidas >= 1),
  Conquista('sos10', '🧘', 'Mente Blindada', 'Venceu 10 fissuras', (c) => c.fissurasVencidas >= 10),
  Conquista('convite', '🤝', 'Corrente do Bem', 'Entrou com um convite', (c) => c.convidou),
];

// ---------------- Frases do dia ----------------
const frases = [
  'Só por hoje. Amanhã a gente vê amanhã.',
  'A fissura é uma onda: ela sobe, chega no pico e passa.',
  'Você não precisa ser perfeito, só precisa continuar.',
  'Cada "não" de hoje é um "sim" para a sua vida.',
  'Recomeçar não é fracassar. É coragem.',
  'O seu futuro agradece a escolha de agora.',
  'Beba água, respire fundo, mande mensagem para alguém.',
  'Dias difíceis também contam. Principalmente eles.',
  'Você já venceu 100% dos seus piores dias até aqui.',
  'Pedir ajuda é sinal de força.',
  'Durma bem: o cansaço disfarça de vontade.',
  'Tédio é gatilho. Mexa o corpo por 10 minutos.',
  'Celebre pequenas vitórias. Elas viram grandes.',
  'Quem cuida de você hoje é você.',
  'A clareza da manhã vale mais que a noite de ontem.',
];

String fraseDoDia() {
  final agora = DateTime.now();
  final diaDoAno = agora.difference(DateTime(agora.year)).inDays;
  return frases[diaDoAno % frases.length];
}

// ---------------- Painel "quanto o vício custa" ----------------
const diasPorMes = 30.4375; // média (365,25 / 12)

class Projecao {
  final String rotulo;
  final int meses;
  final double total;
  const Projecao(this.rotulo, this.meses, this.total);
}

/// Quanto se gasta (ou se economiza, parando) em cada período.
List<Projecao> projecoesGasto(double mensal) => [
      for (final (rotulo, meses) in const [
        ('1 mês', 1),
        ('5 meses', 5),
        ('1 ano', 12),
        ('5 anos', 60),
        ('10 anos', 120),
      ])
        Projecao(rotulo, meses, mensal * meses),
    ];

/// Guardando [mensal] todo mês com rendimento de [taxa] ao mês (juros compostos).
double comRendimento(double mensal, int meses, {double taxa = 0.006}) =>
    taxa == 0 ? mensal * meses : mensal * ((pow(1 + taxa, meses) - 1) / taxa);

const _sonhos = [
  (150.0, 'um tênis novo 👟'),
  (600.0, 'um fim de semana na praia 🏖️'),
  (2000.0, 'um celular novo 📱'),
  (5000.0, 'uma viagem de avião ✈️'),
  (15000.0, 'uma moto 🏍️'),
  (45000.0, 'um carro 🚗'),
  (120000.0, 'a entrada de uma casa 🏠'),
];

/// O maior "sonho" que cabe no valor (ou null se não cabe nenhum).
String? oQueDaPraComprar(double valor) {
  String? melhor;
  for (final (preco, sonho) in _sonhos) {
    if (valor >= preco) melhor = sonho;
  }
  return melhor;
}
