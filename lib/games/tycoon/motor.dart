/// 🧃 Império do Suco: lógica pura do tycoon (sem Flutter, testada em test/).
library;

import 'dart:math';

class Produto {
  final String id, nome, emoji, gerente;
  final double custoBase, crescimento, receitaBase, tempoBase, custoGerente;
  final int cor; // cor da fruta (ARGB), usada no visual
  const Produto(this.id, this.nome, this.emoji, this.custoBase, this.crescimento, this.receitaBase,
      this.tempoBase, this.custoGerente, this.gerente, this.cor);
}

/// Sucos da loja: cada um custa e rende mais, mas demora mais.
const produtos = <Produto>[
  Produto('limao', 'Limonada', '🍋', 4, 1.07, 1, 0.8, 1000, 'Dona Cida', 0xFFF4D03F),
  Produto('laranja', 'Suco de Laranja', '🍊', 60, 1.15, 60, 3, 15000, 'Seu Zé', 0xFFFF8C1A),
  Produto('morango', 'Vitamina de Morango', '🍓', 720, 1.14, 540, 6, 100000, 'Júlia', 0xFFFF4D6D),
  Produto('coco', 'Água de Coco', '🥥', 8640, 1.13, 4320, 12, 500000, 'Marcão', 0xFFB08968),
  Produto('manga', 'Suco de Manga', '🥭', 103680, 1.12, 51840, 24, 1.2e6, 'Tia Lu', 0xFFFFB627),
  Produto('uva', 'Suco de Uva', '🍇', 1.244e6, 1.11, 622080, 96, 1e7, 'Rafa', 0xFF9D4EDD),
  Produto('melancia', 'Suco de Melancia', '🍉', 1.493e7, 1.10, 7.465e6, 384, 1.11e8, 'Bia', 0xFF52B788),
  Produto('abacaxi', 'Abacaxi com Hortelã', '🍍', 1.792e8, 1.09, 8.958e7, 1536, 5.55e8, 'Dr. Kiwi', 0xFFE9C46A),
];

/// Níveis que dobram a velocidade do suco.
const marcos = [25, 50, 100, 200, 300, 400, 500];

class Melhoria {
  final String nome, descricao;
  final int produto; // -1 = todos
  final double mult, custo;
  const Melhoria(this.nome, this.descricao, this.produto, this.mult, this.custo);
}

const melhorias = <Melhoria>[
  Melhoria('Limão siciliano', 'Limonada rende 3x', 0, 3, 2.5e5),
  Melhoria('Laranja-pera', 'Suco de laranja rende 3x', 1, 3, 5e5),
  Melhoria('Morango orgânico', 'Vitamina de morango rende 3x', 2, 3, 1e6),
  Melhoria('Coco gelado', 'Água de coco rende 3x', 3, 3, 5e6),
  Melhoria('Manga palmer', 'Suco de manga rende 3x', 4, 3, 1e7),
  Melhoria('Uva do Vale', 'Suco de uva rende 3x', 5, 3, 2.5e7),
  Melhoria('Melancia sem semente', 'Suco de melancia rende 3x', 6, 3, 5e7),
  Melhoria('Hortelã fresquinha', 'Abacaxi com hortelã rende 3x', 7, 3, 1e8),
  Melhoria('Propaganda na rádio', 'TODOS os sucos rendem 3x', -1, 3, 5e8),
  Melhoria('Delivery por app', 'TODOS os sucos rendem 3x', -1, 3, 1e10),
  Melhoria('Comercial na TV', 'TODOS os sucos rendem 3x', -1, 3, 5e11),
  Melhoria('Franquia nacional', 'TODOS os sucos rendem 5x', -1, 5, 5e13),
];

// ---------------- Missões ----------------
enum TipoMissao { abrir, nivel, vender, gerente, vip, rush, filial, ganhar }

class Missao {
  final String texto;
  final TipoMissao tipo;
  final int produto;
  final double alvo;
  final int gemas;
  final double minutosDeGanho; // recompensa em dinheiro: X minutos de faturamento
  const Missao(this.texto, this.tipo, this.produto, this.alvo, this.gemas, this.minutosDeGanho);
}

/// Sequência de missões: sempre existe um próximo objetivo.
final List<Missao> missoes = () {
  final m = <Missao>[];
  final vendas = [25, 60, 100, 150, 200, 300, 400, 500];
  for (var i = 0; i < produtos.length; i++) {
    final p = produtos[i];
    if (i > 0) m.add(Missao('Abra ${p.nome}', TipoMissao.abrir, i, 1, 1, 2));
    m.add(Missao('Venda ${vendas[i]} x ${p.nome}', TipoMissao.vender, i, vendas[i].toDouble(), 2, 3));
    m.add(Missao('${p.nome} no nível 25', TipoMissao.nivel, i, 25, 2, 3));
    m.add(Missao('Contrate ${p.gerente}', TipoMissao.gerente, i, 1, 3, 5));
    if (i == 1) m.add(const Missao('Atenda 3 clientes VIP', TipoMissao.vip, 0, 3, 3, 5));
    if (i == 2) m.add(const Missao('Atenda 40 clientes na Hora do Rush', TipoMissao.rush, 0, 40, 3, 5));
    m.add(Missao('${p.nome} no nível 50', TipoMissao.nivel, i, 50, 3, 5));
    if (i == 3) m.add(const Missao('Fature R\$ 1 milhão no total', TipoMissao.ganhar, 0, 1e6, 4, 5));
    if (i == 4) m.add(const Missao('Atenda 10 clientes VIP', TipoMissao.vip, 0, 10, 4, 8));
    if (i == 5) m.add(const Missao('Abra a sua 2ª filial', TipoMissao.filial, 0, 2, 6, 10));
    m.add(Missao('${p.nome} no nível 100', TipoMissao.nivel, i, 100, 4, 8));
  }
  m.add(const Missao('Atenda 300 clientes na Hora do Rush', TipoMissao.rush, 0, 300, 8, 15));
  m.add(const Missao('Fature R\$ 1 trilhão no total', TipoMissao.ganhar, 0, 1e12, 10, 15));
  m.add(const Missao('Abra a sua 5ª filial', TipoMissao.filial, 0, 5, 15, 20));
  for (var i = 0; i < produtos.length; i++) {
    m.add(Missao('${produtos[i].nome} no nível 200', TipoMissao.nivel, i, 200, 5, 10));
  }
  return m;
}();

// ---------------- Turbos (pagos com gemas) ----------------
enum Turbo { dobro, tempo, rush }

const custoTurbo = {Turbo.dobro: 5, Turbo.tempo: 10, Turbo.rush: 3};

/// Fachada da loja conforme o Nível do Império.
const fachadas = ['Barraquinha', 'Quiosque', 'Lojinha', 'Loja Grande', 'Megaloja', 'Shopping do Suco'];

class EstadoProduto {
  int nivel = 0;
  bool gerente = false;
  bool rodando = false;
  double progresso = 0;
  int vendas = 0; // ciclos vendidos (missões)
}

/// Evento de um ciclo concluído (para som e animação "+R$").
class Venda {
  final int produto;
  final double valor;
  const Venda(this.produto, this.valor);
}

class MotorTycoon {
  final estados = List.generate(produtos.length, (_) => EstadoProduto());
  final compradas = <int>{}; // melhorias compradas
  final missoesFeitas = <int>{};
  double dinheiro = 0;
  double ganhoDaFilial = 0; // nesta filial
  double ganhoDaVida = 0; // de todas as filiais (dá as estrelas)
  int estrelas = 0;
  int filiais = 1;
  int gemas = 0;
  int vipsAtendidos = 0;
  int clientesRush = 0;
  int nivelImperioPremiado = 1; // até qual nível do império já deu gemas
  int ultimoBau = 0; // dia (desde 1970) do último baú aberto

  // efeitos temporários (segundos restantes)
  double turboDobro = 0;
  double ondaCalor = 0;
  double rush = 0;
  double proximoRush = 150;
  double proximoCalor = 240;

  // Cliente VIP
  double vipEm = 25;
  double vipVisivel = 0;

  // combo da Hora do Rush
  int combo = 0;
  double _ultimoAtendimento = -10;
  double _relogio = 0;

  final Random _rnd;

  MotorTycoon([Random? rnd]) : _rnd = rnd ?? Random() {
    estados[0].nivel = 1; // começa com a barraquinha de limonada
  }

  static const bonusPorEstrela = 0.05;
  static const duracaoRush = 20.0;

  // ---------------- contas ----------------
  int marcosAtingidos(int i) => marcos.where((m) => estados[i].nivel >= m).length;

  int? proximoMarco(int i) => marcos.where((m) => estados[i].nivel < m).firstOrNull;

  double tempo(int i) => produtos[i].tempoBase / pow(2, marcosAtingidos(i));

  double multProduto(int i) {
    var m = 1.0;
    for (final k in compradas) {
      final mel = melhorias[k];
      if (mel.produto == i || mel.produto == -1) m *= mel.mult;
    }
    return m;
  }

  double get multEstrelas => 1 + estrelas * bonusPorEstrela;

  /// Multiplicador dos efeitos temporários (turbo x2, onda de calor x3).
  double get multTemporario => (turboDobro > 0 ? 2 : 1) * (ondaCalor > 0 ? 3 : 1);

  double receitaBase(int i) => produtos[i].receitaBase * estados[i].nivel * multProduto(i) * multEstrelas;

  double receita(int i) => receitaBase(i) * multTemporario;

  /// Custo de comprar [n] níveis do produto [i] (progressão geométrica).
  double custo(int i, int n) {
    final p = produtos[i];
    final r = p.crescimento;
    return p.custoBase * pow(r, estados[i].nivel) * (pow(r, n) - 1) / (r - 1);
  }

  /// Quantos níveis dá para comprar agora (no máximo 1000 de uma vez).
  int maxCompravel(int i) {
    final p = produtos[i];
    final r = p.crescimento;
    final primeiro = p.custoBase * pow(r, estados[i].nivel);
    if (dinheiro < primeiro) return 0;
    final n = (log(dinheiro * (r - 1) / primeiro + 1) / log(r)).floor();
    var ok = min(n, 1000);
    while (ok > 0 && custo(i, ok) > dinheiro + 1e-6) {
      ok--;
    }
    return ok;
  }

  /// Faturamento por segundo SEM efeitos temporários (base para recompensas).
  double get ganhoPorSegundoBase {
    var g = 0.0;
    for (var i = 0; i < produtos.length; i++) {
      if (estados[i].nivel > 0 && estados[i].gerente) g += receitaBase(i) / tempo(i);
    }
    return g;
  }

  double get ganhoPorSegundo => ganhoPorSegundoBase * multTemporario;

  /// Valor de referência para recompensas: o faturamento ou, no começo, o da limonada.
  double get _referencia => max(ganhoPorSegundoBase, max(receitaBase(0) / tempo(0), 1));

  int get estrelasPossiveis => (10 * sqrt(ganhoDaVida / 1e9)).floor();
  int get estrelasNovas => max(0, estrelasPossiveis - estrelas);

  /// Nível do Império: sobe a cada 5x de faturamento total (R$ 100, 500, 2,5 mil...).
  int get nivelImperio => ganhoDaVida < 100 ? 1 : (log(ganhoDaVida / 100) / log(5)).floor() + 2;

  double progressoImperio() {
    final n = nivelImperio;
    final ini = n == 1 ? 0.0 : 100 * pow(5, n - 2).toDouble();
    final fim = 100 * pow(5, n - 1).toDouble();
    return ((ganhoDaVida - ini) / (fim - ini)).clamp(0.0, 1.0);
  }

  int get fachada => min(fachadas.length - 1, (nivelImperio - 1) ~/ 3);

  // ---------------- ações ----------------
  bool tocar(int i) {
    final e = estados[i];
    if (e.nivel == 0 || e.gerente || e.rodando) return false;
    e.rodando = true;
    return true;
  }

  bool comprar(int i, int n) {
    if (n <= 0) return false;
    final c = custo(i, n);
    if (c > dinheiro + 1e-6) return false;
    final antes = marcosAtingidos(i);
    dinheiro -= c;
    estados[i].nivel += n;
    return marcosAtingidos(i) > antes;
  }

  bool comprarGerente(int i) {
    final e = estados[i];
    if (e.gerente || e.nivel == 0 || dinheiro < produtos[i].custoGerente) return false;
    dinheiro -= produtos[i].custoGerente;
    e.gerente = true;
    return true;
  }

  bool comprarMelhoria(int k) {
    if (compradas.contains(k) || dinheiro < melhorias[k].custo) return false;
    dinheiro -= melhorias[k].custo;
    compradas.add(k);
    return true;
  }

  void _ganhar(double v) {
    dinheiro += v;
    ganhoDaFilial += v;
    ganhoDaVida += v;
  }

  /// Avança o tempo. Devolve as vendas concluídas.
  List<Venda> passo(double dt) {
    _relogio += dt;
    final vendas = <Venda>[];
    for (var i = 0; i < produtos.length; i++) {
      final e = estados[i];
      if (e.nivel == 0 || !(e.gerente || e.rodando)) continue;
      e.progresso += dt / tempo(i);
      if (e.progresso >= 1) {
        final ciclos = e.gerente ? e.progresso.floor() : 1;
        final v = receita(i) * ciclos;
        _ganhar(v);
        e.vendas += ciclos;
        vendas.add(Venda(i, v));
        if (e.gerente) {
          e.progresso -= ciclos;
        } else {
          e.progresso = 0;
          e.rodando = false;
        }
      }
    }
    // efeitos temporários
    turboDobro = max(0, turboDobro - dt);
    ondaCalor = max(0, ondaCalor - dt);
    if (rush > 0) {
      rush = max(0, rush - dt);
    } else {
      proximoRush -= dt;
      if (proximoRush <= 0) iniciarRush();
    }
    proximoCalor -= dt;
    if (proximoCalor <= 0) {
      ondaCalor = 30;
      proximoCalor = 200 + _rnd.nextDouble() * 160;
    }
    if (_relogio - _ultimoAtendimento > 1.3) combo = 0;
    // cliente VIP
    if (vipVisivel > 0) {
      vipVisivel = max(0, vipVisivel - dt);
    } else {
      vipEm -= dt;
      if (vipEm <= 0) {
        vipVisivel = 9;
        vipEm = 45 + _rnd.nextDouble() * 60;
      }
    }
    return vendas;
  }

  // ---------------- VIP ----------------
  double get valorVip => max(_referencia * 60, max(receitaBase(0) * 25, 50));

  /// Atende o VIP: dinheiro + 1 gema.
  double atenderVip() {
    if (vipVisivel <= 0) return 0;
    final v = valorVip;
    _ganhar(v);
    vipVisivel = 0;
    vipsAtendidos++;
    gemas++;
    return v;
  }

  // ---------------- Hora do Rush ----------------
  void iniciarRush() {
    rush = duracaoRush;
    combo = 0;
    proximoRush = 150 + _rnd.nextDouble() * 120;
  }

  /// Valor de um cliente do rush (cresce com o combo, até x10). Dourado vale 5x e pode dar gema.
  double atenderClienteRush({bool dourado = false}) {
    if (rush <= 0) return 0;
    combo = (_relogio - _ultimoAtendimento <= 1.3) ? combo + 1 : 1;
    _ultimoAtendimento = _relogio;
    clientesRush++;
    final v = max(_referencia * 2, 2.0) * min(combo, 10) * (dourado ? 5 : 1);
    _ganhar(v);
    if (dourado && _rnd.nextDouble() < 0.5) gemas++;
    return v;
  }

  // ---------------- Turbos ----------------
  /// Compra um turbo com gemas. Devolve o dinheiro ganho (viagem no tempo) ou 0.
  double usarTurbo(Turbo t) {
    final c = custoTurbo[t]!;
    if (gemas < c) return -1;
    if (t == Turbo.rush && rush > 0) return -1;
    gemas -= c;
    switch (t) {
      case Turbo.dobro:
        turboDobro += 300; // 5 minutos
        return 0;
      case Turbo.tempo:
        final v = _referencia * 3600; // 1 hora de faturamento na hora
        _ganhar(v);
        return v;
      case Turbo.rush:
        iniciarRush();
        return 0;
    }
  }

  // ---------------- Missões ----------------
  double valorMissao(Missao m) => switch (m.tipo) {
        TipoMissao.abrir || TipoMissao.nivel => estados[m.produto].nivel.toDouble(),
        TipoMissao.vender => estados[m.produto].vendas.toDouble(),
        TipoMissao.gerente => estados[m.produto].gerente ? 1 : 0,
        TipoMissao.vip => vipsAtendidos.toDouble(),
        TipoMissao.rush => clientesRush.toDouble(),
        TipoMissao.filial => filiais.toDouble(),
        TipoMissao.ganhar => ganhoDaVida,
      };

  double progressoMissao(int k) => (valorMissao(missoes[k]) / missoes[k].alvo).clamp(0.0, 1.0);

  /// As 3 próximas missões ainda não resgatadas.
  List<int> get missoesAtivas => [
        for (var k = 0; k < missoes.length; k++)
          if (!missoesFeitas.contains(k)) k,
      ].take(3).toList();

  int get missoesProntas => missoesAtivas.where((k) => progressoMissao(k) >= 1).length;

  double recompensaMissao(int k) => _referencia * 60 * missoes[k].minutosDeGanho;

  /// Resgata a recompensa. Devolve o dinheiro ganho (ou -1 se não estava pronta).
  double resgatarMissao(int k) {
    if (missoesFeitas.contains(k) || !missoesAtivas.contains(k) || progressoMissao(k) < 1) return -1;
    final v = recompensaMissao(k);
    missoesFeitas.add(k);
    gemas += missoes[k].gemas;
    _ganhar(v);
    return v;
  }

  /// Gemas por cada Nível do Império novo (chame depois de ganhar dinheiro).
  int premiarNivelImperio() {
    final n = nivelImperio;
    if (n <= nivelImperioPremiado) return 0;
    final novas = (n - nivelImperioPremiado) * 2;
    nivelImperioPremiado = n;
    gemas += novas;
    return novas;
  }

  // ---------------- Baú diário ----------------
  static int dia(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  bool podeAbrirBau(DateTime agora) => dia(agora) > ultimoBau;

  /// Abre o baú do dia: 3 a 8 gemas + 15 minutos de faturamento.
  (int, double) abrirBau(DateTime agora) {
    if (!podeAbrirBau(agora)) return (0, 0);
    ultimoBau = dia(agora);
    final g = 3 + _rnd.nextInt(6);
    final v = _referencia * 60 * 15;
    gemas += g;
    _ganhar(v);
    return (g, v);
  }

  // ---------------- offline / filial ----------------
  double ganhoOffline(double segundos) {
    final s = segundos.clamp(0, 3 * 3600).toDouble();
    final v = ganhoPorSegundoBase * s;
    if (v > 0) _ganhar(v);
    return v;
  }

  bool abrirFilial() {
    if (estrelasNovas <= 0) return false;
    estrelas = estrelasPossiveis;
    filiais++;
    dinheiro = 0;
    ganhoDaFilial = 0;
    compradas.clear();
    for (final e in estados) {
      e
        ..nivel = 0
        ..gerente = false
        ..rodando = false
        ..progresso = 0;
    }
    estados[0].nivel = 1;
    return true;
  }

  // ---------------- salvar / carregar ----------------
  Map<String, dynamic> paraJson(DateTime agora) => {
        'v': 2,
        'dinheiro': dinheiro,
        'ganhoDaFilial': ganhoDaFilial,
        'ganhoDaVida': ganhoDaVida,
        'estrelas': estrelas,
        'filiais': filiais,
        'gemas': gemas,
        'vips': vipsAtendidos,
        'rush': clientesRush,
        'imperio': nivelImperioPremiado,
        'bau': ultimoBau,
        'turbo': turboDobro,
        'compradas': compradas.toList(),
        'missoes': missoesFeitas.toList(),
        'produtos': [
          for (final e in estados) {'n': e.nivel, 'g': e.gerente, 'p': e.progresso, 'v': e.vendas}
        ],
        'salvoEm': agora.millisecondsSinceEpoch,
      };

  /// Carrega o jogo salvo. Retorna os segundos que o app ficou fechado.
  double carregar(Map<String, dynamic> j, DateTime agora) {
    double num_(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int int_(String k, [int padrao = 0]) => max(0, (j[k] as num?)?.toInt() ?? padrao);
    Set<int> conjunto(String k, int limite) => ((j[k] as List?) ?? [])
        .whereType<num>()
        .map((e) => e.toInt())
        .where((x) => x >= 0 && x < limite)
        .toSet();
    dinheiro = max(0, num_('dinheiro'));
    ganhoDaFilial = max(0, num_('ganhoDaFilial'));
    ganhoDaVida = max(0, num_('ganhoDaVida'));
    estrelas = int_('estrelas');
    filiais = max(1, int_('filiais', 1));
    gemas = int_('gemas');
    vipsAtendidos = int_('vips');
    clientesRush = int_('rush');
    nivelImperioPremiado = max(1, int_('imperio', nivelImperio));
    ultimoBau = int_('bau');
    turboDobro = num_('turbo').clamp(0, 3600).toDouble();
    compradas
      ..clear()
      ..addAll(conjunto('compradas', melhorias.length));
    missoesFeitas
      ..clear()
      ..addAll(conjunto('missoes', missoes.length));
    final ps = (j['produtos'] as List?) ?? [];
    for (var i = 0; i < estados.length && i < ps.length; i++) {
      final p = ps[i] is Map ? ps[i] as Map : const {};
      estados[i]
        ..nivel = max(0, (p['n'] as num?)?.toInt() ?? 0)
        ..gerente = p['g'] == true
        ..progresso = ((p['p'] as num?)?.toDouble() ?? 0).clamp(0, 0.999)
        ..vendas = max(0, (p['v'] as num?)?.toInt() ?? 0)
        ..rodando = false;
    }
    if (estados[0].nivel == 0) estados[0].nivel = 1;
    final salvo = (j['salvoEm'] as num?)?.toInt();
    if (salvo == null) return 0;
    return max(0, agora.millisecondsSinceEpoch - salvo) / 1000;
  }
}

/// R$ 1,50 · R$ 12,3 mil · R$ 4,56 mi · R$ 7,8 bi · ...
String reais(double v) {
  const nomes = ['', 'mil', 'mi', 'bi', 'tri', 'quatri', 'quinti', 'sexti', 'septi', 'octi', 'noni', 'deci'];
  if (v.isNaN || v.isInfinite) return 'R\$ ∞';
  if (v < 1000) {
    final s = v < 100 ? v.toStringAsFixed(2) : v.toStringAsFixed(0);
    return 'R\$ ${s.replaceAll('.', ',')}';
  }
  var k = 0;
  var x = v;
  while (x >= 1000 && k < nomes.length - 1) {
    x /= 1000;
    k++;
  }
  if (x >= 1000) return 'R\$ ${v.toStringAsExponential(2).replaceAll('.', ',')}';
  final casas = x < 10 ? 2 : (x < 100 ? 1 : 0);
  return 'R\$ ${x.toStringAsFixed(casas).replaceAll('.', ',')} ${nomes[k]}';
}
