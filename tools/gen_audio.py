#!/usr/bin/env python3
"""產生《落閘》所有音效、音樂、架空語音音節。輸出到 audio/。需要 numpy 與 ffmpeg。"""
import numpy as np, wave, os, subprocess, sys
SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
rng = np.random.default_rng(7)

def t(d, sr=SR): return np.arange(int(d * sr)) / sr
def env(n, a=0.005, r=0.1, sr=SR, curve=3.0):
    x = np.ones(n); na = max(1, int(a * sr)); x[:na] = np.linspace(0, 1, na)
    tt = np.arange(n) / sr; return x * np.exp(-tt * curve / max(r, 1e-3))
def noise(n): return rng.uniform(-1, 1, n)
def lp(x, k):
    y = np.empty_like(x); a = 0.0
    for i in range(len(x)):
        a += k * (x[i] - a); y[i] = a
    return y
def hp(x, k): return x - lp(x, k)
def norm(x, peak=0.9):
    m = np.max(np.abs(x)) or 1; return x / m * peak
def save(name, x, sr=SR, peak=0.9):
    x = norm(np.asarray(x, dtype=np.float64), peak)
    p = os.path.join(OUT, name + ".wav")
    with wave.open(p, "wb") as w:
        if x.ndim == 2: w.setnchannels(2)
        else: w.setnchannels(1)
        w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    return p
def to_ogg(name, q=4):
    p = os.path.join(OUT, name + ".wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-c:a", "libvorbis", "-q:a", str(q), os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(p)
def sweep(f0, f1, d):
    tt = t(d); f = f0 * (f1 / f0) ** (tt / d); return np.sin(2 * np.pi * np.cumsum(f) / SR)
def ring(freqs, d, decay=6):
    tt = t(d); return sum(np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * np.exp(-tt * decay * (1 + i * 0.3)) / (1 + i * 0.4) for i, f in enumerate(freqs))
def pad(x, n):
    return np.concatenate([x, np.zeros(max(0, n - len(x)))])[:n] if n else x
def mix(*xs):
    n = max(len(x) for x in xs); return sum(pad(x, n) for x in xs)

def sfx():
    n = int(.22 * SR); save("swing", hp(lp(noise(n), .25), .05) * np.sin(np.pi * np.arange(n) / n) ** 2, peak=.5)
    n = int(.4 * SR); save("swing_heavy", lp(noise(n), .12) * np.sin(np.pi * np.arange(n) / n) ** 3 + .3 * sweep(160, 60, .4) * np.sin(np.pi * np.arange(n) / n) ** 2, peak=.7)
    n = int(.25 * SR); save("hit_flesh", lp(noise(n), .2) * env(n, .001, .06, curve=4) + sweep(140, 50, .25) * env(n, .001, .08))
    n = int(.3 * SR); save("splat", lp(noise(n), .35) * env(n, .001, .09) * (1 + .6 * np.sin(2 * np.pi * 31 * t(.3))) + .5 * sweep(90, 40, .3) * env(n, .001, .1))
    save("hit_block", ring([310, 820, 1270, 2140], .3, 14) + .5 * noise(int(.3 * SR)) * env(int(.3 * SR), .001, .02))
    save("parry", ring([1480, 2217, 2960, 4435, 5920], .9, 5) + .6 * hp(noise(int(.9 * SR)), .5) * env(int(.9 * SR), .001, .03))
    save("deflect", ring([2100, 3150, 5230], .5, 9) + sweep(3000, 900, .5) * env(int(.5 * SR), .001, .08) * .4)
    def shot(d, body, crack, tail):
        n = int(d * SR); return noise(n) * env(n, .0005, crack, curve=4) + lp(noise(n), .08) * env(n, .001, tail) * 1.2 + sweep(body, 40, d) * env(n, .001, .09) * 1.4
    save("shot_revolver", shot(.7, 220, .02, .25)); save("shot_shotgun", shot(1.0, 150, .04, .4)); save("shot_rifle", shot(.9, 300, .012, .35))
    n = int(.25 * SR); save("shot_air", hp(noise(n), .3) * env(n, .001, .04) + ring([900, 1900], .25, 20) * .6)
    n = int(.4 * SR); save("thump", sweep(180, 50, .4) * env(n, .002, .12) + lp(noise(n), .1) * env(n, .001, .05) * .5)
    n = int(1.6 * SR); save("explosion", lp(noise(n), .06) * env(n, .001, .5, curve=3) * 1.5 + sweep(90, 25, 1.6) * env(n, .001, .5) + noise(n) * env(n, .0005, .03))
    def click(f, d=.05): return ring([f, f * 2.3, f * 3.9], d, 60) + noise(int(d * SR)) * env(int(d * SR), .0005, .008) * .6
    save("click", click(1200)); save("ui", click(2200, .04), peak=.4)
    save("reload", np.concatenate([click(700, .12), np.zeros(int(.12 * SR)), click(1100, .1), np.zeros(int(.1 * SR)), click(500, .15)]))
    save("lever", np.concatenate([click(900, .08), np.zeros(int(.05 * SR)), click(600, .1)]))
    n = int(.3 * SR); save("dodge", hp(lp(noise(n), .3), .08) * np.sin(np.pi * np.arange(n) / n) ** 2, peak=.4)
    n = int(.12 * SR); save("step", lp(noise(n), .12) * env(n, .001, .03), peak=.35)
    n = int(.14 * SR); save("step_water", hp(lp(noise(n * 2), .4), .1) * env(n * 2, .005, .06), peak=.4)
    save("break", ring([180, 420, 610, 990], 1.0, 4) + lp(noise(int(1.0 * SR)), .2) * env(int(1.0 * SR), .001, .1) + sweep(400, 60, 1.0) * env(int(1.0 * SR), .001, .2))
    save("ding", ring([2637, 5274, 7911], .6, 8), peak=.5)
    save("ratchet", np.concatenate([click(1500 + 80 * i, .035) for i in range(7)]), peak=.6)
    save("disarm", np.concatenate([click(800, .06), ring([520, 1310, 2050, 3300], .7, 6) + noise(int(.7 * SR)) * env(int(.7 * SR), .001, .03)]))
    n = int(.9 * SR); save("warn", (np.sin(2 * np.pi * 55 * t(.9)) + .6 * np.sin(2 * np.pi * 82.4 * t(.9)) + .3 * np.sign(np.sin(2 * np.pi * 27.5 * t(.9)))) * np.sin(np.pi * np.arange(n) / n) ** .5)
    n = int(.9 * SR); g = np.zeros(n)
    for i in range(3): s = int((.1 + i * .25) * SR); m = int(.2 * SR); g[s:s + m] += sweep(220, 120, .2) * env(m, .02, .08) + lp(noise(m), .2) * env(m, .02, .06) * .5
    save("drink", g, peak=.5)
    n = int(.8 * SR); hb = np.zeros(n)
    for s0 in (0, .25): s = int(s0 * SR); m = int(.2 * SR); hb[s:s + m] += sweep(70, 40, .2) * env(m, .005, .06)
    save("heartbeat", hb)
    n = int(3.0 * SR); save("gate", lp(noise(n), .03) * np.sin(np.pi * np.arange(n) / n) ** .4 * (1 + .5 * np.sin(2 * np.pi * 7 * t(3.0))) + .5 * ring([62, 93, 141, 187], 3.0, .8) + pad(np.zeros(int(2.4 * SR)), 0).sum(), peak=.9)
    save("boom", sweep(70, 28, 2.2) * env(int(2.2 * SR), .002, .7, curve=2.5) * 1.5 + lp(noise(int(2.2 * SR)), .04) * env(int(2.2 * SR), .001, .3) + ring([98, 147, 196], 2.2, 1.5) * .4)
    n = int(2.0 * SR); bz = sum(np.sign(np.sin(2 * np.pi * (f + 6 * np.sin(2 * np.pi * rng.uniform(3, 9) * t(2.0))) * t(2.0))) for f in (190, 213, 236, 251)); save("bees", lp(bz, .25) * (0.7 + .3 * np.sin(2 * np.pi * 2 * t(2.0))), peak=.35)
    n = int(.35 * SR); save("hook", hp(noise(n), .4) * env(n, .001, .03) + sweep(1800, 500, .35) * env(n, .001, .12) * .7)
    n = int(.6 * SR); save("saw", np.sign(np.sin(2 * np.pi * np.cumsum(np.linspace(300, 900, n)) / SR)) * .5 * np.sin(np.pi * np.arange(n) / n) + hp(noise(n), .4) * .3 * np.sin(np.pi * np.arange(n) / n))
    n = int(.5 * SR); save("zap", np.sign(np.sin(2 * np.pi * 110 * t(.5))) * (rng.uniform(0, 1, n) > .35) * env(n, .001, .2) + hp(noise(n), .5) * env(n, .001, .1))
    n = int(.25 * SR); save("hammer", ring([640, 1530, 2480, 3900], .5, 9)[:int(.5 * SR)] , peak=.8)
    n = int(1.4 * SR); save("hiss", hp(noise(n), .35) * env(n, .01, .5, curve=2.5), peak=.5)
    n = int(.5 * SR); save("smoke", lp(noise(n), .2) * env(n, .02, .2), peak=.5)
    n = int(.4 * SR); save("hurt", lp(noise(n), .15) * env(n, .001, .08) + sweep(200, 70, .4) * env(n, .001, .12) + ring([3800], .4, 5) * .15)
    n = int(.3 * SR); save("plate", ring([240, 610, 1180], .5, 8) + noise(int(.5 * SR)) * env(int(.5 * SR), .001, .03) * .6)
    n = int(.3 * SR); save("card", hp(lp(noise(n), .5), .2) * env(n, .001, .05), peak=.5)
    n = int(.5 * SR); save("pickup", ring([880, 1320, 1760], .5, 7), peak=.5)
    # 迴圈環境音
    n = int(6 * SR); w = lp(noise(n), .02) * 2 + lp(noise(n), .2) * .15 * (1 + np.sin(2 * np.pi * .3 * t(6)))
    f = int(.5 * SR); w[:f] = w[:f] * np.linspace(0, 1, f) + w[-f:] * np.linspace(1, 0, f); save("amb_wind", w[:-f], peak=.5); to_ogg("amb_wind")
    n = int(6 * SR); c = np.zeros(n)
    for _ in range(60):
        s = rng.integers(0, n - SR); d = rng.uniform(.2, .7); m = int(d * SR); f0 = rng.uniform(110, 260)
        c[s:s + m] += lp(np.sign(np.sin(2 * np.pi * f0 * (1 + .1 * np.sin(2 * np.pi * rng.uniform(2, 6) * t(d))) * t(d))), .15)[:m] * np.sin(np.pi * np.arange(m) / m) * rng.uniform(.2, 1)
    c = lp(c, .2) + lp(noise(n), .03) * 3; c[:f] = c[:f] * np.linspace(0, 1, f) + c[-f:] * np.linspace(1, 0, f); save("amb_crowd", c[:-f], peak=.5); to_ogg("amb_crowd")
    n = int(5 * SR); w = hp(lp(noise(n), .5), .05) * (0.6 + .4 * lp(noise(n), .001) * 20)
    for _ in range(14):
        s = rng.integers(0, n - 4000); w[s:s + 3000] += ring([rng.uniform(900, 2400)], 3000 / SR, 25) * .8
    w[:f] = w[:f] * np.linspace(0, 1, f) + w[-f:] * np.linspace(1, 0, f); save("amb_water", w[:-f], peak=.5); to_ogg("amb_water")
    n = int(4 * SR); fr = lp(noise(n), .05) * (1 + .5 * lp(noise(n), .002) * 30) + hp(noise(n), .6) * .1 * (rng.uniform(0, 1, n) > .997).astype(float) * 30
    fr[:f] = fr[:f] * np.linspace(0, 1, f) + fr[-f:] * np.linspace(1, 0, f); save("amb_fire", fr[:-f], peak=.4); to_ogg("amb_fire")

def voices():
    # 架空語言：每個角色 10 個音節。參數：基頻、音節長、共鳴、氣聲、粗糙度
    V = {"pc": (150, .13, 1.0, .1, .1), "bao": (88, .19, .85, .15, .5), "xue": (190, .09, 1.15, .1, .1), "ruan": (210, .22, 1.05, .35, .2),
         "ge": (165, .15, 1.2, .05, 0), "zha": (100, .21, .9, .3, .3), "laba": (260, .12, 1.3, .1, .45)}
    vow = [(730, 1090), (270, 2290), (300, 870), (530, 1840), (570, 840), (440, 1020), (660, 1720), (390, 1990), (490, 1350), (640, 1190)]
    for name, (f0, d, fm, breath, rough) in V.items():
        for i, (f1, f2) in enumerate(vow):
            dd = d * rng.uniform(.8, 1.3); n = int(dd * SR); tt = t(dd)
            pitch = f0 * (1 + rng.uniform(-.12, .12) + rng.uniform(-.15, .15) * tt / dd)
            ph = 2 * np.pi * np.cumsum(pitch) / SR
            src = sum(np.sin(ph * k) / k for k in range(1, 18))
            if rough: src *= 1 + rough * np.sign(np.sin(ph * .5))
            y = sum(np.convolve(src, np.sin(2 * np.pi * f * fm * t(.012)) * np.exp(-t(.012) * 380), "same") * g for f, g in ((f1, 1), (f2, .6), (2700, .25)))
            y = norm(y) + breath * hp(noise(n), .3)
            e = np.sin(np.pi * np.arange(n) / n) ** .6
            if i % 3 == 0:  # 子音爆破
                cn = int(.025 * SR); y[:cn] += hp(noise(cn), .4) * np.linspace(1, 0, cn) * .9
            if i % 4 == 1:
                cn = int(.05 * SR); y[:cn] = hp(noise(cn), .6) * .5; e[:cn] = 1
            save(f"v_{name}_{i}", y * e, peak=.7)

# ---------- 音樂 ----------
MSR = 32000
def ks(freq, d, damp=.996, bright=.5, sr=MSR):
    n = int(d * sr); p = max(2, int(sr / freq)); buf = rng.uniform(-1, 1, p)
    buf = buf * bright + np.convolve(buf, np.ones(4) / 4, "same") * (1 - bright)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % p]; buf[i % p] = damp * .5 * (buf[i % p] + buf[(i + 1) % p])
    return out
def mt(d): return np.arange(int(d * MSR)) / MSR
def note(m): return 440 * 2 ** ((m - 69) / 12)
def place(buf, x, at, gain=1.0, pan=.5):
    s = int(at * MSR) % len(buf)
    for ch, g in ((0, np.sqrt(1 - pan)), (1, np.sqrt(pan))):
        e = min(len(buf), s + len(x)); buf[s:e, ch] += x[:e - s] * gain * g
        if e - s < len(x): r = len(x) - (e - s); r = min(r, len(buf)); buf[:r, ch] += x[e - s:e - s + r] * gain * g
def echo(buf, delay, fb=.4, n=4):
    out = buf.copy(); d = int(delay * MSR)
    for i in range(1, n + 1):
        sh = np.roll(buf, d * i, axis=0)
        if i % 2: sh = sh[:, ::-1]
        out += sh * fb ** i
    return out
def lp2(x, k):
    y = np.empty_like(x); a = 0.0
    for i in range(len(x)): a += k * (x[i] - a); y[i] = a
    return y
def padtone(freqs, d, k=.03):
    tt = mt(d); x = sum(np.sin(2 * np.pi * f * tt * (1 + .002 * j) + rng.uniform(0, 6)) for f in freqs for j in (-1, 0, 1))
    n = len(tt); f = int(min(d * .4, 2.5) * MSR); e = np.ones(n); e[:f] = np.linspace(0, 1, f); e[-f:] = np.linspace(1, 0, f); return x * e
def kick(d=.35): tt = mt(d); return np.sin(2 * np.pi * np.cumsum(45 + 90 * np.exp(-tt * 30)) / MSR) * np.exp(-tt * 9)
def rim(): tt = mt(.06); return (np.sin(2 * np.pi * 1700 * tt) + rng.uniform(-1, 1, len(tt)) * .4) * np.exp(-tt * 90)
def shk(): tt = mt(.05); x = rng.uniform(-1, 1, len(tt)); return (x - lp2(x, .5)) * np.exp(-tt * 70)
def bell(f, d=3.0): tt = mt(d); return sum(np.sin(2 * np.pi * f * r * tt) * np.exp(-tt * (1.2 + i)) / (1 + i) for i, r in enumerate((1, 2.76, 5.4, 8.9)))
def sub(f, d): tt = mt(d); return (np.sin(2 * np.pi * f * tt) + .3 * np.sin(4 * np.pi * f * tt)) * np.minimum(1, tt * 30) * np.exp(-tt * 1.5 / d)

def music_hub():
    bpm = 72; b = 60 / bpm; L = b * 32; buf = np.zeros((int(L * MSR), 2))
    chords = [[50, 57, 60, 64], [46, 53, 57, 62], [48, 55, 59, 64], [45, 52, 55, 60]]
    for ci, ch in enumerate(chords):
        place(buf, padtone([note(m) for m in ch], b * 8.5), ci * b * 8, .035)
        place(buf, sub(note(ch[0] - 12), b * 7), ci * b * 8, .22)
        seq = [0, 2, 1, 3, 2, 1]
        for i, k in enumerate(seq):
            if rng.random() < .8: place(buf, ks(note(ch[k] + 12), 2.5, .997, .35), ci * b * 8 + (1 + i * 1.0 + (0.5 if i % 2 else 0)) * b, .22, rng.uniform(.25, .75))
    return echo(buf, b * .75, .35, 3)

def music_fight(final=False):
    bpm = 96 if not final else 84; b = 60 / bpm; L = b * 32; buf = np.zeros((int(L * MSR), 2))
    roots = [38, 38, 34, 36] if not final else [37, 37, 33, 40]
    for ci, r in enumerate(roots):
        t0 = ci * b * 8
        place(buf, padtone([note(r + 24), note(r + 31), note(r + 34 if not final else r + 27)], b * 8.5), t0, .025)
        for s in range(16):
            if s % 8 in (0, 3, 6) or (ci % 2 and s % 8 == 5):
                x = ks(note(r), b * .9, .992, .15); place(buf, lp2(x, .12), t0 + s * b * .5, .5)
        for s in range(8):
            if s % 4 == 0: place(buf, kick(), t0 + s * b, .5)
            if s % 4 == 2: place(buf, rim(), t0 + s * b, .12, .65)
        for s in range(32):
            if s % 2 == 1 or s % 16 == 14: place(buf, shk(), t0 + s * b * .25, .05 + .03 * (s % 4 == 3), .35)
        mel = [r + 36, r + 39, r + 43, r + 46, r + 41] if not final else [r + 36, r + 43, r + 39, r + 48, r + 46]
        for i in range(3):
            if rng.random() < .75: place(buf, bell(note(mel[(ci + i * 2) % 5]), 3.5) if final else ks(note(mel[(ci + i * 2) % 5]), 3.0, .998, .3), t0 + (2 + i * 2.5) * b, .09 if final else .16, rng.uniform(.2, .8))
    return echo(buf, b * .75, .4, 4)

def save_music(name, x):
    x = x / np.max(np.abs(x)) * .8; p = os.path.join(OUT, name + ".wav")
    with wave.open(p, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(MSR); w.writeframes((x * 32767).astype("<i2").tobytes())
    to_ogg(name, 5)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sfx(); voices()
    save_music("mus_hub", music_hub()); save_music("mus_fight", music_fight()); save_music("mus_final", music_fight(True))
    print("ok", len(os.listdir(OUT)))
