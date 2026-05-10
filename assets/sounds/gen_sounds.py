"""
Realistic board-game SFX generator — physics-based synthesis.
Produces 44100 Hz, 16-bit mono WAV files.
"""
import wave, struct, math, numpy as np, os

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))

def write_wav(name, samples):
    path = os.path.join(OUT, name)
    data = np.clip(samples, -1.0, 1.0)
    ints = (data * 32767).astype(np.int16)
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(ints.tobytes())
    print(f"  {name:30s}  {len(ints)/SR*1000:.0f} ms")

def env(n, a=0.002, d=0.01, s_level=0.4, s_dur=0.05, r=0.12):
    """ADSR envelope (all in seconds → samples)"""
    t = np.linspace(0, n/SR, n)
    out = np.zeros(n)
    ai = int(a*SR); di = int(d*SR); si = int(s_dur*SR); ri = int(r*SR)
    # attack
    out[:ai] = np.linspace(0, 1, ai)
    # decay
    end_d = ai + di
    if end_d <= n:
        out[ai:end_d] = np.linspace(1, s_level, di)
    # sustain
    end_s = end_d + si
    if end_s <= n:
        out[end_d:end_s] = s_level
    # release
    end_r = end_s + ri
    if end_r > n: end_r = n
    if end_s < n:
        out[end_s:end_r] = np.linspace(s_level, 0, end_r - end_s)
    return out

def exp_decay(n, tau):
    """Exponential decay envelope"""
    t = np.arange(n) / SR
    return np.exp(-t / tau)

def noise(n):
    return np.random.uniform(-1, 1, n)

# ─────────────────────────────────────────────────────────────────
# 1. TILE PICKUP — ahşap taşı kaldırma: hafif "tik" + hava sürünmesi
# ─────────────────────────────────────────────────────────────────
def make_tile_pickup():
    dur = 0.13
    n = int(dur * SR)
    t = np.arange(n) / SR

    # Transient: kısa wooden click (700 Hz body + 3.2 kHz surface)
    click_env = exp_decay(n, 0.008)
    click = (
        0.6 * np.sin(2*np.pi*700*t) * click_env +
        0.3 * np.sin(2*np.pi*3200*t) * click_env +
        0.15 * noise(n) * click_env
    )

    # Subtle resonant tail (tile vibrates ~1.8 kHz)
    tail_env = exp_decay(n, 0.035) * np.exp(-t/0.003)  # delayed start via modulation
    tail_env[:int(0.004*SR)] = 0  # tiny pre-delay
    tail = 0.25 * np.sin(2*np.pi*1800*t + 0.4) * exp_decay(n, 0.04)

    sig = click + tail
    # soft overall fade
    sig *= exp_decay(n, 0.06)
    sig *= 0.72
    write_wav("tile_pickup.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 2. TILE PLACE — taşı tahtaya yerleştirme: dolu "klak", hafif sıçrama
# ─────────────────────────────────────────────────────────────────
def make_tile_place():
    dur = 0.18
    n = int(dur * SR)
    t = np.arange(n) / SR

    # İmpact: low thud + hard surface click
    impact_env = exp_decay(n, 0.012)
    thud = (
        0.7 * np.sin(2*np.pi*420*t) * impact_env +
        0.5 * np.sin(2*np.pi*880*t) * impact_env +
        0.4 * np.sin(2*np.pi*2600*t) * exp_decay(n, 0.005) +
        0.3 * noise(n) * exp_decay(n, 0.006)
    )

    # Micro-bounce (70% amplitude, 14ms later)
    bounce_start = int(0.014 * SR)
    bounce_env = np.zeros(n)
    bn = n - bounce_start
    bounce_env[bounce_start:] = exp_decay(bn, 0.008)
    bounce = 0.28 * np.sin(2*np.pi*550*t) * bounce_env

    # Board resonance
    board_res = 0.12 * np.sin(2*np.pi*1100*t) * exp_decay(n, 0.055)

    sig = thud + bounce + board_res
    sig *= 0.78
    write_wav("tile_place.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 3. TILE RETURN — taşı rafa geri bırakma: daha yumuşak "tık"
# ─────────────────────────────────────────────────────────────────
def make_tile_return():
    dur = 0.14
    n = int(dur * SR)
    t = np.arange(n) / SR

    impact_env = exp_decay(n, 0.010)
    sig = (
        0.55 * np.sin(2*np.pi*380*t) * impact_env +
        0.35 * np.sin(2*np.pi*750*t) * impact_env +
        0.25 * np.sin(2*np.pi*1900*t) * exp_decay(n, 0.004) +
        0.2  * noise(n) * exp_decay(n, 0.005)
    )
    sig *= 0.62
    write_wav("tile_return.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 4. WORD VALID — kelime kabul: parlak üçlü zil, kristal his
# ─────────────────────────────────────────────────────────────────
def make_word_valid():
    dur = 0.55
    n = int(dur * SR)
    t = np.arange(n) / SR

    def bell(freq, start_s, amp, tau):
        s = int(start_s * SR)
        out = np.zeros(n)
        if s >= n: return out
        tn = np.arange(n - s) / SR
        e = np.exp(-tn / tau)
        # fundamental + partials (inharmonic bell series)
        tone = (
            amp * np.sin(2*np.pi*freq*tn) * e +
            amp*0.45 * np.sin(2*np.pi*freq*2.756*tn) * np.exp(-tn/(tau*0.6)) +
            amp*0.22 * np.sin(2*np.pi*freq*5.404*tn) * np.exp(-tn/(tau*0.4)) +
            amp*0.10 * np.sin(2*np.pi*freq*8.933*tn) * np.exp(-tn/(tau*0.25))
        )
        # attack transient
        atk = int(0.003*SR)
        tone[:atk] *= np.linspace(0, 1, atk)
        out[s:] = tone
        return out

    sig  = bell(1047, 0.000, 0.7,  0.18)   # C6
    sig += bell(1319, 0.075, 0.65, 0.16)   # E6
    sig += bell(1568, 0.150, 0.60, 0.14)   # G6
    # shimmer noise burst at onset
    burst_n = int(0.018*SR)
    burst = noise(burst_n) * np.linspace(1,0,burst_n) * 0.08
    sig[:burst_n] += burst

    sig *= 0.82
    write_wav("word_valid.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 5. WORD INVALID — kelime ret: düşük "bzzzt", mat rezonans
# ─────────────────────────────────────────────────────────────────
def make_word_invalid():
    dur = 0.32
    n = int(dur * SR)
    t = np.arange(n) / SR

    # Descending buzz with flutter
    freq = 280 * np.exp(-t * 2.0)   # pitch drop
    phase = 2*np.pi * np.cumsum(freq) / SR
    buzz = np.sin(phase)

    # Add odd harmonics (sawtooth-ish)
    buzz += 0.35 * np.sin(3*phase) + 0.18 * np.sin(5*phase)

    # Low thud
    thud = 0.6 * np.sin(2*np.pi*110*t) * exp_decay(n, 0.045)

    env_main = exp_decay(n, 0.09)
    # soft onset
    onset = int(0.004*SR)
    env_main[:onset] *= np.linspace(0, 1, onset)

    sig = buzz * env_main * 0.5 + thud
    sig *= 0.68
    write_wav("word_invalid.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 6. SCORE UP — puan artışı: hızlı tırmanma + parlak çıkış
# ─────────────────────────────────────────────────────────────────
def make_score_up():
    dur = 0.28
    n = int(dur * SR)
    t = np.arange(n) / SR

    # Fast pentatonic sweep C5→G5→C6
    notes = [523, 659, 784, 1047]
    step = n // len(notes)
    sig = np.zeros(n)
    for i, freq in enumerate(notes):
        s = i * step
        e_n = min(step + int(0.04*SR), n - s)
        tn = np.arange(e_n) / SR
        env_n = np.exp(-tn / 0.035)
        atk = int(0.002*SR)
        env_n[:atk] *= np.linspace(0, 1, atk)
        tone = (np.sin(2*np.pi*freq*tn) + 0.3*np.sin(2*np.pi*freq*2*tn)) * env_n * 0.5
        sig[s:s+e_n] += tone

    sig *= 0.75
    write_wav("score_up.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 7. WIN — zafer: parlak fanfar + arpej + reverb tail
# ─────────────────────────────────────────────────────────────────
def make_win():
    dur = 1.1
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)

    # Arpeggio chord: C5 E5 G5 C6 E6
    arp = [523, 659, 784, 1047, 1319]
    for i, freq in enumerate(arp):
        s = int(i * 0.055 * SR)
        dur_note = 0.7
        nn = int(dur_note * SR)
        if s + nn > n: nn = n - s
        tn = np.arange(nn) / SR
        e = np.exp(-tn / 0.22)
        atk = int(0.003*SR)
        e[:atk] *= np.linspace(0, 1, atk)
        tone = (
            0.6*np.sin(2*np.pi*freq*tn) +
            0.25*np.sin(2*np.pi*freq*2*tn) +
            0.12*np.sin(2*np.pi*freq*3*tn)
        ) * e
        sig[s:s+nn] += tone * 0.4

    # Sparkle burst at peak
    burst_s = int(0.27 * SR)
    burst_n = int(0.06 * SR)
    if burst_s + burst_n <= n:
        sig[burst_s:burst_s+burst_n] += noise(burst_n) * np.linspace(1,0,burst_n) * 0.06

    sig *= 0.80
    write_wav("win.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 8. LOSE — yenilgi: inen iki nota, hüzünlü
# ─────────────────────────────────────────────────────────────────
def make_lose():
    dur = 0.70
    n = int(dur * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)

    pairs = [(523, 0.0), (415, 0.22)]  # C5 → Ab4 (minor feel)
    for freq, start_s in pairs:
        s = int(start_s * SR)
        nn = int(0.38 * SR)
        if s + nn > n: nn = n - s
        tn = np.arange(nn) / SR
        e = np.exp(-tn / 0.15)
        atk = int(0.006*SR)
        e[:atk] *= np.linspace(0, 1, atk)
        tone = (
            0.7*np.sin(2*np.pi*freq*tn) +
            0.2*np.sin(2*np.pi*freq*2*tn)
        ) * e
        sig[s:s+nn] += tone * 0.5

    sig *= 0.72
    write_wav("lose.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 9. AI TURN — AI hamlesi: yumuşak elektronik "ping"
# ─────────────────────────────────────────────────────────────────
def make_ai_turn():
    dur = 0.22
    n = int(dur * SR)
    t = np.arange(n) / SR

    e = exp_decay(n, 0.06)
    atk = int(0.003*SR)
    e[:atk] *= np.linspace(0, 1, atk)

    sig = (
        0.6 * np.sin(2*np.pi*880*t) +
        0.25 * np.sin(2*np.pi*1320*t) +
        0.10 * np.sin(2*np.pi*1760*t)
    ) * e
    sig *= 0.65
    write_wav("ai_turn.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 10. PASS TURN — pas: nötr yumuşak "tup"
# ─────────────────────────────────────────────────────────────────
def make_pass_turn():
    dur = 0.18
    n = int(dur * SR)
    t = np.arange(n) / SR

    e = exp_decay(n, 0.055)
    atk = int(0.004*SR)
    e[:atk] *= np.linspace(0, 1, atk)

    sig = (
        0.65 * np.sin(2*np.pi*330*t) +
        0.30 * np.sin(2*np.pi*495*t)
    ) * e
    sig *= 0.60
    write_wav("pass_turn.wav", sig)

# ─────────────────────────────────────────────────────────────────
# 11. TILE EXCHANGE — taş değişimi: kısa karıştırma sesi
# ─────────────────────────────────────────────────────────────────
def make_tile_exchange():
    dur = 0.30
    n = int(dur * SR)
    t = np.arange(n) / SR

    # 3 rapid wooden clicks
    sig = np.zeros(n)
    offsets_s = [0.0, 0.08, 0.16]
    for s_time in offsets_s:
        s = int(s_time * SR)
        cn = int(0.07 * SR)
        if s + cn > n: cn = n - s
        tn = np.arange(cn) / SR
        e = np.exp(-tn / 0.015)
        click = (
            0.5*np.sin(2*np.pi*600*tn) +
            0.35*np.sin(2*np.pi*1400*tn) +
            0.25*noise(cn)
        ) * e
        sig[s:s+cn] += click * 0.5

    sig *= 0.70
    write_wav("tile_exchange.wav", sig)

# ─────────────────────────────────────────────────────────────────
print("Generating sounds...")
make_tile_pickup()
make_tile_place()
make_tile_return()
make_word_valid()
make_word_invalid()
make_score_up()
make_win()
make_lose()
make_ai_turn()
make_pass_turn()
make_tile_exchange()
print("Done.")
