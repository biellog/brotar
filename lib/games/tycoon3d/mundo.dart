/// 🧃 Império do Suco 3D: mundo aberto (lógica pura, sem Flutter, testada em test/).
///
/// Você anda pela praça, pega os copos nas barracas, leva até o balcão e vende
/// para os clientes. Fique em cima das placas para comprar coisas.
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

/// Onde fica cada barraca na praça.
const posicoesBarracas = <(double, double)>[
  (4.5, 8.0), (7.0, 8.0), (9.5, 8.0), (12.0, 8.0),
  (4.5, 11.5), (7.0, 11.5), (9.5, 11.5), (12.0, 11.5),
];

/// Balcão onde os clientes são atendidos (retângulo no chão).
const balcao = (x: 6.6, y: 4.0, w: 4.2, d: 0.8);

/// Lugares dos clientes atrás do balcão.
const vagasBalcao = <(double, double)>[(7.2, 3.4), (8.7, 3.4), (10.2, 3.4)];

/// Rua por onde os clientes chegam e vão embora.
const ruaY = 1.6;

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
  int get capacidade => 4 + nivel * 2;
  double get tempo => suco.tempo / (1 + 0.25 * (nivel - 1));
  double get preco => suco.preco * (1 + 0.35 * (nivel - 1));
  double get custoMelhorar => suco.preco * 25 * pow(1.6, nivel - 1);
}

enum TipoPlaca { abrir, melhorar, ajudante, mochila, tenis }

class Placa {
  final TipoPlaca tipo;
  final int alvo; // barraca (abrir/melhorar)
  final double x, y;
  double pago = 0;
  Placa(this.tipo, this.alvo, this.x, this.y);

  String get id => '${tipo.name}:$alvo';
}

class Pessoa {
  double x, y;
  final carga = <int>[]; // copos carregados (índice do suco)
  final bool ajudante;
  double _pegarEm = 0, _entregarEm = 0;
  // IA do ajudante
  int? alvoBarraca;
  double parado = 0;
  double andando = 0; // para a animação de passos
  Pessoa(this.x, this.y, {this.ajudante = false});
}

enum EstadoCliente { chegando, esperando, saindo }

class Cliente {
  double x, y;
  final int quer;
  int faltam;
  final int aparencia;
  EstadoCliente estado = EstadoCliente.chegando;
  int vaga = -1;
  double feliz = 0;
  double andando = 0;
  Cliente(this.x, this.y, this.quer, this.faltam, this.aparencia);
}

enum TipoEvento { pegou, vendeu, comprou, abriu, contratou }

class Evento {
  final TipoEvento tipo;
  final double x, y, valor;
  final int suco;
  const Evento(this.tipo, this.x, this.y, {this.valor = 0, this.suco = 0});
}

class Mundo {
  final Random _rnd;
  double dinheiro = 0;
  double vendidoTotal = 0;
  int copos = 0;
  int nivelMochila = 0, nivelTenis = 0;
  final barracas = List.generate(sucos.length, Barraca.new);
  final ajudantes = <Pessoa>[];
  final clientes = <Cliente>[];
  final pagos = <String, double>{}; // quanto já foi pago em cada placa
  late final Pessoa jogador = Pessoa(8.6, 6.0);
  double _proximoCliente = 1;
  double relogio = 0;

  static const custosAjudante = [150.0, 1500.0, 12000.0, 90000.0];
  static const maxNivelEquip = 5;

  Mundo([Random? rnd]) : _rnd = rnd ?? Random() {
    barracas[0].aberta = true;
  }

  int get capacidade => 4 + nivelMochila * 2;
  double get velocidade => 3.2 * (1 + 0.12 * nivelTenis);
  int get abertas => barracas.where((b) => b.aberta).length;

  // ---------------- placas ----------------
  /// Placas visíveis agora (só a próxima barraca a abrir aparece).
  List<Placa> get placas {
    final l = <Placa>[];
    final prox = barracas.where((b) => !b.aberta).firstOrNull;
    if (prox != null) l.add(Placa(TipoPlaca.abrir, prox.indice, prox.x, prox.y));
    for (final b in barracas.where((b) => b.aberta && b.nivel < 10)) {
      l.add(Placa(TipoPlaca.melhorar, b.indice, b.x + 1.1, b.y + 1.0));
    }
    if (abertas >= 2 && ajudantes.length < custosAjudante.length) l.add(Placa(TipoPlaca.ajudante, 0, 13.6, 4.6));
    if (abertas >= 1 && nivelMochila < maxNivelEquip) l.add(Placa(TipoPlaca.mochila, 0, 2.4, 4.6));
    if (abertas >= 2 && nivelTenis < maxNivelEquip) l.add(Placa(TipoPlaca.tenis, 0, 2.4, 6.2));
    for (final p in l) {
      p.pago = pagos[p.id] ?? 0;
    }
    return l;
  }

  double custo(Placa p) => switch (p.tipo) {
        TipoPlaca.abrir => sucos[p.alvo].custoAbrir,
        TipoPlaca.melhorar => barracas[p.alvo].custoMelhorar,
        TipoPlaca.ajudante => custosAjudante[ajudantes.length],
        TipoPlaca.mochila => 60 * pow(3, nivelMochila).toDouble(),
        TipoPlaca.tenis => 90 * pow(3, nivelTenis).toDouble(),
      };

  String rotulo(Placa p) => switch (p.tipo) {
        TipoPlaca.abrir => 'Abrir ${sucos[p.alvo].nome}',
        TipoPlaca.melhorar => '${sucos[p.alvo].nome} nv ${barracas[p.alvo].nivel + 1}',
        TipoPlaca.ajudante => 'Ajudante ${ajudantes.length + 1}',
        TipoPlaca.mochila => 'Mochila +2 copos',
        TipoPlaca.tenis => 'Tênis +12%',
      };

  String icone(Placa p) => switch (p.tipo) {
        TipoPlaca.abrir => sucos[p.alvo].emoji,
        TipoPlaca.melhorar => '⬆️',
        TipoPlaca.ajudante => '🧑‍🍳',
        TipoPlaca.mochila => '🎒',
        TipoPlaca.tenis => '👟',
      };

  Evento? _aplicar(Placa p) {
    pagos.remove(p.id);
    switch (p.tipo) {
      case TipoPlaca.abrir:
        barracas[p.alvo].aberta = true;
        return Evento(TipoEvento.abriu, p.x, p.y, suco: p.alvo);
      case TipoPlaca.melhorar:
        barracas[p.alvo].nivel++;
      case TipoPlaca.ajudante:
        ajudantes.add(Pessoa(13.0, 5.4, ajudante: true));
        return Evento(TipoEvento.contratou, p.x, p.y);
      case TipoPlaca.mochila:
        nivelMochila++;
      case TipoPlaca.tenis:
        nivelTenis++;
    }
    return Evento(TipoEvento.comprou, p.x, p.y);
  }

  /// Próximo objetivo (para a faixa de dica no topo).
  String get objetivo {
    final prox = barracas.where((b) => !b.aberta).firstOrNull;
    if (abertas >= 2 && ajudantes.isEmpty) return '🧑‍🍳 Contrate um ajudante: ele vende por você';
    if (prox != null) return '${prox.suco.emoji} Junte ${_reais(prox.suco.custoAbrir)} para abrir ${prox.suco.nome}';
    return '👑 Todas as barracas abertas! Melhore e contrate mais ajudantes';
  }

  // ---------------- colisão ----------------
  List<(double, double, double, double)> get _solidos => [
        for (final b in barracas.where((b) => b.aberta)) (b.x - 0.7, b.y - 0.7, 1.4, 1.4),
        (balcao.x, balcao.y, balcao.w, balcao.d),
        (13.0, 13.0, 1.6, 1.6), // fonte
      ];

  void _moverCom(Pessoa p, double dx, double dy) {
    const r = 0.28;
    bool bate(double x, double y) =>
        _solidos.any((s) => x + r > s.$1 && x - r < s.$1 + s.$3 && y + r > s.$2 && y - r < s.$2 + s.$4);
    final nx = (p.x + dx).clamp(0.5, larguraMapa - 0.5);
    if (!bate(nx, p.y)) p.x = nx;
    final ny = (p.y + dy).clamp(2.6, alturaMapa - 0.5); // a rua (em cima) é só dos clientes
    if (!bate(p.x, ny)) p.y = ny;
  }

  // ---------------- passo ----------------
  List<Evento> passo(double dt, double dirX, double dirY) {
    relogio += dt;
    final eventos = <Evento>[];
    // jogador
    final tam = sqrt(dirX * dirX + dirY * dirY);
    if (tam > 0.05) {
      final f = (tam > 1 ? 1 / tam : 1.0) * velocidade * dt;
      _moverCom(jogador, dirX * f, dirY * f);
      jogador.andando += dt;
    } else {
      jogador.andando = 0;
    }
    // barracas produzem
    for (final b in barracas.where((b) => b.aberta && b.estoque < b.capacidade)) {
      b.progresso += dt / b.tempo;
      if (b.progresso >= 1) {
        b.progresso = 0;
        b.estoque++;
      }
    }
    // ajudantes
    for (final a in ajudantes) {
      _pensarAjudante(a, dt);
    }
    // pegar e entregar (jogador e ajudantes)
    for (final p in [jogador, ...ajudantes]) {
      eventos.addAll(_pegar(p, dt));
      eventos.addAll(_entregar(p, dt));
    }
    // placas: o dinheiro "escoa" para a placa enquanto você está em cima dela
    for (final pl in placas) {
      if ((pl.x - jogador.x).abs() < 0.6 && (pl.y - jogador.y).abs() < 0.6 && dinheiro > 0) {
        final c = custo(pl);
        final ritmo = max(c / 1.4, 20.0) * dt;
        final v = min(ritmo, min(dinheiro, c - pl.pago));
        dinheiro -= v;
        pagos[pl.id] = pl.pago + v;
        if (pl.pago + v >= c - 1e-6) {
          final e = _aplicar(pl);
          if (e != null) eventos.add(e);
        }
      }
    }
    _clientes(dt);
    return eventos;
  }

  List<Evento> _pegar(Pessoa p, double dt) {
    p._pegarEm -= dt;
    if (p._pegarEm > 0) return const [];
    final cap = p.ajudante ? 3 : capacidade;
    if (p.carga.length >= cap) return const [];
    for (final b in barracas.where((b) => b.aberta && b.estoque > 0)) {
      if (p.ajudante && p.alvoBarraca != b.indice) continue;
      if ((b.x - p.x).abs() < 1.25 && (b.y - p.y).abs() < 1.25) {
        b.estoque--;
        p.carga.add(b.indice);
        p._pegarEm = 0.14;
        return [Evento(TipoEvento.pegou, b.x, b.y, suco: b.indice)];
      }
    }
    return const [];
  }

  bool _pertoDoBalcao(Pessoa p) =>
      p.x > balcao.x - 0.4 && p.x < balcao.x + balcao.w + 0.4 && p.y > balcao.y + balcao.d - 0.1 && p.y < balcao.y + balcao.d + 1.3;

  List<Evento> _entregar(Pessoa p, double dt) {
    p._entregarEm -= dt;
    if (p._entregarEm > 0 || p.carga.isEmpty || !_pertoDoBalcao(p)) return const [];
    for (final c in clientes.where((c) => c.estado == EstadoCliente.esperando)) {
      final k = p.carga.lastIndexOf(c.quer);
      if (k < 0) continue;
      p.carga.removeAt(k);
      c.faltam--;
      final preco = barracas[c.quer].preco;
      dinheiro += preco;
      vendidoTotal += preco;
      copos++;
      p._entregarEm = 0.18;
      if (c.faltam <= 0) {
        c.estado = EstadoCliente.saindo;
        c.feliz = 2;
      }
      return [Evento(TipoEvento.vendeu, c.x, c.y, valor: preco, suco: c.quer)];
    }
    return const [];
  }

  void _pensarAjudante(Pessoa a, double dt) {
    final querido = {for (final c in clientes.where((c) => c.estado != EstadoCliente.saindo)) c.quer};
    double alvoX, alvoY;
    if (a.carga.isNotEmpty && (a.carga.length >= 3 || a.alvoBarraca == null || barracas[a.alvoBarraca!].estoque == 0)) {
      // leva para o balcão
      alvoX = 7.4 + (ajudantes.indexOf(a) % 3) * 1.2;
      alvoY = balcao.y + balcao.d + 0.6;
      a.alvoBarraca = null;
      if (_pertoDoBalcao(a)) {
        a.parado += dt;
        if (a.parado > 4) {
          a.carga.clear(); // ninguém quer mais: devolve (não trava)
          a.parado = 0;
        }
      }
    } else {
      // escolhe uma barraca com estoque que algum cliente quer
      if (a.alvoBarraca == null) {
        final opcoes = barracas.where((b) => b.aberta && b.estoque > 0 && querido.contains(b.indice)).toList();
        a.alvoBarraca = opcoes.isEmpty ? null : opcoes[_rnd.nextInt(opcoes.length)].indice;
        a.parado = 0;
      }
      final b = a.alvoBarraca == null ? null : barracas[a.alvoBarraca!];
      alvoX = b == null ? 8.6 : b.x;
      alvoY = b == null ? 6.4 : b.y + 1.0;
    }
    final dx = alvoX - a.x, dy = alvoY - a.y;
    final d = sqrt(dx * dx + dy * dy);
    if (d > 0.15) {
      final passo = min(d, 2.6 * dt);
      _moverCom(a, dx / d * passo, dy / d * passo);
      a.andando += dt;
    } else {
      a.andando = 0;
    }
  }

  void _clientes(double dt) {
    final maxClientes = 3 + abertas;
    _proximoCliente -= dt;
    if (_proximoCliente <= 0 && clientes.length < maxClientes) {
      _proximoCliente = max(1.2, 4.0 - abertas * 0.35) * (0.7 + _rnd.nextDouble() * 0.6);
      final abertasL = barracas.where((b) => b.aberta).toList();
      // prefere as barracas mais novas (dá motivo para abrir mais)
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
      clientes.add(Cliente(daEsquerda ? -0.5 : larguraMapa + 0.5, ruaY, quer, 1 + _rnd.nextInt(2), _rnd.nextInt(8)));
    }
    final ocupadas = {for (final c in clientes) if (c.vaga >= 0 && c.estado != EstadoCliente.saindo) c.vaga};
    for (final c in clientes) {
      double tx, ty;
      switch (c.estado) {
        case EstadoCliente.chegando:
          if (c.vaga < 0) {
            final livre = [for (var v = 0; v < vagasBalcao.length; v++) if (!ocupadas.contains(v)) v].firstOrNull;
            if (livre != null) {
              c.vaga = livre;
              ocupadas.add(livre);
            }
          }
          if (c.vaga < 0) {
            // espera na calçada
            tx = 3.5 + clientes.indexOf(c) * 0.9;
            ty = ruaY;
          } else {
            (tx, ty) = vagasBalcao[c.vaga];
          }
        case EstadoCliente.esperando:
          (tx, ty) = vagasBalcao[c.vaga];
        case EstadoCliente.saindo:
          tx = c.x < larguraMapa / 2 ? -1.0 : larguraMapa + 1;
          ty = ruaY;
          c.feliz = max(0, c.feliz - dt);
      }
      // caminho em "L": pela rua (y = 1,6) até ficar na direção do destino, depois desce/sobe
      final passo = 2.2 * dt;
      var andou = false;
      if ((c.x - tx).abs() > 0.06) {
        if ((c.y - ruaY).abs() > 0.06) {
          c.y += (ruaY - c.y).sign * min(passo, (ruaY - c.y).abs()); // volta para a rua
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
    clientes.removeWhere((c) => c.estado == EstadoCliente.saindo && (c.x < -0.8 || c.x > larguraMapa + 0.8));
  }

  /// Faturamento estimado por segundo dos ajudantes (para o ganho offline).
  double get ganhoAjudantesPorSegundo {
    if (ajudantes.isEmpty) return 0;
    final abertasL = barracas.where((b) => b.aberta).toList();
    final precoMedio = abertasL.fold<double>(0, (s, b) => s + b.preco) / abertasL.length;
    return ajudantes.length * precoMedio / 4.0; // ~1 copo a cada 4 s por ajudante
  }

  /// Ganho enquanto o app estava fechado (até 3 horas, metade do ritmo).
  double ganhoOffline(double segundos) {
    final v = ganhoAjudantesPorSegundo * 0.5 * segundos.clamp(0, 3 * 3600);
    dinheiro += v;
    vendidoTotal += v;
    return v;
  }

  // ---------------- salvar ----------------
  Map<String, dynamic> paraJson(DateTime agora) => {
        'v': 1,
        'dinheiro': dinheiro,
        'vendido': vendidoTotal,
        'copos': copos,
        'mochila': nivelMochila,
        'tenis': nivelTenis,
        'ajudantes': ajudantes.length,
        'pagos': pagos,
        'barracas': [for (final b in barracas) {'a': b.aberta, 'n': b.nivel, 'e': b.estoque}],
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
    ajudantes.clear();
    for (var k = 0; k < i(j['ajudantes'], custosAjudante.length); k++) {
      ajudantes.add(Pessoa(12.0 + k * 0.5, 5.4, ajudante: true));
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
          ..nivel = max(1, i(b['n'], 10))
          ..estoque = i(b['e'], 30).clamp(0, barracas[k].capacidade);
      }
    }
    final s = j['salvoEm'];
    return s is int ? max(0, agora.millisecondsSinceEpoch - s) / 1000 : 0;
  }
}

String _reais(double v) => v >= 1000 ? 'R\$ ${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)} mil' : 'R\$ ${v.toStringAsFixed(0)}';
