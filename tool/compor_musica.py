"""Compõe a música de fundo do Fica Sóbrio: lo-fi ambiente calmo, em loop perfeito.

Tudo sintetizado aqui (sem amostras de terceiros): piano elétrico FM, pad de acordes,
contrabaixo, sininhos e uma escovinha bem baixinha. Fá maior, 72 bpm, 16 compassos.
"""
import sys
import numpy as np

SR = 44100
BPM = 72
BEAT = 60 / BPM
COMPASSOS = 16
L = int(round(COMPASSOS * 4 * BEAT * SR))  # duração exata do loop
CAUDA = int(4 * SR)                          # sobra para notas/reverb que passam do fim
rng = np.random.default_rng(7)
mix = np.zeros((L + CAUDA, 2))


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def env_adsr(n, a, d, s, r_start, r):
    """Envelope: ataque a, decaimento d até s, sustain até r_start, release r (em amostras)."""
    e = np.ones(n) * s
    a = max(1, a)
    e[:a] = np.linspace(0, 1, a)
    dd = min(d, n - a)
    e[a:a + dd] = np.linspace(1, s, dd) if dd > 0 else e[a:a + dd]
    if r_start < n:
        rr = np.exp(-np.arange(n - r_start) / max(1, r))
        e[r_start:] = e[r_start] * rr if r_start > 0 else rr
    return e


def colocar(sinal, t0, pan=0.0, ganho=1.0):
    i = int(t0 * SR)
    n = min(len(sinal), len(mix) - i)
    if n <= 0:
        return
    esq = np.cos((pan + 1) * np.pi / 4)
    dir_ = np.sin((pan + 1) * np.pi / 4)
    mix[i:i + n, 0] += sinal[:n] * ganho * esq
    mix[i:i + n, 1] += sinal[:n] * ganho * dir_


def rhodes(midi, dur, vel):
    """Piano elétrico por FM (tine + corpo), timbre macio."""
    n = int((dur + 2.5) * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    idx = (1.2 + 1.8 * vel) * np.exp(-t * 3.0)
    corpo = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    tine = 0.18 * vel * np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 18)
    e = np.exp(-t * 1.1) * np.minimum(1, t * 400)
    corte = int(dur * SR)
    e[corte:] *= np.exp(-np.arange(n - corte) / (0.35 * SR))
    tremolo = 1 + 0.08 * np.sin(2 * np.pi * 4.2 * t)
    return (corpo + tine) * e * tremolo * vel


def pad(midis, dur):
    """Colchão de acordes: senos levemente desafinados, ataque e release lentos."""
    n = int((dur + 3) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in midis:
        f = hz(m)
        for det in (-0.12, 0.0, 0.11):
            fx = f * 2 ** (det / 12)
            s += np.sin(2 * np.pi * fx * t + rng.uniform(0, 6.28)) + 0.18 * np.sin(4 * np.pi * fx * t)
    e = env_adsr(n, int(1.6 * SR), 0, 1.0, int(dur * SR), int(1.2 * SR))
    return s * e / (len(midis) * 3)


def baixo(midi, dur):
    n = int((dur + 1) * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) + 0.08 * np.sin(6 * np.pi * f * t)
    e = env_adsr(n, int(0.02 * SR), int(0.4 * SR), 0.7, int(dur * SR), int(0.25 * SR))
    return s * e


def sino(midi, vel):
    n = int(4 * SR)
    t = np.arange(n) / SR
    f = hz(midi)
    s = np.sin(2 * np.pi * f * t + 1.5 * np.exp(-t * 2) * np.sin(2 * np.pi * f * 3.5 * t))
    return s * np.exp(-t * 1.4) * np.minimum(1, t * 300) * vel


def escova(vel):
    n = int(0.25 * SR)
    ruido = rng.standard_normal(n)
    ruido = np.diff(ruido, prepend=0)  # tira os graves (fica "chiado" de escovinha)
    return ruido * np.exp(-np.arange(n) / (0.05 * SR)) * vel


# ---------------- Harmonia: Fmaj9 | Dm9 | Bbmaj9 | C6/9sus (x4, com variação) ----------------
acordes = [
    (41, [57, 60, 64, 67]),   # F  : A C E G  (Fmaj9 sem a fundamental no pad)
    (38, [57, 60, 64, 65]),   # Dm9: A C E F
    (46, [57, 62, 65, 69]),   # Bbmaj9: A D F A
    (36, [55, 60, 62, 67]),   # C6/9sus: G C D G
]
pentatonica = [65, 67, 69, 72, 74, 76, 77, 79, 81]  # Fá maior pentatônica (com 4ª)

compasso = 4 * BEAT
for c in range(COMPASSOS):
    raiz, notas = acordes[c % 4]
    t0 = c * compasso
    volta = c // 4
    # pad (entra mais cheio a partir da 2ª volta)
    colocar(pad(notas, compasso * 0.98), t0, pan=0.0, ganho=0.55 if volta == 0 else 0.7)
    # baixo: tônica no tempo 1 e quinta suave no 3
    colocar(baixo(raiz, BEAT * 2.2), t0, ganho=0.55)
    colocar(baixo(raiz + 7, BEAT * 1.6), t0 + 2 * BEAT, ganho=0.35)
    # piano: arpejo em colcheias, com humanização de tempo e força
    arpejo = [notas[0], notas[2], notas[1], notas[3], notas[2], notas[1], notas[3], notas[2]]
    for k, nota in enumerate(arpejo):
        if volta == 0 and k % 2 == 1:
            continue  # primeira volta mais vazia
        if rng.random() < 0.12:
            continue
        tt = t0 + k * BEAT / 2 + rng.normal(0, 0.012) + (0.03 if k % 2 else 0)  # leve swing
        vel = 0.55 + 0.25 * rng.random() - (0.15 if k % 2 else 0)
        colocar(rhodes(nota, BEAT * 0.45, vel), max(0, tt), pan=rng.uniform(-0.35, 0.35), ganho=0.42)
    # sininhos: melodia esparsa nas voltas 2 a 4
    if volta >= 1:
        for k in range(2):
            if rng.random() < 0.6:
                tt = t0 + rng.choice([0.5, 1.5, 2.5, 3.0]) * BEAT + k * 2 * BEAT
                colocar(sino(int(rng.choice(pentatonica)) + 12, 0.5), tt, pan=rng.uniform(-0.7, 0.7), ganho=0.16)
    # escovinha bem baixa nos contratempos (a partir da 3ª volta)
    if volta >= 2:
        for k in range(4):
            colocar(escova(0.5 + 0.3 * rng.random()), t0 + (k + 0.5) * BEAT, pan=0.3, ganho=0.035)

# ---------------- Loop perfeito: dobra a cauda de volta no começo ----------------
seca = mix.copy()

# reverb (resposta ao impulso de ruído com decaimento de 2,8 s, um pouco diferente em cada canal)
n_ir = int(2.8 * SR)
t_ir = np.arange(n_ir) / SR
saida = np.zeros_like(seca)
for ch in range(2):
    ir = rng.standard_normal(n_ir) * np.exp(-t_ir * 2.3)
    ir[: int(0.012 * SR)] = 0  # pré-delay
    # escurece a reverb
    espectro = np.fft.rfft(ir)
    fr = np.fft.rfftfreq(n_ir, 1 / SR)
    espectro *= 1 / (1 + (fr / 3500) ** 2)
    ir = np.fft.irfft(espectro, n_ir)
    ir /= np.sqrt(np.sum(ir ** 2))
    tam = 1 << int(np.ceil(np.log2(len(seca) + n_ir)))
    molhada = np.fft.irfft(np.fft.rfft(seca[:, ch], tam) * np.fft.rfft(ir, tam), tam)[: len(seca)]
    saida[:, ch] = seca[:, ch] * 0.78 + molhada * 0.55

# a cauda (notas e reverb que passaram do fim) volta para o início
loop = saida[:L].copy()
loop[:CAUDA] += saida[L:L + CAUDA]

# calor: corta agudos acima de ~6 kHz e graves abaixo de 35 Hz (filtro no domínio da frequência, circular = sem emenda)
for ch in range(2):
    esp = np.fft.rfft(loop[:, ch])
    fr = np.fft.rfftfreq(L, 1 / SR)
    esp *= 1 / np.sqrt(1 + (fr / 6000) ** 4)
    esp *= 1 / np.sqrt(1 + (35 / np.maximum(fr, 1e-3)) ** 4)
    loop[:, ch] = np.fft.irfft(esp, L)

# volume: RMS -22 dBFS (baixinho, igual à anterior), pico no máximo -3 dBFS
loop *= 10 ** (-22 / 20) / np.sqrt(np.mean(loop ** 2))
pico = np.abs(loop).max()
if pico > 10 ** (-3 / 20):
    loop *= 10 ** (-3 / 20) / pico

print(f"duração {L / SR:.2f}s  rms {20 * np.log10(np.sqrt(np.mean(loop ** 2))):.1f} dBFS  "
      f"pico {20 * np.log10(np.abs(loop).max()):.1f} dBFS  "
      f"emenda {np.abs(loop[-1] - loop[0]).max():.4f}")
loop.astype(np.float32).tofile(sys.argv[1])
