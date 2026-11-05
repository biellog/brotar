/// 🧃 Império do Suco 3D: mundo aberto (lógica pura, sem Flutter, testada em test/).
///
/// Você anda pela praça, pega os copos nas barracas (no fundo), leva até o balcão
/// e vende. Placas na frente das barracas abrem e melhoram. No escritório, o boneco
/// senta no computador para comprar boosts, melhorias da empresa, equipe e habilidades.
library;

import 'dart:math';

const larguraMapa = 16.0;
const alturaMapa = 16.0;

class Suco {
  final String nome, emoji;
  final int cor;
  final double custoAbrir, preco, tempo;
  const Suco(this.nome, this.emoji, this.cor, this.custoAbrir, this.preco, this.tempo);
}

const sucos = <Suco>[
  Suco('Limonada', '🍋', 0xFFF4D03F, 0, 3, 1.5),
  Suco('Laranja', '🍊', 0xFFFF8C1A, 40, 8, 2.0),
  Suco('Morango', '🍓', 0xFFFF4D6D, 250, 20, 2.6),
  Suco('Coco', '🥥', 0xFFB08968, 1200, 45, 3.2),
  Suco('Manga', '🥭', 0xFFFFB627, 6000, 100, 3.8),
  Suco('Uva', '🍇', 0xFF9D4EDD, 30000, 220, 4.4),
  Suco('Melancia', '🍉', 0xFF52B788, 150000, 480, 5.0),
  Suco('Abacaxi', '🍍', 0xFFE9C46A, 700000, 1000, 5.6),
];

/// Barracas encostadas no FUNDO da praça (lado esquerdo do mapa), uma do lado da outra.
const xBarracas = 1.8;
const posicoesBarracas = <(double, double)>[
  (xBarracas, 3.9),
  (xBarracas, 5.5),
  (xBarracas, 7.1),
  (xBarracas, 8.7),
  (xBarracas, 10.3),
  (xBarracas, 11.9),
  (xBarracas, 13.5),
  (xBarracas, 15.1),
];

/// A placa de cada barraca fica NA FRENTE dela (nunca no lugar da barraca).
const xPlacas = 3.9;

/// Balcão onde os clientes são atendidos.
const balcao = (x: 6.0, y: 4.0, w: 5.4, d: 0.8);
const ruaY = 1.6;
const vagasBase = <(double, double)>[(6.6, 3.4), (8.0, 3.4), (9.4, 3.4), (10.8, 3.4)];

/// Escritório da gerência (computador) e fonte da praça.
const mesa = (x: 12.7, y: 11.9, w: 0.9, d: 1.8);
const cadeira = (x: 12.1, y: 12.8);
const fonte = (x: 8.2, y: 8.6, w: 1.6, d: 1.6);

class Barraca {
  final int indice;
  bool aberta = false;
  int nivel = 1;
  int estoque = 0;
  double progresso = 0;
  Barraca(this.indice);

  Suco get suco => sucos[indice];
  double get x => posicoesBarracas[indice].$1;
  double get y => posicoesBarracas[indice].$2;
  int get capacidadeBase => 4 + nivel * 2;
  double get tempoBase => suco.tempo / (1 + 0.25 * (nivel - 1));
  double get precoBase => suco.preco * (1 + 0.35 * (nivel - 1));
  double get custoMelhorar => suco.preco * 25 * pow(1.6, nivel - 1);
}

enum TipoPlaca { abrir, melhorar }

class Placa {
  final TipoPlaca tipo;
  final int alvo;
  final double x, y;
  double pago = 0;
  Placa(this.tipo, this.alvo, this.x, this.y);
  String get id => '${tipo.name}:$alvo';
}

// ---------------- Habilidades (pontos ganhos nas missões) ----------------
enum Habilidade {
  agilidade('🏃', 'Agilidade', '+10% velocidade'),
  forca('💪', 'Força', '+1 copo carregado'),
  carisma('😊', 'Carisma', '+8% no preço (gorjeta)'),
  barista('🧪', 'Barista', '+12% produção'),
  marketing('📣', 'Marketing', 'mais clientes'),
  lideranca('🧑‍🏫', 'Liderança', 'ajudantes +15% rápidos');

  final String emoji, nome, efeito;
  const Habilidade(this.emoji, this.nome, this.efeito);
}

const maxHabilidade = 5;

// ---------------- Empresa (compras no computador) ----------------
enum Melhoria {
  logo('🎨', 'Logo nova', 'Todos os sucos +10% no preço', 400, 1),
  gelo('🧊', 'Máquina de gelo', 'Barracas guardam +3 copos', 1500, 1),
  uniforme('👕', 'Uniformes', 'Ajudantes 20% mais rápidos', 2500, 1),
  mesas('🪑', 'Mesas na calçada', '+1 vaga de cliente no balcão', 4000, 1),
  delivery('🛵', 'Delivery', 'Vende sozinho por app (por nível)', 3000, 3),
  franquia('🏆', 'Franquia nacional', 'Todos os preços em dobro', 250000, 1);

  final String emoji, nome, descricao;
  final double custoBase;
  final int maxNivel;
  const Melhoria(this.emoji, this.nome, this.descricao, this.custoBase, this.maxNivel);
}

// ---------------- Boosts (temporários, comprados no computador) ----------------
enum Boost {
  turbo('⚡', 'Turbo', 'Você corre 60% mais rápido', 120),
  producao('🏭', 'Produção x2', 'Barracas fazem o dobro', 120),
  promocao('📢', 'Promoção', 'Clientes em dobro e +20% no preço', 90);

  final String emoji, nome, descricao;
  final double duracao;
  const Boost(this.emoji, this.nome, this.descricao, this.duracao);
}

// ---------------- Missões ----------------
enum TipoMissao { copos, faturar, abrir, nivelLimonada, computador, ajudantes, boost, empresa, mochila, cidade }

class Missao {
  final String texto;
  final TipoMissao tipo;
  final double alvo;
  final double premio;
  const Missao(this.texto, this.tipo, this.alvo, this.premio);
}

const missoes = <Missao>[
  Missao('Venda 5 copos', TipoMissao.copos, 5, 15),
  Missao('Abra a barraca de Laranja', TipoMissao.abrir, 2, 30),
  Missao('Venda 25 copos', TipoMissao.copos, 25, 60),
  Missao('Melhore a Limonada (nível 2)', TipoMissao.nivelLimonada, 2, 60),
  Missao('Sente no computador da gerência', TipoMissao.computador, 1, 80),
  Missao('Compre a mochila (no computador)', TipoMissao.mochila, 1, 100),
  Missao('Abra a barraca de Morango', TipoMissao.abrir, 3, 150),
  Missao('Contrate um ajudante', TipoMissao.ajudantes, 1, 200),
  Missao('Use um boost', TipoMissao.boost, 1, 250),
  Missao('Fature R\$ 1.000', TipoMissao.faturar, 1000, 300),
  Missao('Compre uma melhoria da empresa', TipoMissao.empresa, 1, 400),
  Missao('Abra a barraca de Coco', TipoMissao.abrir, 4, 600),
  Missao('Venda 300 copos', TipoMissao.copos, 300, 900),
  Missao('Tenha 2 ajudantes', TipoMissao.ajudantes, 2, 1500),
  Missao('Abra a barraca de Manga', TipoMissao.abrir, 5, 3000),
  Missao('Fature R\$ 25 mil', TipoMissao.faturar, 25000, 5000),
  Missao('Compre 3 melhorias da empresa', TipoMissao.empresa, 3, 8000),
  Missao('Abra a barraca de Uva', TipoMissao.abrir, 6, 15000),
  Missao('Venda 2.000 copos', TipoMissao.copos, 2000, 30000),
  Missao('Abra a barraca de Melancia', TipoMissao.abrir, 7, 60000),
  Missao('Tenha 4 ajudantes', TipoMissao.ajudantes, 4, 90000),
  Missao('Fature R\$ 1 milhão', TipoMissao.faturar, 1e6, 150000),
  Missao('Abra a barraca de Abacaxi', TipoMissao.abrir, 8, 300000),
];

class Pessoa {
  double x, y, vx = 0, vy = 0;
  final carga = <int>[];
  final bool ajudante;
  double pegarEm = 0, entregarEm = 0;
  int? alvoBarraca;
  double parado = 0;
  double andando = 0;
  bool olhandoEsquerda = false;
  String? placaAtual; // em cima de qual placa está
  double naPlaca = 0; // há quanto tempo (só começa a cobrar depois de [esperaPlaca])
  Pessoa(this.x, this.y, {this.ajudante = false});
}

/// Segundos parado em cima da placa antes de começar a cobrar (evita compra sem querer).
const esperaPlaca = 5.0;

/// Agitos: acontecimentos surpresa na praça para o jogo nunca ficar parado.
enum TipoAgito {
  excursao('🚌', 'Excursão chegando!', 'Muitos clientes de uma vez', 22),
  calor('🌞', 'Onda de calor!', 'Todo suco vale +50%', 25),
  vip('👑', 'Cliente VIP!', 'Atenda antes da paciência acabar: paga 5x', 30),
  moedas('🪙', 'Chuva de moedas!', 'Corra pela praça e pegue as moedas', 15),
  fruta('🌟', 'Fruta dourada!', 'Pegue a fruta: enche todas as barracas', 20);

  final String emoji, nome, descricao;
  final double duracao;
  const TipoAgito(this.emoji, this.nome, this.descricao, this.duracao);
}

class MoedaChao {
  final double x, y, valor;
  const MoedaChao(this.x, this.y, this.valor);
}

/// Cidades (recomeçar com bônus permanente).
const nomesCidades = [
  'Praça Central',
  'Vila do Sol',
  'Porto Alegria',
  'Serra Verde',
  'Cidade Nova',
  'Ilha do Coco',
  'Capital do Suco',
];
String nomeCidade(int i) => i < nomesCidades.length ? nomesCidades[i] : 'Cidade ${i + 1}';

/// Outro jogador no mesmo império (modo em grupo).
class Amigo extends Pessoa {
  final String id;
  String nome;
  int cor;
  double alvoX, alvoY;
  bool sentado = false;
  double visto = 0; // segundos desde a última notícia dele
  Amigo(this.id, this.nome, this.cor, double x, double y) : alvoX = x, alvoY = y, super(x, y);
}

const coresAmigos = [0xFF4CC9F0, 0xFFFF6FA5, 0xFF7BD389, 0xFFB98CF0, 0xFF3A86FF, 0xFFF94144];

enum EstadoCliente { chegando, esperando, saindo }

class Cliente {
  int id = 0;
  double x, y;
  double? alvoX, alvoY; // no modo espelho: para onde ele está indo
  final int quer;
  int faltam;
  final int aparencia;
  EstadoCliente estado = EstadoCliente.chegando;
  int vaga = -1;
  double feliz = 0;
  double andando = 0;
  bool vip = false;
  double paciencia = 0; // VIP: segundos até desistir
  Cliente(this.x, this.y, this.quer, this.faltam, this.aparencia);
}

enum TipoEvento { pegou, vendeu, comprou, abriu, contratou, missao, sentou, poeira, combo, agito, moeda, fruta, vip, cidade }

class Evento {
  final TipoEvento tipo;
  final double x, y, valor;
  final int suco;
  final String texto;
  const Evento(this.tipo, this.x, this.y, {this.valor = 0, this.suco = 0, this.texto = ''});
}

class Mundo {
  final Random _rnd;
  double dinheiro = 0;
  double vendidoTotal = 0;
  int copos = 0;
  int nivelMochila = 0, nivelTenis = 0;
  int pontosHabilidade = 0;
  int missao = 0;
  int boostsUsados = 0;
  bool usouComputador = false;
  final habilidades = {for (final h in Habilidade.values) h: 0};
  final melhorias = {for (final m in Melhoria.values) m: 0};
  final boosts = {for (final b in Boost.values) b: 0.0}; // segundos restantes
  final barracas = List.generate(sucos.length, Barraca.new);
  final ajudantes = <Pessoa>[];
  final clientes = <Cliente>[];
  final pagos = <String, double>{};
  late final Pessoa jogador = Pessoa(8.6, 6.4);
  bool sentado = false;
  double _naCadeira = 0;
  double _proximoCliente = 1;
  double _poeira = 0;
  double relogio = 0;

  /// Império em grupo: sem ajudantes (os amigos é que trabalham juntos).
  bool grupo = false;

  /// Espelho: outro celular roda o jogo; este só anda com o próprio boneco e mostra o que chega.
  bool espelho = false;
  final amigos = <String, Amigo>{};
  final _eventosRede = <Evento>[];
  int _idCliente = 0;

  // agito (eventos surpresa), combo e cidades
  TipoAgito? agito;
  double agitoResta = 0;
  double _proximoAgito = 35;
  final moedasChao = <MoedaChao>[];
  (double, double)? fruta;
  int combo = 0;
  double comboTempo = 0;
  int cidades = 0; // quantas vezes recomeçou em uma cidade nova
  static const tempoCombo = 3.0;

  double get multCombo => 1 + min(max(combo - 1, 0), 10) * 0.1; // até x2
  double get bonusCidade => 1 + 0.5 * cidades;
  bool get podeNovaCidade => abertas == sucos.length;

  static const custosAjudante = [150.0, 1500.0, 12000.0, 90000.0];
  static const maxNivelEquip = 5;

  Mundo([Random? rnd]) : _rnd = rnd ?? Random() {
    barracas[0].aberta = true;
  }

  // ---------------- números com habilidades, empresa e boosts ----------------
  int nivel(Habilidade h) => habilidades[h]!;
  int nivelMelhoria(Melhoria m) => melhorias[m]!;
  bool ativo(Boost b) => boosts[b]! > 0;

  int get capacidade => 4 + nivelMochila * 2 + nivel(Habilidade.forca);
  double get velocidade =>
      3.6 * (1 + 0.1 * nivel(Habilidade.agilidade)) * (1 + 0.12 * nivelTenis) * (ativo(Boost.turbo) ? 1.6 : 1);
  double get multPreco =>
      (1 + 0.08 * nivel(Habilidade.carisma)) *
      (nivelMelhoria(Melhoria.logo) > 0 ? 1.1 : 1) *
      (nivelMelhoria(Melhoria.franquia) > 0 ? 2 : 1) *
      (ativo(Boost.promocao) ? 1.2 : 1) *
      (agito == TipoAgito.calor ? 1.5 : 1) *
      bonusCidade;
  double get multProducao => (1 + 0.12 * nivel(Habilidade.barista)) * (ativo(Boost.producao) ? 2 : 1);
  double get velocidadeAjudante =>
      2.6 * (1 + 0.15 * nivel(Habilidade.lideranca)) * (nivelMelhoria(Melhoria.uniforme) > 0 ? 1.2 : 1);
  int capacidadeBarraca(Barraca b) => b.capacidadeBase + (nivelMelhoria(Melhoria.gelo) > 0 ? 3 : 0);
  double tempoBarraca(Barraca b) => b.tempoBase / multProducao;
  double preco(Barraca b) => b.precoBase * multPreco;
  List<(double, double)> get vagas => vagasBase.take(nivelMelhoria(Melhoria.mesas) > 0 ? 4 : 3).toList();
  int get abertas => barracas.where((b) => b.aberta).length;

  /// Valor de referência dos preços (base para o custo dos boosts).
  double get precoMedio {
    final l = barracas.where((b) => b.aberta).toList();
    return l.fold<double>(0, (s, b) => s + preco(b)) / l.length;
  }

  // ---------------- placas (na frente das barracas) ----------------
  List<Placa> get placas {
    final l = <Placa>[];
    final prox = barracas.where((b) => !b.aberta).firstOrNull;
    if (prox != null) l.add(Placa(TipoPlaca.abrir, prox.indice, xPlacas, prox.y));
    for (final b in barracas.where((b) => b.aberta && b.nivel < 10)) {
      l.add(Placa(TipoPlaca.melhorar, b.indice, xPlacas, b.y));
    }
    for (final p in l) {
      p.pago = pagos[p.id] ?? 0;
    }
    return l;
  }

  double custo(Placa p) => p.tipo == TipoPlaca.abrir ? sucos[p.alvo].custoAbrir : barracas[p.alvo].custoMelhorar;

  String rotulo(Placa p) => p.tipo == TipoPlaca.abrir
      ? 'Abrir ${sucos[p.alvo].nome}'
      : 'Melhorar ${sucos[p.alvo].nome} → nv ${barracas[p.alvo].nivel + 1}';

  String icone(Placa p) => p.tipo == TipoPlaca.abrir ? sucos[p.alvo].emoji : '⬆️';

  Evento _aplicarPlaca(Placa p) {
    pagos.remove(p.id);
    if (p.tipo == TipoPlaca.abrir) {
      barracas[p.alvo].aberta = true;
      return Evento(TipoEvento.abriu, p.x, p.y, suco: p.alvo);
    }
    barracas[p.alvo].nivel++;
    return Evento(TipoEvento.comprou, p.x, p.y, texto: '⬆️ ${sucos[p.alvo].nome} nv ${barracas[p.alvo].nivel}');
  }

  // ---------------- computador ----------------
  double custoBoost(Boost b) => max(40, precoMedio * (b == Boost.promocao ? 40 : 30)).roundToDouble();

  bool comprarBoost(Boost b) {
    final c = custoBoost(b);
    if (dinheiro < c) return false;
    dinheiro -= c;
    boosts[b] = boosts[b]! + b.duracao;
    boostsUsados++;
    return true;
  }

  double custoMelhoria(Melhoria m) => m.custoBase * pow(3, nivelMelhoria(m));

  bool comprarMelhoria(Melhoria m) {
    if (nivelMelhoria(m) >= m.maxNivel || dinheiro < custoMelhoria(m)) return false;
    dinheiro -= custoMelhoria(m);
    melhorias[m] = nivelMelhoria(m) + 1;
    return true;
  }

  int get totalMelhorias => melhorias.values.fold(0, (s, v) => s + v);

  int custoHabilidade(Habilidade h) => nivel(h) + 1;

  bool subirHabilidade(Habilidade h) {
    if (nivel(h) >= maxHabilidade || pontosHabilidade < custoHabilidade(h)) return false;
    pontosHabilidade -= custoHabilidade(h);
    habilidades[h] = nivel(h) + 1;
    return true;
  }

  double get custoAjudante => ajudantes.length < custosAjudante.length ? custosAjudante[ajudantes.length] : double.infinity;
  double get custoMochila => 60 * pow(3, nivelMochila).toDouble();
  double get custoTenis => 90 * pow(3, nivelTenis).toDouble();

  bool contratarAjudante() {
    if (grupo || dinheiro < custoAjudante) return false;
    dinheiro -= custoAjudante;
    ajudantes.add(Pessoa(cadeira.x - 1.5, cadeira.y - 1.2, ajudante: true));
    return true;
  }

  bool comprarMochila() {
    if (nivelMochila >= maxNivelEquip || dinheiro < custoMochila) return false;
    dinheiro -= custoMochila;
    nivelMochila++;
    return true;
  }

  bool comprarTenis() {
    if (nivelTenis >= maxNivelEquip || dinheiro < custoTenis) return false;
    dinheiro -= custoTenis;
    nivelTenis++;
    return true;
  }

  /// Uma compra do computador pelo nome (usada também pelos amigos, pela rede).
  bool executar(String tipo, String k) {
    T? achar<T extends Enum>(List<T> l) => l.where((e) => e.name == k).firstOrNull;
    return switch (tipo) {
      'boost' => achar(Boost.values) != null && comprarBoost(achar(Boost.values)!),
      'emp' => achar(Melhoria.values) != null && comprarMelhoria(achar(Melhoria.values)!),
      'hab' => achar(Habilidade.values) != null && subirHabilidade(achar(Habilidade.values)!),
      'ajudante' => contratarAjudante(),
      'mochila' => comprarMochila(),
      'tenis' => comprarTenis(),
      'cidade' => novaCidade(),
      _ => false,
    };
  }

  /// Recomeça numa cidade nova: barracas e dinheiro zeram, mas tudo vale +50% (para sempre).
  /// Habilidades, melhorias da empresa, equipamentos e missões continuam.
  bool novaCidade() {
    if (!podeNovaCidade) return false;
    cidades++;
    dinheiro = 0;
    pagos.clear();
    clientes.clear();
    moedasChao.clear();
    fruta = null;
    agito = null;
    for (final b in barracas) {
      b
        ..aberta = b.indice == 0
        ..nivel = 1
        ..estoque = 0
        ..progresso = 0;
    }
    for (final a in [jogador, ...ajudantes]) {
      a.carga.clear();
    }
    return true;
  }

  /// Sai da cadeira (fecha o computador) e dá um passinho para fora dela.
  void levantar() {
    sentado = false;
    _naCadeira = -1.5; // não senta de novo logo em seguida
    jogador.x = cadeira.x - 0.8;
  }

  // ---------------- missões ----------------
  /// Depois das missões fixas vêm missões sem fim (vender, faturar, cidade nova...).
  Missao? get missaoAtual {
    if (missao < missoes.length) return missoes[missao];
    final k = missao - missoes.length;
    final premio = (precoMedio * 150 * (1 + k * 0.2)).roundToDouble();
    final r = k ~/ 3 + 1;
    return switch (k % 3) {
      0 => Missao('Venda ${2000 + r * 1500} copos', TipoMissao.copos, 2000.0 + r * 1500, premio),
      1 => Missao('Fature ${reais3d(1e6 * pow(4, r))}', TipoMissao.faturar, 1e6 * pow(4, r).toDouble(), premio),
      _ => Missao('Abra uma cidade nova ($rª)', TipoMissao.cidade, r.toDouble(), premio),
    };
  }

  double valorMissao(Missao m) => switch (m.tipo) {
    TipoMissao.copos => copos.toDouble(),
    TipoMissao.faturar => vendidoTotal,
    TipoMissao.abrir => abertas.toDouble(),
    TipoMissao.nivelLimonada => barracas[0].nivel.toDouble(),
    TipoMissao.computador => usouComputador ? 1 : 0,
    TipoMissao.ajudantes => ajudantes.length.toDouble(),
    TipoMissao.boost => boostsUsados.toDouble(),
    TipoMissao.empresa => totalMelhorias.toDouble(),
    TipoMissao.mochila => nivelMochila.toDouble(),
    TipoMissao.cidade => cidades.toDouble(),
  };

  double get progressoMissao {
    final m = missaoAtual;
    return m == null ? 1 : (valorMissao(m) / m.alvo).clamp(0.0, 1.0);
  }

  Evento? _checarMissao() {
    final m = missaoAtual;
    if (m == null) return null;
    if (grupo && m.tipo == TipoMissao.ajudantes) {
      missao++; // em grupo não tem ajudante: pula essa missão
      return null;
    }
    if (valorMissao(m) < m.alvo) return null;
    missao++;
    dinheiro += m.premio;
    pontosHabilidade++;
    return Evento(TipoEvento.missao, jogador.x, jogador.y, valor: m.premio, texto: m.texto);
  }

  // ---------------- colisão ----------------
  List<(double, double, double, double)> get _solidos => [
    for (final b in barracas.where((b) => b.aberta)) (b.x - 0.7, b.y - 0.7, 1.4, 1.4),
    (balcao.x, balcao.y, balcao.w, balcao.d),
    (mesa.x, mesa.y, mesa.w, mesa.d),
    (fonte.x, fonte.y, fonte.w, fonte.d),
  ];

  bool _bate(double x, double y) {
    const r = 0.28;
    return _solidos.any((s) => x + r > s.$1 && x - r < s.$1 + s.$3 && y + r > s.$2 && y - r < s.$2 + s.$4);
  }

  void _moverCom(Pessoa p, double dx, double dy) {
    // se por algum motivo ficou dentro de algo sólido, deixa sair livremente (nunca trava)
    final preso = _bate(p.x, p.y);
    final nx = (p.x + dx).clamp(0.5, larguraMapa - 0.5);
    if (preso || !_bate(nx, p.y)) p.x = nx;
    final ny = (p.y + dy).clamp(2.6, alturaMapa - 0.5);
    if (preso || !_bate(p.x, ny)) p.y = ny;
  }

  // ---------------- passo ----------------
  List<Evento> passo(double dt, double dirX, double dirY) {
    relogio += dt;
    final eventos = <Evento>[];
    for (final b in Boost.values) {
      boosts[b] = max(0, boosts[b]! - dt);
    }
    if (!sentado) _moverJogador(dt, dirX, dirY, eventos);
    _moverAmigos(dt);
    if (espelho) {
      if (!sentado) _contarPlaca(jogador, dt);
      _cadeira(dt, eventos);
      _moverClientesEspelho(dt);
      return eventos;
    }
    for (final b in barracas.where((b) => b.aberta && b.estoque < capacidadeBarraca(b))) {
      b.progresso += dt / tempoBarraca(b);
      if (b.progresso >= 1) {
        b.progresso = 0;
        b.estoque++;
      }
    }
    for (final a in ajudantes) {
      _pensarAjudante(a, dt);
    }
    final andando = [if (!sentado) jogador, ...amigos.values.where((a) => !a.sentado)];
    for (final p in [...andando, ...ajudantes]) {
      eventos.addAll(_pegar(p, dt));
      eventos.addAll(_entregar(p, dt));
    }
    for (final p in andando) {
      _placas(p, dt, eventos);
    }
    comboTempo = max(0, comboTempo - dt);
    if (comboTempo <= 0) combo = 0;
    _agitos(dt, andando, eventos);
    if (amigos.values.any((a) => a.sentado)) usouComputador = true;
    _cadeira(dt, eventos);
    // delivery: vende sozinho pelo app
    final d = nivelMelhoria(Melhoria.delivery);
    if (d > 0) {
      final v = d * 0.15 * precoMedio * dt;
      dinheiro += v;
      vendidoTotal += v;
    }
    _clientes(dt);
    final m = _checarMissao();
    if (m != null) eventos.add(m);
    if (amigos.isNotEmpty) {
      for (final e in eventos) {
        if (e.tipo != TipoEvento.poeira &&
            e.tipo != TipoEvento.sentou &&
            e.tipo != TipoEvento.pegou &&
            _eventosRede.length < 30) {
          _eventosRede.add(e);
        }
      }
    }
    return eventos;
  }

  // ---------------- agitos ----------------
  void _agitos(double dt, List<Pessoa> andando, List<Evento> eventos) {
    // moedas e fruta dourada: quem passar por cima pega
    for (final p in andando) {
      for (final mo in moedasChao.where((mo) => (mo.x - p.x).abs() < 0.5 && (mo.y - p.y).abs() < 0.5).toList()) {
        moedasChao.remove(mo);
        dinheiro += mo.valor;
        vendidoTotal += mo.valor;
        eventos.add(Evento(TipoEvento.moeda, mo.x, mo.y, valor: mo.valor));
      }
      final f = fruta;
      if (f != null && (f.$1 - p.x).abs() < 0.6 && (f.$2 - p.y).abs() < 0.6) {
        fruta = null;
        for (final b in barracas.where((b) => b.aberta)) {
          b.estoque = capacidadeBarraca(b);
        }
        boosts[Boost.producao] = boosts[Boost.producao]! + 20;
        agitoResta = 0;
        eventos.add(Evento(TipoEvento.fruta, f.$1, f.$2, texto: '🌟 Barracas cheias + produção x2!'));
      }
    }
    if (agito != null) {
      agitoResta -= dt;
      final vipAinda = clientes.any((c) => c.vip && c.estado != EstadoCliente.saindo);
      if (agitoResta <= 0 || (agito == TipoAgito.vip && !vipAinda) || (agito == TipoAgito.moedas && moedasChao.isEmpty)) {
        agito = null;
        moedasChao.clear();
        fruta = null;
        _proximoAgito = 40 + _rnd.nextDouble() * 30;
      }
      return;
    }
    _proximoAgito -= dt;
    if (_proximoAgito > 0 || copos < 5) return;
    final opcoes = [TipoAgito.excursao, TipoAgito.calor, TipoAgito.moedas, TipoAgito.fruta, if (abertas >= 2) TipoAgito.vip];
    comecarAgito(opcoes[_rnd.nextInt(opcoes.length)], eventos);
  }

  void comecarAgito(TipoAgito t, List<Evento> eventos) {
    agito = t;
    agitoResta = t.duracao;
    moedasChao.clear();
    fruta = null;
    switch (t) {
      case TipoAgito.moedas:
        for (var k = 0; k < 14; k++) {
          final (x, y) = _lugarLivre();
          moedasChao.add(MoedaChao(x, y, (precoMedio * 2).ceilToDouble()));
        }
      case TipoAgito.fruta:
        fruta = _lugarLivre();
      case TipoAgito.vip:
        final melhor = barracas.where((b) => b.aberta).last.indice;
        clientes.add(
          Cliente(larguraMapa + 0.5, ruaY, melhor, 3, _rnd.nextInt(8))
            ..id = ++_idCliente
            ..vip = true
            ..paciencia = t.duracao,
        );
      case TipoAgito.excursao:
      case TipoAgito.calor:
        break;
    }
    eventos.add(Evento(TipoEvento.agito, jogador.x, jogador.y, suco: t.index, texto: '${t.emoji} ${t.nome}'));
  }

  (double, double) _lugarLivre() {
    for (var k = 0; k < 40; k++) {
      final x = 4.6 + _rnd.nextDouble() * 9.6, y = 5.6 + _rnd.nextDouble() * 9;
      if (!_bate(x, y)) return (x, y);
    }
    return (8.6, 7.0);
  }

  void _moverAmigos(double dt) {
    for (final a in amigos.values) {
      a.visto += dt;
      final dx = a.alvoX - a.x, dy = a.alvoY - a.y;
      final d = sqrt(dx * dx + dy * dy);
      if (d > 3) {
        a
          ..x = a.alvoX
          ..y = a.alvoY;
      } else {
        final k = min(1.0, dt * 10);
        a
          ..x += dx * k
          ..y += dy * k;
      }
      if (d > 0.04) {
        a.andando += dt;
        if ((dx - dy).abs() > 0.05) a.olhandoEsquerda = (dx - dy) < 0;
      } else {
        a.andando = 0;
      }
    }
  }

  void _moverClientesEspelho(double dt) {
    for (final c in clientes) {
      final tx = c.alvoX ?? c.x, ty = c.alvoY ?? c.y;
      final dx = tx - c.x, dy = ty - c.y;
      final d = sqrt(dx * dx + dy * dy);
      final passo = min(d, 2.6 * dt);
      if (d > 0.02) {
        c
          ..x += dx / d * passo
          ..y += dy / d * passo
          ..andando += dt;
      } else {
        c.andando = 0;
      }
      if (c.feliz > 0) c.feliz = max(0, c.feliz - dt);
    }
  }

  // ---------------- modo em grupo (rede) ----------------
  /// Notícia de um amigo (posição que o celular dele mandou). Dados de fora: tudo validado.
  void atualizarAmigo(String id, Map<String, dynamic> d) {
    if (id.isEmpty || id.length > 40) return;
    final x = d['x'], y = d['y'];
    if (x is! num || y is! num || !x.isFinite || !y.isFinite) return;
    final a =
        amigos[id] ??
        (amigos.length >= 7
            ? null
            : Amigo(id, 'Amigo', coresAmigos[amigos.length % coresAmigos.length], x.toDouble(), y.toDouble()));
    if (a == null) return;
    amigos[id] = a;
    a
      ..alvoX = x.toDouble().clamp(0.5, larguraMapa - 0.5)
      ..alvoY = y.toDouble().clamp(2.6, alturaMapa - 0.5)
      ..sentado = d['s'] == true
      ..visto = 0;
    final n = d['n'];
    if (n is String && n.trim().isNotEmpty) a.nome = n.trim().length > 16 ? n.trim().substring(0, 16) : n.trim();
    final c = d['o'];
    if (c is int && coresAmigos.contains(c)) a.cor = c;
  }

  void removerAmigo(String id) => amigos.remove(id);

  /// Foto do jogo inteiro para os amigos (o celular que roda o jogo manda ~4x por segundo).
  Map<String, dynamic> estadoAoVivo(String meuId, String meuNome, int minhaCor) {
    double r(double v) => (v * 100).roundToDouble() / 100;
    final ev = [
      for (final e in _eventosRede) [e.tipo.index, r(e.x), r(e.y), r(e.valor), e.suco, e.texto],
    ];
    _eventosRede.clear();
    return {
      'e': paraJson(DateTime.now()),
      'cl': [
        for (final c in clientes)
          [c.id, r(c.x), r(c.y), c.quer, c.faltam, c.aparencia, c.estado.index, r(c.feliz), c.vip ? 1 : 0, r(c.paciencia)],
      ],
      'js': {
        meuId: {'x': r(jogador.x), 'y': r(jogador.y), 'c': jogador.carga, 's': sentado, 'n': meuNome, 'o': minhaCor},
        for (final a in amigos.values)
          a.id: {'x': r(a.alvoX), 'y': r(a.alvoY), 'c': a.carga, 's': a.sentado, 'n': a.nome, 'o': a.cor},
      },
      'ev': ev,
      'ag': agito == null ? null : [agito!.index, r(agitoResta)],
      'mo': [
        for (final mo in moedasChao) [r(mo.x), r(mo.y), mo.valor],
      ],
      'fr': fruta == null ? null : [r(fruta!.$1), r(fruta!.$2)],
      'cb': [combo, r(comboTempo)],
    };
  }

  /// Aplica a foto que chegou do celular que roda o jogo. Devolve os eventos (sons, moedas).
  List<Evento> aplicarAoVivo(Map<String, dynamic> d, String meuId) {
    final e = d['e'];
    if (e is Map) carregar(Map<String, dynamic>.from(e), DateTime.now());
    final cl = d['cl'];
    if (cl is List) {
      final antigos = {for (final c in clientes) c.id: c};
      clientes.clear();
      for (final item in cl.take(30)) {
        if (item is! List || item.length < 8 || item.take(3).any((v) => v is! num)) continue;
        final id = (item[0] as num).toInt();
        final quer = item[3] is int ? (item[3] as int).clamp(0, sucos.length - 1) : 0;
        final c =
            antigos[id] ??
            Cliente((item[1] as num).toDouble(), (item[2] as num).toDouble(), quer, 1, item[5] is int ? item[5] as int : 0);
        c
          ..id = id
          ..alvoX = (item[1] as num).toDouble()
          ..alvoY = (item[2] as num).toDouble()
          ..faltam = item[4] is int ? (item[4] as int).clamp(0, 9) : 1
          ..estado = EstadoCliente.values[item[6] is int ? (item[6] as int).clamp(0, 2) : 0]
          ..feliz = item[7] is num ? (item[7] as num).toDouble().clamp(0, 2) : 0
          ..vip = item.length > 8 && item[8] == 1
          ..paciencia = item.length > 9 && item[9] is num ? (item[9] as num).toDouble().clamp(0, 60) : 0;
        clientes.add(c);
      }
    }
    final js = d['js'];
    if (js is Map) {
      for (final ent in js.entries) {
        final id = ent.key, v = ent.value;
        if (id is! String || v is! Map) continue;
        final dados = Map<String, dynamic>.from(v);
        final carga = dados['c'];
        final lista = carga is List
            ? [
                for (final k in carga.take(30))
                  if (k is int && k >= 0 && k < sucos.length) k,
              ]
            : <int>[];
        if (id == meuId) {
          jogador.carga
            ..clear()
            ..addAll(lista);
        } else {
          atualizarAmigo(id, dados);
          amigos[id]?.carga
            ?..clear()
            ..addAll(lista);
        }
      }
      amigos.removeWhere((id, _) => !js.containsKey(id));
    }
    final ag = d['ag'];
    if (ag is List && ag.length == 2 && ag[0] is int && ag[1] is num) {
      agito = TipoAgito.values[(ag[0] as int).clamp(0, TipoAgito.values.length - 1)];
      agitoResta = (ag[1] as num).toDouble().clamp(0, 60);
    } else {
      agito = null;
    }
    final mo = d['mo'];
    moedasChao.clear();
    if (mo is List) {
      for (final x in mo.take(30)) {
        if (x is List && x.length == 3 && x.every((v) => v is num && v.isFinite)) {
          moedasChao.add(MoedaChao((x[0] as num).toDouble(), (x[1] as num).toDouble(), (x[2] as num).toDouble()));
        }
      }
    }
    final fr = d['fr'];
    fruta = fr is List && fr.length == 2 && fr.every((v) => v is num)
        ? ((fr[0] as num).toDouble(), (fr[1] as num).toDouble())
        : null;
    final cb = d['cb'];
    if (cb is List && cb.length == 2 && cb[0] is int && cb[1] is num) {
      combo = (cb[0] as int).clamp(0, 999);
      comboTempo = (cb[1] as num).toDouble().clamp(0, tempoCombo);
    }
    final ev = d['ev'];
    final eventos = <Evento>[];
    if (ev is List) {
      for (final x in ev.take(30)) {
        if (x is! List || x.length < 6 || x[0] is! int || x.skip(1).take(3).any((v) => v is! num)) continue;
        final t = (x[0] as int).clamp(0, TipoEvento.values.length - 1);
        eventos.add(
          Evento(
            TipoEvento.values[t],
            (x[1] as num).toDouble(),
            (x[2] as num).toDouble(),
            valor: (x[3] as num).toDouble(),
            suco: x[4] is int ? (x[4] as int).clamp(0, sucos.length - 1) : 0,
            texto: x[5] is String ? (x[5] as String).substring(0, min(60, (x[5] as String).length)) : '',
          ),
        );
      }
    }
    return eventos;
  }

  void _moverJogador(double dt, double dirX, double dirY, List<Evento> eventos) {
    final j = jogador;
    final tam = sqrt(dirX * dirX + dirY * dirY);
    final f = tam > 1 ? 1 / tam : 1.0;
    // aceleração suave (sem "patinar" nem parar seco)
    final alvoVx = dirX * f * velocidade, alvoVy = dirY * f * velocidade;
    final k = min(1.0, dt * (tam > 0.05 ? 12 : 16));
    j.vx += (alvoVx - j.vx) * k;
    j.vy += (alvoVy - j.vy) * k;
    final vel = sqrt(j.vx * j.vx + j.vy * j.vy);
    if (vel > 0.05) {
      _moverCom(j, j.vx * dt, j.vy * dt);
      j.andando += dt * (vel / 3.6);
      // vira para o lado em que anda (na tela, esquerda = x - y diminuindo)
      final telaX = j.vx - j.vy;
      if (telaX.abs() > 0.3) j.olhandoEsquerda = telaX < 0;
      _poeira -= dt;
      if (_poeira <= 0 && vel > 2.5) {
        _poeira = 0.12;
        eventos.add(Evento(TipoEvento.poeira, j.x, j.y));
      }
    } else {
      j.andando = 0;
    }
  }

  /// Marca há quanto tempo a pessoa está em cima de uma placa. Devolve a placa (ou null).
  Placa? _contarPlaca(Pessoa quem, double dt) {
    final pl = placas.where((pl) => (pl.x - quem.x).abs() < 0.55 && (pl.y - quem.y).abs() < 0.55).firstOrNull;
    if (pl?.id != quem.placaAtual) quem.naPlaca = 0;
    quem.placaAtual = pl?.id;
    if (pl != null) quem.naPlaca += dt;
    return pl;
  }

  void _placas(Pessoa quem, double dt, List<Evento> eventos) {
    final atual = _contarPlaca(quem, dt);
    for (final pl in placas) {
      if (pl.id == atual?.id && quem.naPlaca >= esperaPlaca && dinheiro > 0) {
        final c = custo(pl);
        final ritmo = max(c / 1.3, 20.0) * dt;
        final v = min(ritmo, min(dinheiro, c - pl.pago));
        dinheiro -= v;
        pagos[pl.id] = pl.pago + v;
        if (pl.pago + v >= c - 1e-6) eventos.add(_aplicarPlaca(pl));
      }
    }
  }

  void _cadeira(double dt, List<Evento> eventos) {
    if (sentado) return;
    final perto = (jogador.x - cadeira.x).abs() < 0.65 && (jogador.y - cadeira.y).abs() < 0.65;
    if (_naCadeira < 0) {
      _naCadeira = min(0, _naCadeira + dt); // tempinho depois de levantar
      if (!perto) _naCadeira = 0;
      return;
    }
    _naCadeira = perto ? _naCadeira + dt : 0;
    if (_naCadeira > 0.25) {
      sentado = true;
      usouComputador = true;
      jogador
        ..x = cadeira.x
        ..y = cadeira.y
        ..vx = 0
        ..vy = 0
        ..andando = 0;
      eventos.add(Evento(TipoEvento.sentou, cadeira.x, cadeira.y));
    }
  }

  List<Evento> _pegar(Pessoa p, double dt) {
    p.pegarEm -= dt;
    if (p.pegarEm > 0) return const [];
    final cap = p.ajudante ? 3 : capacidade;
    if (p.carga.length >= cap) return const [];
    for (final b in barracas.where((b) => b.aberta && b.estoque > 0)) {
      if (p.ajudante && p.alvoBarraca != b.indice) continue;
      if (p.x - b.x < 1.45 && p.x > b.x && (b.y - p.y).abs() < 0.9) {
        b.estoque--;
        p.carga.add(b.indice);
        p.pegarEm = 0.12;
        return [Evento(TipoEvento.pegou, b.x, b.y, suco: b.indice)];
      }
    }
    return const [];
  }

  bool _pertoDoBalcao(Pessoa p) =>
      p.x > balcao.x - 0.4 &&
      p.x < balcao.x + balcao.w + 0.4 &&
      p.y > balcao.y + balcao.d - 0.1 &&
      p.y < balcao.y + balcao.d + 1.3;

  List<Evento> _entregar(Pessoa p, double dt) {
    p.entregarEm -= dt;
    if (p.entregarEm > 0 || p.carga.isEmpty || !_pertoDoBalcao(p)) return const [];
    for (final c in clientes.where((c) => c.estado == EstadoCliente.esperando)) {
      final k = p.carga.lastIndexOf(c.quer);
      if (k < 0) continue;
      p.carga.removeAt(k);
      c.faltam--;
      final eventos = <Evento>[];
      if (!p.ajudante) {
        combo = comboTempo > 0 ? combo + 1 : 1;
        comboTempo = tempoCombo;
        if (const [3, 5, 8, 11].contains(combo)) {
          eventos.add(Evento(TipoEvento.combo, c.x, c.y, valor: multCombo, texto: 'COMBO x${multCombo.toStringAsFixed(1)}!'));
        }
      }
      final v = preco(barracas[c.quer]) * (p.ajudante ? 1 : multCombo) * (c.vip ? 5 : 1);
      dinheiro += v;
      vendidoTotal += v;
      copos++;
      p.entregarEm = 0.16;
      if (c.faltam <= 0) {
        c.estado = EstadoCliente.saindo;
        c.feliz = 2;
        if (c.vip) {
          eventos.add(Evento(TipoEvento.vip, c.x, c.y, valor: v, texto: '👑 VIP satisfeito!'));
          if (agito == TipoAgito.vip) agitoResta = 0;
        }
      }
      return [Evento(TipoEvento.vendeu, c.x, c.y, valor: v, suco: c.quer), ...eventos];
    }
    return const [];
  }

  void _pensarAjudante(Pessoa a, double dt) {
    final querido = {for (final c in clientes.where((c) => c.estado != EstadoCliente.saindo)) c.quer};
    double alvoX, alvoY;
    if (a.carga.isNotEmpty && (a.carga.length >= 3 || a.alvoBarraca == null || barracas[a.alvoBarraca!].estoque == 0)) {
      alvoX = 7.0 + (ajudantes.indexOf(a) % 4) * 1.2;
      alvoY = balcao.y + balcao.d + 0.6;
      a.alvoBarraca = null;
      if (_pertoDoBalcao(a)) {
        a.parado += dt;
        if (a.parado > 4) {
          a.carga.clear(); // ninguém quer: devolve (não trava)
          a.parado = 0;
        }
      }
    } else {
      if (a.alvoBarraca == null) {
        final opcoes = barracas.where((b) => b.aberta && b.estoque > 0 && querido.contains(b.indice)).toList();
        a.alvoBarraca = opcoes.isEmpty ? null : opcoes[_rnd.nextInt(opcoes.length)].indice;
        a.parado = 0;
      }
      final b = a.alvoBarraca == null ? null : barracas[a.alvoBarraca!];
      alvoX = b == null ? 8.6 : b.x + 1.05;
      alvoY = b == null ? 6.6 : b.y;
    }
    final dx = alvoX - a.x, dy = alvoY - a.y;
    final d = sqrt(dx * dx + dy * dy);
    if (d > 0.15) {
      final passo = min(d, velocidadeAjudante * dt);
      _moverCom(a, dx / d * passo, dy / d * passo);
      a.andando += dt;
      if ((dx - dy).abs() > 0.2) a.olhandoEsquerda = (dx - dy) < 0;
    } else {
      a.andando = 0;
    }
  }

  void _clientes(double dt) {
    final promo = ativo(Boost.promocao);
    final excursao = agito == TipoAgito.excursao;
    final maxClientes = 3 + abertas + nivel(Habilidade.marketing) + (promo ? 3 : 0) + (excursao ? 5 : 0);
    _proximoCliente -= dt * (promo ? 2 : 1) * (excursao ? 4 : 1);
    if (_proximoCliente <= 0 && clientes.length < maxClientes) {
      _proximoCliente = max(0.9, 4.0 - abertas * 0.35 - nivel(Habilidade.marketing) * 0.3) * (0.7 + _rnd.nextDouble() * 0.6);
      final abertasL = barracas.where((b) => b.aberta).toList();
      var soma = 0;
      for (final b in abertasL) {
        soma += b.indice + 1;
      }
      var sorteio = _rnd.nextInt(soma);
      var quer = abertasL.first.indice;
      for (final b in abertasL) {
        sorteio -= b.indice + 1;
        if (sorteio < 0) {
          quer = b.indice;
          break;
        }
      }
      final daEsquerda = _rnd.nextBool();
      clientes.add(
        Cliente(daEsquerda ? -0.5 : larguraMapa + 0.5, ruaY, quer, 1 + _rnd.nextInt(2), _rnd.nextInt(8))..id = ++_idCliente,
      );
    }
    final vs = vagas;
    final ocupadas = {
      for (final c in clientes)
        if (c.vaga >= 0 && c.estado != EstadoCliente.saindo) c.vaga,
    };
    for (final c in clientes) {
      double tx, ty;
      switch (c.estado) {
        case EstadoCliente.chegando:
          if (c.vaga < 0) {
            final livre = [
              for (var v = 0; v < vs.length; v++)
                if (!ocupadas.contains(v)) v,
            ].firstOrNull;
            if (livre != null) {
              c.vaga = livre;
              ocupadas.add(livre);
            }
          }
          if (c.vaga < 0) {
            tx = 2.5 + clientes.indexOf(c) * 0.8;
            ty = ruaY;
          } else {
            (tx, ty) = vs[c.vaga];
          }
        case EstadoCliente.esperando:
          (tx, ty) = vs[c.vaga];
        case EstadoCliente.saindo:
          tx = c.x < larguraMapa / 2 ? -1.0 : larguraMapa + 1;
          ty = ruaY;
          c.feliz = max(0, c.feliz - dt);
      }
      final passo = 2.3 * dt;
      var andou = false;
      if ((c.x - tx).abs() > 0.06) {
        if ((c.y - ruaY).abs() > 0.06) {
          c.y += (ruaY - c.y).sign * min(passo, (ruaY - c.y).abs());
        } else {
          c.x += (tx - c.x).sign * min(passo, (tx - c.x).abs());
        }
        andou = true;
      } else if ((c.y - ty).abs() > 0.06) {
        c.y += (ty - c.y).sign * min(passo, (ty - c.y).abs());
        andou = true;
      }
      if (andou) {
        c.andando += dt;
      } else {
        c.andando = 0;
        if (c.estado == EstadoCliente.chegando && c.vaga >= 0) c.estado = EstadoCliente.esperando;
      }
    }
    for (final c in clientes.where((c) => c.vip && c.estado != EstadoCliente.saindo)) {
      c.paciencia -= dt;
      if (c.paciencia <= 0) c.estado = EstadoCliente.saindo; // cansou de esperar
    }
    clientes.removeWhere((c) => c.estado == EstadoCliente.saindo && (c.x < -0.8 || c.x > larguraMapa + 0.8));
  }

  double get ganhoAjudantesPorSegundo {
    final d = nivelMelhoria(Melhoria.delivery) * 0.15 * precoMedio;
    return ajudantes.length * precoMedio / 4.0 + d;
  }

  double ganhoOffline(double segundos) {
    final v = ganhoAjudantesPorSegundo * 0.5 * segundos.clamp(0, 3 * 3600);
    dinheiro += v;
    vendidoTotal += v;
    return v;
  }

  // ---------------- salvar ----------------
  Map<String, dynamic> paraJson(DateTime agora) => {
    'v': 2,
    'dinheiro': dinheiro,
    'vendido': vendidoTotal,
    'copos': copos,
    'mochila': nivelMochila,
    'tenis': nivelTenis,
    'ajudantes': ajudantes.length,
    'pontos': pontosHabilidade,
    'missao': missao,
    'boosts': boostsUsados,
    'pc': usouComputador,
    'hab': {for (final e in habilidades.entries) e.key.name: e.value},
    'emp': {for (final e in melhorias.entries) e.key.name: e.value},
    'pagos': pagos,
    'cid': cidades,
    'bo': {
      for (final e in boosts.entries)
        if (e.value > 0) e.key.name: e.value.roundToDouble(),
    },
    'barracas': [
      for (final b in barracas) {'a': b.aberta, 'n': b.nivel, 'e': b.estoque},
    ],
    'salvoEm': agora.millisecondsSinceEpoch,
  };

  double carregar(Map<String, dynamic> j, DateTime agora) {
    double n(Object? v) => v is num && v.isFinite ? max(0, v.toDouble()) : 0;
    int i(Object? v, int maxV) => v is num ? v.toInt().clamp(0, maxV) : 0;
    dinheiro = n(j['dinheiro']);
    vendidoTotal = n(j['vendido']);
    copos = i(j['copos'], 1 << 30);
    nivelMochila = i(j['mochila'], maxNivelEquip);
    nivelTenis = i(j['tenis'], maxNivelEquip);
    pontosHabilidade = i(j['pontos'], 1000);
    missao = i(j['missao'], missoes.length + 1000);
    boostsUsados = i(j['boosts'], 1 << 20);
    usouComputador = j['pc'] == true;
    cidades = i(j['cid'], 100);
    final hab = j['hab'];
    for (final h in Habilidade.values) {
      habilidades[h] = hab is Map ? i(hab[h.name], maxHabilidade) : 0;
    }
    final emp = j['emp'];
    for (final m in Melhoria.values) {
      melhorias[m] = emp is Map ? i(emp[m.name], m.maxNivel) : 0;
    }
    final bo = j['bo'];
    for (final b in Boost.values) {
      boosts[b] = bo is Map ? n(bo[b.name]).clamp(0, 900).toDouble() : 0;
    }
    final qtdAjudantes = grupo ? 0 : i(j['ajudantes'], custosAjudante.length);
    if (ajudantes.length != qtdAjudantes) ajudantes.clear();
    for (var k = ajudantes.length; k < qtdAjudantes; k++) {
      ajudantes.add(Pessoa(10.0 + k * 0.6, 6.4, ajudante: true));
    }
    pagos.clear();
    final p = j['pagos'];
    if (p is Map) {
      for (final e in p.entries) {
        if (e.key is String && (e.key as String).length < 30) pagos[e.key as String] = n(e.value);
      }
    }
    final bs = j['barracas'];
    if (bs is List) {
      for (var k = 0; k < barracas.length && k < bs.length; k++) {
        final b = bs[k];
        if (b is! Map) continue;
        barracas[k]
          ..aberta = b['a'] == true || k == 0
          ..nivel = max(1, i(b['n'], 10));
        barracas[k].estoque = i(b['e'], 40).clamp(0, capacidadeBarraca(barracas[k]));
      }
    }
    final s = j['salvoEm'];
    return s is int ? max(0, agora.millisecondsSinceEpoch - s) / 1000 : 0;
  }
}

/// R$ 1.234 · R$ 12,3 mil · R$ 4,56 mi
String reais3d(double v) {
  if (v.isInfinite) return '—';
  if (v >= 1e9) return 'R\$ ${(v / 1e9).toStringAsFixed(2).replaceAll('.', ',')} bi';
  if (v >= 1e6) return 'R\$ ${(v / 1e6).toStringAsFixed(2).replaceAll('.', ',')} mi';
  if (v >= 1e4) return 'R\$ ${(v / 1e3).toStringAsFixed(1).replaceAll('.', ',')} mil';
  return 'R\$ ${v.toStringAsFixed(0)}';
}
