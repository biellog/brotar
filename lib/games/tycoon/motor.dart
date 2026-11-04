/// 🧃 Império do Suco: lógica pura do tycoon (sem Flutter, testada em test/).
library;

import 'dart:math';

class Produto {
  final String id, nome, emoji, gerente;
  final double custoBase, crescimento, receitaBase, tempoBase, custoGerente;
  const Produto(this.id, this.nome, this.emoji, this.custoBase, this.crescimento, this.receitaBase,
      this.tempoBase, this.custoGerente, this.gerente);
}

/// Sucos da loja: cada um custa e rende mais, mas demora mais.
const produtos = <Produto>[
  Produto('limao', 'Limonada', '🍋', 4, 1.07, 1, 0.8, 1000, 'Dona Cida'),
  Produto('laranja', 'Suco de Laranja', '🍊', 60, 1.15, 60, 3, 15000, 'Seu Zé'),
  Produto('morango', 'Vitamina de Morango', '🍓', 720, 1.14, 540, 6, 100000, 'Júlia'),
  Produto('coco', 'Água de Coco', '🥥', 8640, 1.13, 4320, 12, 500000, 'Marcão'),
  Produto('manga', 'Suco de Manga', '🥭', 103680, 1.12, 51840, 24, 1.2e6, 'Tia Lu'),
  Produto('uva', 'Suco de Uva', '🍇', 1.244e6, 1.11, 622080, 96, 1e7, 'Rafa'),
  Produto('melancia', 'Suco de Melancia', '🍉', 1.493e7, 1.10, 7.465e6, 384, 1.11e8, 'Bia'),
  Produto('abacaxi', 'Abacaxi com Hortelã', '🍍', 1.792e8, 1.09, 8.958e7, 1536, 5.55e8, 'Dr. Kiwi'),
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

class EstadoProduto {
  int nivel = 0;
  bool gerente = false;
  bool rodando = false;
  double progresso = 0;
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
  double dinheiro = 0;
  double ganhoDaFilial = 0; // nesta filial
  double ganhoDaVida = 0; // de todas as filiais (dá as estrelas)
  int estrelas = 0;
  int filiais = 1;

  // Cliente VIP
  double vipEm = 25; // segundos até o próximo
  double vipVisivel = 0; // > 0 enquanto está na loja
  final Random _rnd;

  MotorTycoon([Random? rnd]) : _rnd = rnd ?? Random() {
    estados[0].nivel = 1; // começa com a barraquinha de limonada
  }

  static const bonusPorEstrela = 0.05;

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

  double receita(int i) => produtos[i].receitaBase * estados[i].nivel * multProduto(i) * multEstrelas;

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
      ok--; // corrige arredondamento
    }
    return ok;
  }

  double get ganhoPorSegundo {
    var g = 0.0;
    for (var i = 0; i < produtos.length; i++) {
      if (estados[i].nivel > 0 && estados[i].gerente) g += receita(i) / tempo(i);
    }
    return g;
  }

  /// Estrelas que a próxima filial dá (10 · √(ganho da vida / 1 bilhão)).
  int get estrelasPossiveis => (10 * sqrt(ganhoDaVida / 1e9)).floor();
  int get estrelasNovas => max(0, estrelasPossiveis - estrelas);

  // ---------------- ações ----------------
  /// Toque no produto: começa a preparar (se não tiver gerente).
  bool tocar(int i) {
    final e = estados[i];
    if (e.nivel == 0 || e.gerente || e.rodando) return false;
    e.rodando = true;
    return true;
  }

  /// Compra [n] níveis. Retorna true se atingiu um marco novo.
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
    final vendas = <Venda>[];
    for (var i = 0; i < produtos.length; i++) {
      final e = estados[i];
      if (e.nivel == 0 || !(e.gerente || e.rodando)) continue;
      e.progresso += dt / tempo(i);
      if (e.progresso >= 1) {
        final ciclos = e.gerente ? e.progresso.floor() : 1;
        final v = receita(i) * ciclos;
        _ganhar(v);
        vendas.add(Venda(i, v));
        if (e.gerente) {
          e.progresso -= ciclos;
        } else {
          e.progresso = 0;
          e.rodando = false;
        }
      }
    }
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

  /// Gorjeta do cliente VIP: 1 minuto de faturamento (ou o mínimo para o começo).
  double get valorVip => max(ganhoPorSegundo * 60, max(receita(0) * 25, 50));

  double atenderVip() {
    if (vipVisivel <= 0) return 0;
    final v = valorVip;
    _ganhar(v);
    vipVisivel = 0;
    return v;
  }

  /// Ganho enquanto o app estava fechado (só com gerentes, até 3 horas).
  double ganhoOffline(double segundos) {
    final s = segundos.clamp(0, 3 * 3600).toDouble();
    final v = ganhoPorSegundo * s;
    if (v > 0) _ganhar(v);
    return v;
  }

  /// Nova filial: recomeça do zero, mas com as estrelas (bônus permanente).
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
        'v': 1,
        'dinheiro': dinheiro,
        'ganhoDaFilial': ganhoDaFilial,
        'ganhoDaVida': ganhoDaVida,
        'estrelas': estrelas,
        'filiais': filiais,
        'compradas': compradas.toList(),
        'produtos': [
          for (final e in estados) {'n': e.nivel, 'g': e.gerente, 'p': e.progresso}
        ],
        'salvoEm': agora.millisecondsSinceEpoch,
      };

  /// Carrega o jogo salvo. Retorna os segundos que o app ficou fechado.
  double carregar(Map<String, dynamic> j, DateTime agora) {
    double num_(String k) => (j[k] as num?)?.toDouble() ?? 0;
    dinheiro = num_('dinheiro');
    ganhoDaFilial = num_('ganhoDaFilial');
    ganhoDaVida = num_('ganhoDaVida');
    estrelas = (j['estrelas'] as num?)?.toInt() ?? 0;
    filiais = (j['filiais'] as num?)?.toInt() ?? 1;
    compradas
      ..clear()
      ..addAll(((j['compradas'] as List?) ?? []).map((e) => (e as num).toInt()).where((k) => k >= 0 && k < melhorias.length));
    final ps = (j['produtos'] as List?) ?? [];
    for (var i = 0; i < estados.length && i < ps.length; i++) {
      final p = ps[i] as Map;
      estados[i]
        ..nivel = max(0, (p['n'] as num?)?.toInt() ?? 0)
        ..gerente = p['g'] == true
        ..progresso = ((p['p'] as num?)?.toDouble() ?? 0).clamp(0, 0.999)
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
