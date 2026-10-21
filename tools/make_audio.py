#!/usr/bin/env python3
"""自合成音频（无外部素材）：五声音阶古琴/古筝式拨弦 + 环境声 → assets/audio/*.ogg。需要 numpy、ffmpeg。"""
import os, subprocess, numpy as np
R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(R, "assets/audio"); os.makedirs(D, exist_ok=True)
SR = 22050
rng = np.random.default_rng(11)
def hz(m): return 440.0 * 2 ** ((m - 69) / 12)
def pluck(f, dur=3.0, bright=0.5, slide=0.0, amp=0.5):
    n = int(dur * SR); t = np.arange(n) / SR
    fr = f * (1 + slide * np.exp(-t * 6))            # 吟猱：起音轻微滑音
    ph = 2 * np.pi * np.cumsum(fr) / SR
    out = np.zeros(n)
    for k, a in enumerate([1, .55 * bright + .2, .35 * bright, .22 * bright, .12 * bright, .07 * bright], 1):
        out += a * np.sin(k * ph) * np.exp(-t * (1.2 + k * 0.9))
    att = np.minimum(1, t / 0.004)
    noise = rng.standard_normal(n) * np.exp(-t * 60) * 0.15
    return (out * att + noise) * amp
def reverb(x, sec=2.2, wet=0.28):
    n = int(sec * SR); ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * 3.2)
    ir[0] = 0; ir /= np.sqrt((ir ** 2).sum())
    L = len(x) + n; F = 1 << int(np.ceil(np.log2(L)))
    y = np.fft.irfft(np.fft.rfft(x, F) * np.fft.rfft(ir, F), F)[:L]
    return np.concatenate([x, np.zeros(n)]) * (1 - wet) + y * wet
def lowpass_noise(n, k):
    w = rng.standard_normal(n); ker = np.ones(k) / k
    return np.convolve(w, ker, "same")
def loop_render(events, length, amb=None, rev=(2.2, .28)):
    n = int(length * SR); buf = np.zeros(n + SR * 6)
    for (t0, f, d, b, s, a) in events:
        p = pluck(f, d, b, s, a); i = int(t0 * SR); buf[i:i + len(p)] += p
    y = reverb(buf, *rev)
    out = y[:n].copy(); tail = y[n:]
    out[:len(tail)] += tail[:n]                       # 尾音绕回开头，循环无缝
    if amb is not None: out += amb(n)
    return out
def phrase(scale, length, density, octs, rng_seed, bright=.5, amp=.45, dur=3.5, start=0.6):
    r = np.random.default_rng(rng_seed); ev = []; t = start; idx = 2
    while t < length - 1.5:
        idx = int(np.clip(idx + r.choice([-2, -1, -1, 0, 1, 1, 2]), 0, len(scale) * len(octs) - 1))
        o = octs[idx // len(scale)]; m = scale[idx % len(scale)] + 12 * o
        ev.append((t, hz(m), dur, bright, r.choice([0, 0, .012, -.01]), amp * r.uniform(.7, 1)))
        if r.random() < .25: ev.append((t + .09, hz(m - 12), dur, bright * .6, 0, amp * .45))
        t += r.choice(density)
    return ev
def wind(level, k=400):
    def f(n):
        w = lowpass_noise(n, k); env = 0.6 + 0.4 * np.sin(np.linspace(0, 2 * np.pi * 3, n))
        return w / (np.abs(w).max() + 1e-9) * level * env
    return f
def stream(level):
    def f(n):
        w = lowpass_noise(n, 6) - lowpass_noise(n, 60)
        return w / (np.abs(w).max() + 1e-9) * level
    return f
def drips(level):
    def f(n):
        out = np.zeros(n)
        for t0 in np.arange(1.3, n / SR - 1, 2.7):
            i = int((t0 + rng.uniform(-.4, .4)) * SR); d = pluck(hz(rng.choice([88, 91, 93])), .5, .1, .05, level)
            out[i:i + len(d)] += d[:n - i]
        return out + wind(level * .5, 900)(n)
    return f
def drone(level, m):
    def f(n):
        t = np.arange(n) / SR; tr = 0.5 + 0.5 * np.sin(2 * np.pi * t / (n / SR) * 4)
        return level * (np.sin(2 * np.pi * hz(m) * t) + .5 * np.sin(2 * np.pi * hz(m + 7) * t * 1.003)) * (0.6 + 0.4 * tr)
    return f
GONG = [0, 2, 4, 7, 9]; YU = [0, 3, 5, 7, 10]
def write(name, x, q="0"):
    x = x / (np.abs(x).max() + 1e-9) * 0.85
    raw = (x * 32767).astype("<i2").tobytes()
    p = os.path.join(D, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-",
                    "-c:a", "libvorbis", "-q:a", q, p], input=raw, check=True)
    print(name, os.path.getsize(p))
L = 32.0
write("bgm_home", loop_render(phrase([m + 62 for m in GONG], L, [1.0, 1.5, 2.0, 2.0, 3.0], [-1, 0], 1, .45, .42), L, wind(.035)), "-1")
write("bgm_travel", loop_render(phrase([m + 64 for m in GONG], L, [.5, .75, 1.0, 1.0, 1.5], [0, 1], 2, .6, .38, 2.5), L, stream(.05)), "-1")
write("bgm_hantan", loop_render(phrase([m + 57 for m in YU], L, [1.5, 2.0, 3.0, 4.0], [0, 1], 3, .3, .4, 4.5), L, drips(.06), (3.2, .4)), "-1")
write("bgm_xinmo", loop_render(phrase([m + 50 for m in YU], L, [2.0, 3.0, 4.0], [0, 1], 4, .25, .45, 5), L, drone(.05, 38), (3.5, .5)), "-1")
write("bgm_ending", loop_render(phrase([m + 62 for m in GONG], L, [.75, 1.0, 1.5, 2.0], [0, 1], 5, .55, .42, 4), L, wind(.025)), "-1")
def sfx(name, ev, length, rev=(1.0, .2)):
    buf = np.zeros(int(length * SR) + SR * 3)
    for (t0, f, d, b, s, a) in ev:
        p = pluck(f, d, b, s, a); i = int(t0 * SR); buf[i:i + len(p)] += p
    y = reverb(buf, *rev)[:int(length * SR)]
    y *= np.minimum(1, (len(y) - np.arange(len(y))) / (0.15 * SR))
    write(name, y, "1")
sfx("sfx_click", [(0, hz(86), .2, .1, 0, .3)], .25, (.4, .1))
sfx("sfx_pluck", [(0, hz(69), 1.4, .6, .01, .5)], 1.2)
sfx("sfx_good", [(0, hz(67), 1.2, .6, 0, .5), (.16, hz(74), 1.6, .6, 0, .5)], 1.6)
sfx("sfx_bad", [(0, hz(45), 1.2, .3, -.02, .7), (.05, hz(52), 1.0, .2, 0, .3)], 1.2)
def page():
    n = int(.35 * SR); w = lowpass_noise(n, 3) - lowpass_noise(n, 25)
    env = np.exp(-np.abs(np.arange(n) / SR - .08) * 25); return w * env
write("sfx_page", page(), "1")
sfx("sfx_bell", [(0, hz(74), 4, .9, 0, .5), (0, hz(74) * 2.76, 3, .5, 0, .12), (0, hz(81), 4, .4, 0, .25)], 4.0, (3, .45))
