/// 🌟 Brilha Junto: arena online de vagalumes. Lógica pura (testada em test/).
///
/// Ninguém perde: as luzes renascem, encostar em alguém só solta faíscas
/// e quem voa PERTO de outro jogador ganha x2 ("juntos brilhamos mais").
library;

import 'dart:math';

const larguraMundo = 2400.0;
const alturaMundo = 2400.0;
const totalLuzes = 70;
const totalEstrelas = 3;
const duracaoRodada = 120; // segundos
const intervalo = 12; // segundos de pódio entre rodadas
const raioDupla = 220.0;
const velocidadeMax = 330.0;

const coresVagalume = [
  0xFFFFD166, 0xFF06D6A0, 0xFF4CC9F0, 0xFFFF6FA5, 0xFFB98CF0, 0xFFFF9F1C, 0xFF7BD389, 0xFFF94144,
];

const emotes = ['👋', '💚', '💪', '🔥', '🙌', '😄'];

const _nomesBots = ['Ana', 'Léo', 'Bia', 'Caio', 'Duda', 'Rafa', 'Lia', 'Theo', 'Malu', 'Davi', 'Nina', 'Gabi'];
const _sobrenomesBots = ['🌻', '🌊', '🍀', '🌙', '⭐', '🦋', '🌿', '☀️'];

/// Multiplicação módulo 2^32 sem estourar (dá o mesmo resultado em qualquer aparelho).
int _mul32(int a, int b) => (((a & 0xffff) * b) + ((((a >> 16) * b) & 0xffff) << 16)) & 0xffffffff;

int _misturar(int x) {
  x &= 0xffffffff;
  x = _mul32(x ^ (x >> 16), 0x45d9f3b);
  x = _mul32(x ^ (x >> 16), 0x45d9f3b);
  return (x ^ (x >> 16)) & 0xffffffff;
}

/// Número pseudoaleatório estável entre 0 e 1 (mesmo resultado em todos os celulares).
double hashUnit(int a, int b, int c) =>
    _misturar(a ^ _misturar(b ^ _misturar(c + 0x9e3779b9))) / 4294967296.0;

int hashTexto(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

class Luz {
  final int id; // 0..totalLuzes-1 = luz comum; 1000+ = estrela cadente
  int geracao;
  Luz(this.id, this.geracao);

  bool get estrela => id >= 1000;
  int get valor => estrela ? 10 : 1;
}

class Vagalume {
  final String id;
  String nome;
  int cor;
  final bool bot; // simulado NESTE celular
  final bool robo; // é um bot (mostra 🤖), mesmo que venha de outro celular
  final bool eu;
  double x, y, vx = 0, vy = 0;
  double alvoX, alvoY; // jogadores remotos andam suavemente até a última posição recebida
  int pontos = 0;
  String? emote;
  double emoteAte = 0;
  double vistoEm = 0; // último sinal recebido (remotos)
  final trilha = <(double, double)>[];
  // IA dos bots
  double pensarEm = 0;
  double botAlvoX = 0, botAlvoY = 0;

  Vagalume(this.id, this.nome, this.cor, this.x, this.y, {this.bot = false, bool robo = false, this.eu = false})
      : robo = robo || bot,
        alvoX = x,
        alvoY = y;

  double get raio => 18 + min(pontos, 300) / 300 * 14; // brilha (cresce) com as luzes
}

class Coleta {
  final String jogador;
  final Luz luz;
  final int ganho;
  final bool dupla;
  const Coleta(this.jogador, this.luz, this.ganho, this.dupla);
}

class MotorBrilha {
  final String sala;
  final Random _rnd;
  final jogadores = <String, Vagalume>{};
  final luzes = <int, Luz>{};
  final estrelasPegas = <int>{};
  int rodada = -1;
  double relogio = 0;

  MotorBrilha(this.sala, [Random? rnd]) : _rnd = rnd ?? Random();

  int get semente => hashTexto('$sala#$rodada');

  // ---------------- rodadas (todos os celulares usam o mesmo relógio) ----------------
  static int rodadaDe(DateTime agora) => agora.millisecondsSinceEpoch ~/ 1000 ~/ (duracaoRodada + intervalo);

  static double segundosNaRodada(DateTime agora) =>
      (agora.millisecondsSinceEpoch / 1000) % (duracaoRodada + intervalo);

  static bool emIntervalo(DateTime agora) => segundosNaRodada(agora) >= duracaoRodada;

  static int restante(DateTime agora) => max(0, (duracaoRodada - segundosNaRodada(agora)).ceil());

  /// Começa uma rodada nova: zera pontos e espalha as luzes (iguais para todos).
  bool sincronizarRodada(DateTime agora) {
    final r = rodadaDe(agora);
    if (r == rodada) return false;
    rodada = r;
    luzes.clear();
    estrelasPegas.clear();
    for (var i = 0; i < totalLuzes; i++) {
      luzes[i] = Luz(i, 0);
    }
    for (final j in jogadores.values) {
      j.pontos = 0;
      j.trilha.clear();
    }
    return true;
  }

  /// Estrelas cadentes: 3 por vez, trocam a cada 20 s.
  void atualizarEstrelas(DateTime agora) {
    final janela = (segundosNaRodada(agora) ~/ 20);
    luzes.removeWhere((id, l) => l.estrela && (id - 1000) ~/ totalEstrelas != janela);
    for (var k = 0; k < totalEstrelas; k++) {
      final id = 1000 + janela * totalEstrelas + k;
      if (!estrelasPegas.contains(id)) luzes.putIfAbsent(id, () => Luz(id, 0));
    }
  }

  /// Posição de uma luz: calculada do mesmo jeito em todos os celulares.
  (double, double) posicaoLuz(Luz l) {
    final m = 120.0;
    return (
      m + hashUnit(semente, l.id, l.geracao * 2) * (larguraMundo - 2 * m),
      m + hashUnit(semente, l.id, l.geracao * 2 + 1) * (alturaMundo - 2 * m),
    );
  }

  // ---------------- jogadores ----------------
  Vagalume entrar(String id, String nome, int cor, {bool bot = false, bool robo = false, bool eu = false}) {
    return jogadores.putIfAbsent(id, () {
      final x = larguraMundo * (0.3 + _rnd.nextDouble() * 0.4);
      final y = alturaMundo * (0.3 + _rnd.nextDouble() * 0.4);
      return Vagalume(id, nome, cor, x, y, bot: bot, robo: robo, eu: eu)..vistoEm = relogio;
    });
  }

  void sair(String id) => jogadores.remove(id);

  Iterable<Vagalume> get pessoas => jogadores.values.where((j) => !j.robo);

  /// Mantém a sala animada: completa com bots até [alvo] jogadores
  /// e tira bots quando entra gente de verdade.
  void ajustarBots(int alvo, {int? reaisNaSala}) {
    final reais = reaisNaSala ?? pessoas.length;
    final bots = jogadores.values.where((j) => j.bot).toList();
    final precisa = max(0, alvo - reais);
    if (bots.length > precisa) {
      for (final b in bots.take(bots.length - precisa)) {
        jogadores.remove(b.id);
      }
    }
    var k = 0;
    while (jogadores.values.where((j) => j.bot).length < precisa && k < 40) {
      final n = _rnd.nextInt(_nomesBots.length);
      final id = 'bot-$n-${_rnd.nextInt(9999)}';
      entrar(id, '${_nomesBots[n]} ${_sobrenomesBots[_rnd.nextInt(_sobrenomesBots.length)]}',
          coresVagalume[_rnd.nextInt(coresVagalume.length)], bot: true);
      k++;
    }
  }

  /// Meu movimento: direção do joystick (-1..1 em cada eixo).
  void moverMeu(String id, double dx, double dy, double dt) {
    final j = jogadores[id];
    if (j == null) return;
    final tam = sqrt(dx * dx + dy * dy);
    final f = tam > 1 ? 1 / tam : 1.0;
    final alvoVx = dx * f * velocidadeMax, alvoVy = dy * f * velocidadeMax;
    final suav = min(1.0, dt * 6);
    j.vx += (alvoVx - j.vx) * suav;
    j.vy += (alvoVy - j.vy) * suav;
    _andar(j, dt);
  }

  void _andar(Vagalume j, double dt) {
    j.x = (j.x + j.vx * dt).clamp(30, larguraMundo - 30);
    j.y = (j.y + j.vy * dt).clamp(30, alturaMundo - 30);
    if (j.trilha.isEmpty ||
        (j.trilha.last.$1 - j.x).abs() + (j.trilha.last.$2 - j.y).abs() > 10) {
      j.trilha.add((j.x, j.y));
      final maxTrilha = 14 + min(j.pontos, 200) ~/ 10;
      while (j.trilha.length > maxTrilha) {
        j.trilha.removeAt(0);
      }
    }
  }

  /// Posição recebida pela rede (jogador remoto).
  void posicaoRemota(String id, double x, double y, int pontos, {String? nome, int? cor, bool robo = false}) {
    var j = jogadores[id];
    if (j == null && nome != null && cor != null) {
      j = entrar(id, nome, cor, robo: robo)
        ..x = x
        ..y = y;
    }
    if (j == null || j.eu || j.bot) return;
    j
      ..alvoX = x.clamp(0, larguraMundo).toDouble()
      ..alvoY = y.clamp(0, alturaMundo).toDouble()
      ..pontos = pontos.clamp(0, 100000)
      ..vistoEm = relogio;
  }

  void emote(String id, String e) {
    final j = jogadores[id];
    if (j == null || !emotes.contains(e)) return;
    j.emote = e;
    j.emoteAte = relogio + 3;
  }

  /// Alguém pegou uma luz em outro celular: ela renasce em outro lugar.
  void coletaRemota(int luzId, int geracao) {
    if (luzId >= 1000) {
      estrelasPegas.add(luzId); // estrela: some para todos
      luzes.remove(luzId);
      return;
    }
    final l = luzes[luzId];
    if (l != null && geracao > l.geracao) l.geracao = geracao;
  }

  /// Quem está perto de outro vagalume ganha x2 (bots só ganham perto de uma pessoa de verdade).
  bool emDupla(Vagalume j) => jogadores.values.any((o) =>
      o.id != j.id &&
      (!j.robo || !o.robo) &&
      (o.x - j.x) * (o.x - j.x) + (o.y - j.y) * (o.y - j.y) < raioDupla * raioDupla);

  // ---------------- passo ----------------
  /// Avança o jogo. Devolve as luzes que [meuId] e os bots pegaram (para enviar/tocar som).
  List<Coleta> passo(double dt, String meuId, {bool pausado = false}) {
    relogio += dt;
    final coletas = <Coleta>[];
    for (final j in jogadores.values) {
      if (j.bot) {
        _pensarBot(j, dt);
        _andar(j, dt);
      } else if (!j.eu) {
        // interpolação suave até a última posição recebida
        final k = min(1.0, dt * 8);
        j.x += (j.alvoX - j.x) * k;
        j.y += (j.alvoY - j.y) * k;
        j.vx = 0;
        j.vy = 0;
        _andar(j, dt);
      }
      if (j.emote != null && relogio > j.emoteAte) j.emote = null;
    }
    if (pausado) return coletas;
    // coletas: só o meu vagalume e os bots coletam aqui (os outros avisam pela rede)
    for (final j in jogadores.values.where((j) => j.eu || j.bot)) {
      for (final l in luzes.values.toList()) {
        if (!luzes.containsKey(l.id)) continue; // estrela já pega neste passo
        final (lx, ly) = posicaoLuz(l);
        final r = j.raio + (l.estrela ? 22 : 12);
        if ((lx - j.x) * (lx - j.x) + (ly - j.y) * (ly - j.y) < r * r) {
          final dupla = emDupla(j);
          final ganho = l.valor * (dupla ? 2 : 1);
          j.pontos += ganho;
          l.geracao++;
          coletas.add(Coleta(j.id, l, ganho, dupla));
          if (l.estrela) {
            estrelasPegas.add(l.id); // estrela some até a próxima leva
            luzes.remove(l.id);
          }
        }
      }
    }
    // jogadores que sumiram da rede (sem sinal há 8 s)
    jogadores.removeWhere((_, j) => !j.eu && !j.bot && relogio - j.vistoEm > 8);
    return coletas;
  }

  void _pensarBot(Vagalume b, double dt) {
    b.pensarEm -= dt;
    if (b.pensarEm <= 0) {
      b.pensarEm = 0.8 + _rnd.nextDouble() * 1.6;
      final sorte = _rnd.nextDouble();
      final eu = jogadores.values.where((j) => j.eu).firstOrNull;
      if (sorte < 0.18 && eu != null) {
        // às vezes vem brilhar junto com você (x2 para os dois!)
        b.botAlvoX = eu.x + (_rnd.nextDouble() - 0.5) * 160;
        b.botAlvoY = eu.y + (_rnd.nextDouble() - 0.5) * 160;
        if (_rnd.nextDouble() < 0.4) emote(b.id, emotes[_rnd.nextInt(emotes.length)]);
      } else {
        // vai até a luz mais próxima (com um pouco de distração)
        Luz? melhor;
        var dist = double.infinity;
        for (final l in luzes.values) {
          final (lx, ly) = posicaoLuz(l);
          final d = (lx - b.x).abs() + (ly - b.y).abs() - (l.estrela ? 400 : 0) + _rnd.nextDouble() * 500;
          if (d < dist) {
            dist = d;
            melhor = l;
          }
        }
        if (melhor != null) {
          final (lx, ly) = posicaoLuz(melhor);
          b.botAlvoX = lx;
          b.botAlvoY = ly;
        }
      }
    }
    final dx = b.botAlvoX - b.x, dy = b.botAlvoY - b.y;
    final d = sqrt(dx * dx + dy * dy);
    final vel = velocidadeMax * 0.52;
    final alvoVx = d > 1 ? dx / d * vel : 0.0, alvoVy = d > 1 ? dy / d * vel : 0.0;
    final suav = min(1.0, dt * 3);
    b.vx += (alvoVx - b.vx) * suav;
    b.vy += (alvoVy - b.vy) * suav;
  }

  /// Ranking da rodada (maior pontuação primeiro).
  List<Vagalume> get ranking => jogadores.values.toList()..sort((a, b) => b.pontos.compareTo(a.pontos));

  int posicao(String id) => ranking.indexWhere((j) => j.id == id) + 1;
}
