/// Atividades de movimento e o que elas liberam. Lógica pura (testada em test/).
library;

enum TipoAtividade { passos, guiada }

class Etapa {
  final String emoji, nome, dica;
  final int segundos;
  const Etapa(this.emoji, this.nome, this.dica, this.segundos);
}

class Atividade {
  final String id, emoji, nome, descricao;
  final TipoAtividade tipo;

  /// Para atividades de passos: meta de passos e, se o celular não tiver
  /// contador de passos, meta em minutos.
  final int metaPassos, metaMinutosSemSensor;
  final List<Etapa> etapas;

  const Atividade({
    required this.id,
    required this.emoji,
    required this.nome,
    required this.descricao,
    required this.tipo,
    this.metaPassos = 0,
    this.metaMinutosSemSensor = 0,
    this.etapas = const [],
  });

  int get duracaoGuiada => etapas.fold(0, (s, e) => s + e.segundos);
}

const atividades = <Atividade>[
  Atividade(
    id: 'caminhada',
    emoji: '🚶',
    nome: 'Caminhada',
    descricao: '1.500 passos no seu ritmo (uns 15 minutos). Pode guardar o celular no bolso.',
    tipo: TipoAtividade.passos,
    metaPassos: 1500,
    metaMinutosSemSensor: 15,
  ),
  Atividade(
    id: 'corrida',
    emoji: '🏃',
    nome: 'Corrida leve',
    descricao: '3.000 passos, alternando trote e caminhada. Respeite seu corpo.',
    tipo: TipoAtividade.passos,
    metaPassos: 3000,
    metaMinutosSemSensor: 20,
  ),
  Atividade(
    id: 'alongamento',
    emoji: '🧘',
    nome: 'Alongamento',
    descricao: '6 posições guiadas, 3 minutos. Ótimo para soltar a tensão.',
    tipo: TipoAtividade.guiada,
    etapas: [
      Etapa('🙆', 'Braços para o alto', 'Entrelace os dedos e estique para cima. Respire fundo.', 30),
      Etapa('🙇', 'Pescoço', 'Incline a cabeça devagar para um lado, depois para o outro.', 30),
      Etapa('🤸', 'Lateral do tronco', 'Braço por cima da cabeça, incline para o lado oposto. Troque.', 30),
      Etapa('🧎', 'Coxa da frente', 'Em pé, segure um pé atrás (apoie numa parede). Troque.', 30),
      Etapa('🙇', 'Costas e pernas', 'Pernas levemente dobradas, desça as mãos em direção aos pés.', 30),
      Etapa('🧘', 'Respiração final', 'Ombros soltos. Inspire em 4, solte em 6.', 30),
    ],
  ),
  Atividade(
    id: 'treino',
    emoji: '💪',
    nome: 'Treino leve',
    descricao: '5 minutos de exercícios simples, sem equipamento, com descansos.',
    tipo: TipoAtividade.guiada,
    etapas: [
      Etapa('🚶', 'Aquecimento', 'Marche no lugar balançando os braços.', 40),
      Etapa('⭐', 'Polichinelos', 'No seu ritmo. Se preferir, sem pular: abra braços e pernas.', 30),
      Etapa('💨', 'Descanso', 'Respire e beba água.', 20),
      Etapa('🪑', 'Agachamento', 'Como se fosse sentar numa cadeira. Costas retas.', 30),
      Etapa('💨', 'Descanso', 'Solte os ombros.', 20),
      Etapa('🦵', 'Joelhos ao peito', 'Eleve um joelho de cada vez, alternando.', 30),
      Etapa('💨', 'Descanso', 'Respire fundo.', 20),
      Etapa('🧱', 'Prancha na parede', 'Mãos na parede, corpo reto. Segure.', 30),
      Etapa('🧘', 'Volta à calma', 'Caminhe devagar e respire. Você conseguiu!', 40),
    ],
  ),
];

// ---------------- Recompensas: jogos liberados por movimento ----------------
class Desbloqueio {
  final String jogoId;
  final int atividadesNecessarias;
  const Desbloqueio(this.jogoId, this.atividadesNecessarias);
}

/// Quantas atividades de movimento concluídas liberam cada jogo relaxante.
const desbloqueios = <Desbloqueio>[
  Desbloqueio('jardim', 1),
  Desbloqueio('mandala', 3),
  Desbloqueio('aquario', 5),
];

int atividadesParaLiberar(String jogoId) =>
    desbloqueios.where((d) => d.jogoId == jogoId).map((d) => d.atividadesNecessarias).firstOrNull ?? 0;

bool jogoLiberado(String jogoId, int atividadesConcluidas) =>
    atividadesConcluidas >= atividadesParaLiberar(jogoId);

/// Jogos que passaram a ficar liberados ao ir de [antes] para [depois] atividades.
List<String> novosDesbloqueios(int antes, int depois) => [
      for (final d in desbloqueios)
        if (antes < d.atividadesNecessarias && depois >= d.atividadesNecessarias) d.jogoId,
    ];

// ---------------- Contador de passos ----------------
/// O sensor do Android informa o total de passos desde que o celular ligou.
/// Este contador guarda o primeiro valor da sessão e calcula a diferença.
class ContadorPassos {
  int? _base;
  int passos = 0;

  void novoValor(int totalDoSensor) {
    _base ??= totalDoSensor;
    if (totalDoSensor < _base!) _base = totalDoSensor; // celular reiniciou
    passos = totalDoSensor - _base!;
  }

  double progresso(int meta) => meta <= 0 ? 0 : (passos / meta).clamp(0.0, 1.0);

  /// Distância aproximada (passo médio de 0,75 m).
  double get km => passos * 0.75 / 1000;
}

// ---------------- Roteiro guiado ----------------
class PosicaoRoteiro {
  final int etapa;
  final int restante;
  final bool terminou;
  const PosicaoRoteiro(this.etapa, this.restante, this.terminou);
}

/// Em qual etapa o roteiro está depois de [segundos] decorridos.
PosicaoRoteiro posicaoNoRoteiro(List<Etapa> etapas, int segundos) {
  var t = segundos;
  for (var i = 0; i < etapas.length; i++) {
    if (t < etapas[i].segundos) return PosicaoRoteiro(i, etapas[i].segundos - t, false);
    t -= etapas[i].segundos;
  }
  return PosicaoRoteiro(etapas.length - 1, 0, true);
}
