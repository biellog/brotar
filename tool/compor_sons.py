"""Sintetiza os efeitos sonoros do Império do Suco (tycoon). Tudo original, sem amostras.

Uso: python3 tool/compor_sons.py <pasta de saída>   (gera .wav; o ffmpeg converte para .ogg)
"""
import sys
import wave

import numpy as np

SR = 44100
rng = np.random.default_rng(42)


def t(seg):
    return np.arange(int(seg * SR)) / SR


def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)


def env(x, ataque=0.003, decai=8.0):
    tt = np.arange(len(x)) / SR
    return x * np.minimum(1, tt / ataque) * np.exp(-tt * decai)


def sino(f, dur, decai=6.0, brilho=1.0):
    """Sino/moeda por FM: metálico e limpo."""
    tt = t(dur)
    mod = brilho * np.exp(-tt * 10) * np.sin(2 * np.pi * f * 2.76 * tt)
    return env(np.sin(2 * np.pi * f * tt + mod) + 0.3 * np.sin(2 * np.pi * f * 4.1 * tt) * np.exp(-tt * 20), 0.002, decai)


def colocar(dest, sinal, inicio):
    i = int(inicio * SR)
    n = min(len(sinal), len(dest) - i)
    dest[i:i + n] += sinal[:n]


def ruido_agudo(dur, decai):
    r = np.diff(rng.standard_normal(int(dur * SR) + 1))
    return env(r, 0.001, decai)


def normalizar(x, pico_db=-1.5):
    x = x - np.mean(x)
    fade = int(0.004 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (10 ** (pico_db / 20) / (np.abs(x).max() + 1e-9))


def salvar(nome, x, pasta):
    x = normalizar(x)
    with wave.open(f"{pasta}/{nome}.wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def moeda():
    """'Plim' de duas notas subindo (Mi6 → Si6)."""
    x = np.zeros(int(0.35 * SR))
    colocar(x, sino(hz(88), 0.3, 14, 0.8), 0)
    colocar(x, sino(hz(95), 0.3, 10, 0.8) * 0.9, 0.055)
    return x


def caixa():
    """'Ka-ching': clique da gaveta + acorde de sino brilhante."""
    x = np.zeros(int(0.9 * SR))
    clique = ruido_agudo(0.05, 60) * 0.6
    tt = t(0.05)
    clique += env(np.sin(2 * np.pi * 180 * tt), 0.001, 70) * 0.8  # "ka" grave da gaveta
    colocar(x, clique, 0)
    for k, m in enumerate([91, 95, 98, 103]):  # Sol6 Si6 Ré7 Sol7
        colocar(x, sino(hz(m), 0.8, 4.5, 1.2) * (0.7 - 0.1 * k), 0.07 + 0.012 * k)
    return x


def compra():
    """'Pop' curto: seno caindo de tom + estalinho."""
    tt = t(0.12)
    f = 900 * np.exp(-tt * 25) + 220
    fase = 2 * np.pi * np.cumsum(f) / SR
    x = env(np.sin(fase), 0.001, 30)
    x[: int(0.01 * SR)] += ruido_agudo(0.01, 300) * 0.3
    return x


def marco():
    """Arpejo alegre subindo (Dó maior) com brilho no fim."""
    x = np.zeros(int(0.8 * SR))
    for k, m in enumerate([72, 76, 79, 84]):
        tt = t(0.35)
        f = hz(m)
        tom = np.sin(2 * np.pi * f * tt) + 0.35 * np.sin(2 * np.pi * 2 * f * tt) + 0.15 * np.sin(2 * np.pi * 3 * f * tt)
        colocar(x, env(tom, 0.004, 7) * 0.8, k * 0.075)
    colocar(x, sino(hz(96), 0.5, 6) * 0.5, 0.3)
    return x


def gerente():
    """Fanfarra curta de 'metais' (harmônicos de dente de serra suavizados)."""
    x = np.zeros(int(1.0 * SR))

    def metal(midi, dur, vol):
        tt = t(dur)
        f = hz(midi)
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * tt)
        s = sum(np.sin(2 * np.pi * f * h * vib * tt) / h ** 1.2 for h in range(1, 9))
        a = np.minimum(1, tt / 0.03)
        r = np.ones_like(tt)
        cauda = int(0.12 * SR)
        r[-cauda:] = np.linspace(1, 0, cauda)
        return s * a * r * vol

    for midi in (67, 71, 74):  # Sol maior curto
        colocar(x, metal(midi, 0.14, 0.5), 0)
    for midi in (72, 76, 79, 84):  # Dó maior longo
        colocar(x, metal(midi, 0.55, 0.45), 0.17)
    return x


def filial():
    """Brilho subindo: varredura com cintilação + acorde final."""
    dur = 1.3
    tt = t(dur)
    f = 300 * 2 ** (tt / dur * 3)
    fase = 2 * np.pi * np.cumsum(f) / SR
    var = np.sin(fase) * np.minimum(1, tt / 0.2) * (1 - tt / dur) * 0.5
    x = var.copy()
    for k in range(14):
        colocar(x, sino(hz(84 + (k * 5) % 24), 0.4, 9, 0.6) * 0.25, 0.05 + k * 0.07)
    for m in (84, 88, 91, 96):
        colocar(x, sino(hz(m), 0.9, 3.5, 0.7) * 0.4, 0.95)
    return np.concatenate([x, np.zeros(int(0.6 * SR))])


def toque():
    """Clique suave de botão."""
    tt = t(0.04)
    return env(np.sin(2 * np.pi * 1500 * tt) * 0.6 + np.sin(2 * np.pi * 750 * tt), 0.0005, 120)


if __name__ == "__main__":
    pasta = sys.argv[1]
    for nome, fn in [("ty_moeda", moeda), ("ty_caixa", caixa), ("ty_compra", compra), ("ty_marco", marco),
                     ("ty_gerente", gerente), ("ty_filial", filial), ("ty_toque", toque)]:
        salvar(nome, fn(), pasta)
        print(nome)
