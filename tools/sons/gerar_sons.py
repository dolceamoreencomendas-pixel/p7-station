#!/usr/bin/env python3
"""Gera os sons do P7 Station do zero (síntese), sem nenhuma amostra de terceiros.

Identidade: vidro e ar (leve, macio, com eco curto), lembrando consoles PlayStation
sem copiar nenhum som deles. Rode: python3 gerar_sons.py <pasta de saída>
"""
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, attack=0.004, release=0.05, curve=4.0):
    """Envelope com ataque curto e queda exponencial até o fim."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-curve * t / max(n / SR, 1e-4))
    r = np.clip((n / SR - t) / max(release, 1e-4), 0, 1)
    return a * d * r


def bell(freq, dur, ratio=3.5, index=1.2, decay=5.0, attack=0.003):
    """Sino de FM: timbre de vidro."""
    t = t_axis(dur)
    mod_env = np.exp(-decay * 1.6 * t)
    mod = index * mod_env * np.sin(2 * np.pi * freq * ratio * t)
    car = np.sin(2 * np.pi * freq * t + mod)
    return car * env(len(t), attack=attack, release=0.03, curve=decay)


def pad(freqs, dur, attack=0.5, release=0.6):
    """Acorde macio com leve desafinação (coro)."""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for f in freqs:
        for det in (-0.35, 0.0, 0.35):
            out += np.sin(2 * np.pi * (f + det) * t + np.random.uniform(0, 6.28))
            out += 0.25 * np.sin(2 * np.pi * 2 * (f + det) * t)
    a = np.clip(t / attack, 0, 1) ** 2
    r = np.clip((dur - t) / release, 0, 1) ** 1.5
    return out * a * r / (len(freqs) * 3)


def noise_swish(dur, f_lo, f_hi):
    """Sopro de ar filtrado que sobe de f_lo a f_hi."""
    n = int(SR * dur)
    x = np.random.normal(0, 1, n)
    out = np.zeros(n)
    y1 = y2 = 0.0
    for i in range(n):
        f = f_lo + (f_hi - f_lo) * (i / n)
        w = 2 * np.pi * f / SR
        q = 4.0
        alpha = np.sin(w) / (2 * q)
        b0 = alpha
        a0 = 1 + alpha
        a1 = -2 * np.cos(w)
        a2 = 1 - alpha
        y = (b0 * x[i] - b0 * (x[i - 2] if i >= 2 else 0) - a1 * y1 - a2 * y2) / a0
        y2, y1 = y1, y
        out[i] = y
    return out * np.sin(np.pi * np.arange(n) / n) ** 2


def reverb(x, wet=0.25, room=0.82, damp=0.35, tail=0.6):
    """Eco de sala simples (Schroeder): 4 pentes em paralelo + 2 passa-tudo."""
    out_len = len(x) + int(SR * tail)
    x = np.concatenate([x, np.zeros(out_len - len(x))])
    combs = [1557, 1617, 1491, 1422]
    acc = np.zeros(out_len)
    for d in combs:
        buf = np.zeros(out_len)
        lp = 0.0
        for i in range(out_len):
            fb = buf[i - d] if i >= d else 0.0
            lp = fb * (1 - damp) + lp * damp
            buf[i] = x[i] + lp * room
        acc += buf
    acc /= len(combs)
    for d, g in ((556, 0.5), (441, 0.5)):
        y = np.zeros(out_len)
        for i in range(out_len):
            xd = acc[i - d] if i >= d else 0.0
            yd = y[i - d] if i >= d else 0.0
            y[i] = -g * acc[i] + xd + g * yd
        acc = y
    return x * (1 - wet) + acc * wet


def place(total, *parts):
    """Soma partes (início em s, sinal) num buffer."""
    n = int(SR * total)
    out = np.zeros(n)
    for start, sig in parts:
        i = int(SR * start)
        j = min(n, i + len(sig))
        out[i:j] += sig[: j - i]
    return out


def finish(x, peak_db=-3.0, fade=0.004):
    x = x - np.mean(x)
    peak = np.max(np.abs(x)) or 1.0
    x = x / peak * (10 ** (peak_db / 20))
    f = int(SR * fade)
    if f:
        x[:f] *= np.linspace(0, 1, f)
        x[-f:] *= np.linspace(1, 0, f)
    return x


def save(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main(out_dir):
    np.random.seed(7)
    out = Path(out_dir)
    out.mkdir(parents=True, exist_ok=True)

    # navegar: clique de vidro bem curto e macio
    tick = place(0.05, (0, bell(2093, 0.05, ratio=2.0, index=0.6, decay=14) * 0.9),
                 (0, noise_swish(0.012, 3000, 6000) * 0.08))
    save(out / "move.wav", finish(reverb(tick, wet=0.12, tail=0.08), peak_db=-9))

    # trocar de aba: sopro curto subindo + nota
    sw = noise_swish(0.11, 600, 2600) * 0.5
    sw = place(0.14, (0, sw), (0.02, bell(1175, 0.11, ratio=2, index=0.5, decay=9) * 0.5))
    save(out / "tab.wav", finish(reverb(sw, wet=0.18, tail=0.15), peak_db=-8))

    # confirmar: duas notas subindo (Mi, Si), vidro
    c = place(0.45, (0, bell(1319, 0.32, decay=7)), (0.06, bell(1976, 0.36, decay=7) * 0.85))
    save(out / "confirm.wav", finish(reverb(c, wet=0.22, tail=0.3), peak_db=-6))

    # voltar: duas notas descendo, mais graves e macias
    b = place(0.38, (0, bell(988, 0.26, ratio=2, index=0.8, decay=8)), (0.06, bell(659, 0.3, ratio=2, index=0.7, decay=8) * 0.9))
    save(out / "back.wav", finish(reverb(b, wet=0.2, tail=0.25), peak_db=-7))

    # aviso: duas notas graves iguais, curtas
    n = place(0.42, (0, bell(392, 0.18, ratio=1.5, index=1.0, decay=10)), (0.17, bell(392, 0.22, ratio=1.5, index=1.0, decay=10)))
    save(out / "notice.wav", finish(reverb(n, wet=0.15, tail=0.2), peak_db=-6))

    # controle conectado / desconectado: três notas subindo / descendo
    up = place(0.36, (0, bell(1047, 0.16, decay=10)), (0.07, bell(1319, 0.16, decay=10)), (0.14, bell(1568, 0.22, decay=8)))
    save(out / "pad-on.wav", finish(reverb(up, wet=0.2, tail=0.25), peak_db=-7))
    dn = place(0.36, (0, bell(784, 0.16, decay=10)), (0.07, bell(659, 0.16, decay=10)), (0.14, bell(523, 0.22, decay=8)))
    save(out / "pad-off.wav", finish(reverb(dn, wet=0.2, tail=0.25), peak_db=-8))

    # abrir jogo: acorde que cresce e um brilho por cima
    p = pad([110, 164.8, 220, 277.2], 1.3, attack=0.45, release=0.7) * 0.9
    shimmer = place(1.3, (0.35, bell(1760, 0.6, decay=4) * 0.35), (0.45, bell(2217, 0.6, decay=4) * 0.3),
                    (0.55, bell(2637, 0.7, decay=4) * 0.3))
    whoosh = place(1.3, (0.0, noise_swish(0.6, 300, 3000) * 0.25))
    save(out / "launch.wav", finish(reverb(p + shimmer + whoosh, wet=0.3, tail=0.8), peak_db=-4))

    # abertura do app: grave que nasce, depois um acorde de cristal que se abre com eco longo
    t = t_axis(2.4)
    sub = (np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 110 * t)) * np.clip(t / 0.9, 0, 1) ** 2 * np.exp(-1.4 * np.clip(t - 1.0, 0, None))
    body = pad([220, 329.6, 440, 554.4], 2.4, attack=0.9, release=1.2) * 0.8
    crystal = place(2.4, (0.85, bell(1760, 1.4, ratio=3.5, index=0.9, decay=2.5) * 0.4),
                    (0.92, bell(2637, 1.3, ratio=3.5, index=0.8, decay=2.6) * 0.32),
                    (0.99, bell(3520, 1.2, ratio=3.5, index=0.7, decay=2.8) * 0.25))
    rise = place(2.4, (0.0, noise_swish(0.9, 200, 4000) * 0.18))
    save(out / "boot.wav", finish(reverb(sub * 0.7 + body + crystal + rise, wet=0.35, room=0.86, tail=1.2), peak_db=-3))

    # encaixe da mídia na base: estalo curto de plástico, um "tum" grave e o bipe da luz acendendo
    n = int(SR * 0.018)
    click = np.random.normal(0, 1, n) * np.exp(-np.arange(n) / (SR * 0.004))
    click = np.convolve(click, np.ones(6) / 6, mode="same")
    tt = t_axis(0.16)
    thunk = np.sin(2 * np.pi * (140 - 60 * tt / 0.16) * tt) * np.exp(-tt * 34)
    blip = bell(2349, 0.22, ratio=2.0, index=0.4, decay=9) * 0.35
    ins = place(0.42, (0, click * 0.9), (0.004, thunk * 0.8), (0.09, blip))
    save(out / "insert.wav", finish(reverb(ins, wet=0.16, tail=0.2), peak_db=-5))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
