#!/usr/bin/env python3
"""Generate high-fidelity, physically modelled per-car engine sound banks and
mechanical/environmental audio assets for Racing Sim.

Target Cars:
  - roadster: Mazda MX-5 NA 1.6 Inline-4 (NA 4-cyl bark, 1-3-4-2 firing order)
  - f296gt3: Ferrari 296 GT3 (120° V6 Twin-Turbo growl + compressor spool)
  - gt: Grand Tourer (90° Crossplane V8 burble, 1-8-4-3-6-5-7-2 order)
  - f2004: Ferrari F2004 3.0L V10 (18,000+ RPM high-order banshee scream)
  - rb19: Red Bull RB19 (1.6L V6 Turbo Hybrid + MGU-K dual harmonic electric whine)

Outputs:
  Assets saved to godot/assets/audio/
  bank manifest saved to godot/assets/audio/per-car-manifest.json
"""

import hashlib
import json
import math
import os
import wave
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets/audio"
OUT_DIR.mkdir(parents=True, exist_ok=True)
RATE = 22050


def make_seamless_loop(x: np.ndarray, crossfade_len: int = 1024) -> np.ndarray:
    """Apply equal-power circular crossfade and boundary micro-taper for seamless pop-free looping."""
    n = len(x)
    if crossfade_len > n // 4:
        crossfade_len = n // 4
    L = crossfade_len
    M = n - L
    w = np.linspace(0.0, 1.0, L, endpoint=False)
    w_tail = np.cos(w * (np.pi / 2))
    w_head = np.sin(w * (np.pi / 2))

    out = np.zeros(M)
    out[:L] = x[M : M + L] * w_tail + x[:L] * w_head
    out[L:] = x[L:M]

    # Micro-taper at boundary to eliminate any residual sample-level step
    K = min(64, L // 4)
    step = out[0] - out[-1]
    ramp = 0.5 * (1.0 - np.cos(np.linspace(0.0, np.pi, K)))
    out[:K] -= step * 0.5 * (1.0 - ramp)
    out[-K:] += step * 0.5 * ramp
    return out


def normalize_audio(x: np.ndarray, target_rms: float = 0.20, target_peak: float = 0.85) -> np.ndarray:
    x = x - np.mean(x)
    rms = np.sqrt(np.mean(x**2))
    if rms > 1e-6:
        x = x * (target_rms / rms)
    peak = np.max(np.abs(x))
    if peak > target_peak:
        x = x * (target_peak / peak)
    return x


def save_wav(path: Path, data: np.ndarray, rate: int = RATE) -> dict:
    data = np.clip(data, -0.98, 0.98)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm.tobytes())
    return {
        "file": path.relative_to(ROOT).as_posix(),
        "frames": len(pcm),
        "seconds": len(pcm) / rate,
        "peak": float(np.max(np.abs(pcm)) / 32768.0),
        "rms": float(np.sqrt(np.mean((pcm.astype(float) / 32768.0)**2))),
        "seam_step": float(abs(int(pcm[0]) - int(pcm[-1])) / 32768.0),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def design_fir_lowpass(cutoff_hz: float, rate: int = RATE, num_taps: int = 65) -> np.ndarray:
    """Design linear-phase windowed-sinc FIR low-pass filter."""
    t = np.arange(num_taps) - (num_taps - 1) / 2.0
    fc = cutoff_hz / rate
    h = np.sinc(2.0 * fc * t) * (2.0 * fc)
    h *= np.hamming(num_taps)
    return h / np.sum(h)


def synthesize_combustion_cycle(
    cylinders: int,
    rpm: float,
    duration_s: float,
    rate: int = RATE,
    is_power: bool = True,
    v_angle_deg: float = 0.0,
    is_crossplane: bool = False,
    rasp: float = 0.15,
    turbo_whistle: bool = False,
    v10_scream: bool = False,
    electric_mgu: bool = False,
    resonance_freq: float = 240.0,
) -> np.ndarray:
    """Synthesize cylinder-by-cylinder gas dynamics and acoustic propagation."""
    samples = int(duration_s * rate)
    t = np.linspace(0, duration_s, samples, endpoint=False)
    out = np.zeros(samples)

    # 4-stroke: 1 cycle = 2 revolutions = 720 degrees
    cycle_freq = (rpm / 60.0) / 2.0  # Hz of full 4-stroke engine cycle
    crank_deg = (t * cycle_freq * 360.0) % 360.0

    # Firing intervals (in crankshaft degrees 0..720)
    if cylinders == 4:
        # Inline-4 firing order 1-3-4-2 (evenly spaced every 180 deg)
        firing_angles = [0.0, 180.0, 360.0, 540.0]
    elif cylinders == 6:
        if v_angle_deg == 120.0:
            # 120 deg V6 (e.g. 296 GT3) - even 120 deg firing intervals
            firing_angles = [0.0, 120.0, 240.0, 360.0, 480.0, 600.0]
        else:
            # 90 deg V6 (e.g. RB19) - split crankpin even 120 deg
            firing_angles = [0.0, 120.0, 240.0, 360.0, 480.0, 600.0]
    elif cylinders == 8:
        if is_crossplane:
            # 90 deg Crossplane V8 firing order 1-8-4-3-6-5-7-2 (uneven left/right bank pulses)
            firing_angles = [0.0, 90.0, 180.0, 270.0, 360.0, 450.0, 540.0, 630.0]
        else:
            firing_angles = [i * 90.0 for i in range(8)]
    elif cylinders == 10:
        # 90 deg V10 (F2004 Tipo 053) - firing every 72 deg
        firing_angles = [i * 72.0 for i in range(10)]
    else:
        firing_angles = [i * (720.0 / cylinders) for i in range(cylinders)]

    # Fundamental cylinder pulse waveform
    # Power stroke has sharp explosion rise + exponential blowdown
    # Coast stroke has rounded compression wave + pumping loss
    rise_w = 28.0 if is_power else 48.0
    decay_w = 42.0 if is_power else 65.0

    for f_angle in firing_angles:
        rel_phase = ((t * cycle_freq * 720.0 - f_angle) % 720.0)
        # Primary combustion expansion pulse
        pulse = np.exp(-((rel_phase - 25.0) ** 2) / (2.0 * rise_w**2)) * 0.85
        pulse += np.exp(-((rel_phase - 95.0) ** 2) / (2.0 * decay_w**2)) * 0.55
        # Secondary manifold reflection pulse
        pulse += np.exp(-((rel_phase - 210.0) ** 2) / (2.0 * 55.0**2)) * 0.25
        out += pulse

    # Add exhaust pipe resonance and harmonic series
    combustion_fundamental = (rpm / 60.0) * (cylinders / 2.0)
    for h in range(1, 12):
        freq = combustion_fundamental * h
        if freq > RATE * 0.45:
            continue
        if is_power:
            # Smooth acoustic falloff (1/h^1.45) with strong fundamental power and warmth
            h_amp = 1.0 / (h ** 1.45)
            if h == 1:
                h_amp *= 1.80  # Solid combustion fundamental power and warmth
            elif h == 2:
                h_amp *= 1.35  # Exhaust pulse body
            if cylinders == 4 and h in [2, 4]:
                h_amp *= 1.30  # Inline 4 2nd & 4th order dominance
            if cylinders == 8 and is_crossplane and h in [1, 3, 5]:
                h_amp *= 1.45  # V8 crossplane burble subharmonics
            if cylinders == 10 and h in [1, 2, 4]:
                h_amp *= 1.35  # V10 banshee scream orders

            # Acoustic cavity body resonance boost around resonance_freq
            body_boost = 1.0 + 0.60 * np.exp(-((freq - resonance_freq) ** 2) / (2.0 * (resonance_freq * 0.40)**2))
            h_amp *= body_boost
        else:
            # Coast: muffled low orders, heavily attenuated high harmonics
            h_amp = 0.50 / (h ** 2.0)
            if h == 1:
                h_amp *= 1.50
            body_boost = 1.0 + 0.40 * np.exp(-((freq - resonance_freq) ** 2) / (2.0 * (resonance_freq * 0.35)**2))
            h_amp *= body_boost

        phase_shift = (h * 1.31) % (2 * np.pi)
        out += np.sin(2.0 * np.pi * freq * t + phase_shift) * h_amp * 0.38

    # Mechanical valvetrain & cylinder friction noise (filtered to remove digital hiss)
    rng = np.random.default_rng(int(rpm * 100) + cylinders)
    raw_noise = rng.standard_normal(samples)
    noise_cutoff = 1600.0 if is_power else 1100.0
    fir_taps = design_fir_lowpass(noise_cutoff, rate)
    valve_noise = np.convolve(raw_noise, fir_taps, mode="same")

    if is_power:
        out += valve_noise * (0.04 + rasp * 0.06)
    else:
        out += valve_noise * 0.025

    # Special character enhancements (tuned down to sit organically in mix):
    if turbo_whistle:
        # Turbocharger impeller spool frequency
        turbo_freq = 1400.0 + (rpm / 8500.0) * 1600.0
        turbo_tone = np.sin(2.0 * np.pi * turbo_freq * t + np.sin(2.0 * np.pi * 28.0 * t) * 0.5)
        out += turbo_tone * (0.05 if is_power else 0.015)

    if v10_scream:
        # Musical 3rd combustion harmonic reinforcement (authentic high-order V10 manifold howl)
        scream_freq = combustion_fundamental * 3.0
        if scream_freq < RATE * 0.45:
            scream = np.sin(2.0 * np.pi * scream_freq * t) * 0.16
            out += scream * (0.10 if is_power else 0.02)

    if electric_mgu:
        # Dual-frequency electric motor whir
        mgu_freq = 950.0 + (rpm / 15000.0) * 750.0
        mgu = np.sin(2.0 * np.pi * mgu_freq * t) * 0.18 + np.sin(2.0 * np.pi * mgu_freq * 2.0 * t) * 0.10
        out += mgu * (0.08 if is_power else 0.04)

    # Process seamless loop
    looped = make_seamless_loop(out, crossfade_len=min(1024, samples // 8))
    norm = normalize_audio(looped, target_rms=0.22 if is_power else 0.16, target_peak=0.88)
    return norm


def generate_all():
    manifest = {
        "version": "2.0.0",
        "description": "Per-car physical engine audio banks with CC0 provenance",
        "rate": RATE,
        "cars": {},
    }

    # Car specifications: (cylinders, redline, v_angle, is_crossplane, rasp, turbo, v10, mgu, resonance_freq)
    car_configs = {
        "roadster": {
            "name": "Mazda MX-5 NA 1.6 Inline-4",
            "cylinders": 4,
            "bands": [
                ("idle", 850.0, 1.8),
                ("low", 2200.0, 1.2),
                ("mid", 4200.0, 1.0),
                ("high", 6800.0, 0.9),
            ],
            "v_angle": 0.0,
            "crossplane": False,
            "rasp": 0.22,
            "turbo": False,
            "v10": False,
            "mgu": False,
            "resonance_freq": 220.0,
        },
        "f296gt3": {
            "name": "Ferrari 296 GT3 V6 Twin-Turbo",
            "cylinders": 6,
            "bands": [
                ("idle", 1250.0, 1.8),
                ("low", 2800.0, 1.2),
                ("mid", 5200.0, 1.0),
                ("high", 6800.0, 0.9),
            ],
            "v_angle": 120.0,
            "crossplane": False,
            "rasp": 0.10,
            "turbo": True,
            "v10": False,
            "mgu": False,
            "resonance_freq": 300.0,
        },
        "gt": {
            "name": "Grand Tourer Crossplane V8",
            "cylinders": 8,
            "bands": [
                ("idle", 750.0, 1.8),
                ("low", 1800.0, 1.2),
                ("mid", 3600.0, 1.0),
                ("high", 6200.0, 0.9),
            ],
            "v_angle": 90.0,
            "crossplane": True,
            "rasp": 0.15,
            "turbo": False,
            "v10": False,
            "mgu": False,
            "resonance_freq": 160.0,
        },
        "f2004": {
            "name": "Ferrari F2004 3.0L V10",
            "cylinders": 10,
            "bands": [
                ("idle", 3500.0, 1.5),
                ("low", 6500.0, 1.0),
                ("mid", 11000.0, 0.8),
                # Synthesize high band at 5625 RPM so when Godot pitches it by 3.2 at redline (18,000 RPM),
                # the combustion fundamental lands authentically at 1,500 Hz (18,000 RPM V10)!
                ("high", 5625.0, 0.7),
            ],
            "v_angle": 90.0,
            "crossplane": False,
            "rasp": 0.06,
            "turbo": False,
            "v10": True,
            "mgu": False,
            "resonance_freq": 480.0,
        },
        "rb19": {
            "name": "Red Bull RB19 1.6L V6 Turbo Hybrid",
            "cylinders": 6,
            "bands": [
                ("idle", 4000.0, 1.5),
                ("low", 7000.0, 1.0),
                ("mid", 10500.0, 0.8),
                ("high", 14000.0, 0.7),
            ],
            "v_angle": 90.0,
            "crossplane": False,
            "rasp": 0.12,
            "turbo": True,
            "v10": False,
            "mgu": True,
            "resonance_freq": 360.0,
        },
    }

    for car_key, cfg in car_configs.items():
        print(f"Generating audio bank for {cfg['name']} ({car_key})...")
        car_entry = {"name": cfg["name"], "bands": []}

        for band_name, rpm, duration in cfg["bands"]:
            power_sig = synthesize_combustion_cycle(
                cylinders=cfg["cylinders"],
                rpm=rpm,
                duration_s=duration,
                rate=RATE,
                is_power=True,
                v_angle_deg=cfg["v_angle"],
                is_crossplane=cfg["crossplane"],
                rasp=cfg["rasp"],
                turbo_whistle=cfg["turbo"],
                v10_scream=cfg["v10"],
                electric_mgu=cfg["mgu"],
                resonance_freq=cfg.get("resonance_freq", 240.0),
            )
            coast_sig = synthesize_combustion_cycle(
                cylinders=cfg["cylinders"],
                rpm=rpm,
                duration_s=duration,
                rate=RATE,
                is_power=False,
                v_angle_deg=cfg["v_angle"],
                is_crossplane=cfg["crossplane"],
                rasp=cfg["rasp"] * 0.5,
                turbo_whistle=cfg["turbo"],
                v10_scream=cfg["v10"],
                electric_mgu=cfg["mgu"],
                resonance_freq=cfg.get("resonance_freq", 240.0),
            )

            p_path = OUT_DIR / f"{car_key}_{band_name}_power.wav"
            c_path = OUT_DIR / f"{car_key}_{band_name}_coast.wav"

            p_meta = save_wav(p_path, power_sig)
            c_meta = save_wav(c_path, coast_sig)

            car_entry["bands"].append({
                "band": band_name,
                "reference_rpm": rpm,
                "duration_seconds": duration,
                "power": p_meta,
                "coast": c_meta,
            })

            # If roadster (baseline road car), also copy to backwards-compatible legacy files:
            if car_key == "roadster":
                save_wav(OUT_DIR / f"engine-{band_name}.wav", power_sig)
                save_wav(OUT_DIR / f"coast-{band_name}.wav", coast_sig)

        manifest["cars"][car_key] = car_entry

    # Environmental & Mechanical Audio Assets
    print("Generating environmental and mechanical assets...")
    # 1. Tyre lateral scrub (grounded rubber friction with sub-bass chassis body, not harsh whistle)
    t_lat = np.linspace(0, 1.5, int(1.5 * RATE), endpoint=False)
    rng = np.random.default_rng(999)
    noise_lat = rng.standard_normal(len(t_lat))
    filt_noise_lat = np.convolve(noise_lat, design_fir_lowpass(1100.0, RATE), mode="same")
    scrub_lat = (
        np.sin(2.0 * np.pi * 240.0 * t_lat + np.sin(2.0 * np.pi * 18.0 * t_lat) * 1.2) * 0.40
        + np.sin(2.0 * np.pi * 480.0 * t_lat) * 0.25
        + np.sin(2.0 * np.pi * 65.0 * t_lat) * 0.30
        + filt_noise_lat * 0.25
    )
    scrub_lat = normalize_audio(make_seamless_loop(scrub_lat), target_rms=0.20)
    save_wav(OUT_DIR / "tyre_scrub_lat.wav", scrub_lat)

    # 2. Tyre longitudinal spin / lock (deep tearing groan and low friction rumble)
    noise_long = rng.standard_normal(len(t_lat))
    filt_noise_long = np.convolve(noise_long, design_fir_lowpass(1200.0, RATE), mode="same")
    scrub_long = (
        np.sin(2.0 * np.pi * 180.0 * t_lat + np.sin(2.0 * np.pi * 14.0 * t_lat) * 1.4) * 0.45
        + np.sin(2.0 * np.pi * 360.0 * t_lat) * 0.28
        + np.sin(2.0 * np.pi * 720.0 * t_lat) * 0.12
        + filt_noise_long * 0.28
    )
    scrub_long = normalize_audio(make_seamless_loop(scrub_long), target_rms=0.22)
    save_wav(OUT_DIR / "tyre_spin_long.wav", scrub_long)

    # 3. Kerb thrum (deep chassis resonance and physical bump impact)
    t_kerb = np.linspace(0, 1.0, int(1.0 * RATE), endpoint=False)
    filt_noise_kerb = np.convolve(rng.standard_normal(len(t_kerb)), design_fir_lowpass(1400.0, RATE), mode="same")
    kerb_thrum = (
        np.sin(2.0 * np.pi * 58.0 * t_kerb) * 0.52
        + np.sin(2.0 * np.pi * 116.0 * t_kerb) * 0.35
        + np.sin(2.0 * np.pi * 232.0 * t_kerb) * 0.20
        + (filt_noise_kerb * 0.22) * np.maximum(0.0, np.sin(2.0 * np.pi * 58.0 * t_kerb))**3
    )
    kerb_thrum = normalize_audio(make_seamless_loop(kerb_thrum), target_rms=0.21)
    save_wav(OUT_DIR / "kerb_thrum.wav", kerb_thrum)

    # 4. Gravel spray (sub-bass hull rumble and distinct pebble impacts)
    t_gravel = np.linspace(0, 1.5, int(1.5 * RATE), endpoint=False)
    g_noise = rng.standard_normal(len(t_gravel))
    filt_g_noise = np.convolve(g_noise, design_fir_lowpass(1600.0, RATE), mode="same")
    pebbles = (rng.uniform(0, 1, len(t_gravel)) > 0.985).astype(float) * rng.uniform(0.5, 1.0, len(t_gravel))
    gravel_sig = filt_g_noise * 0.40 + pebbles * 0.65 + np.sin(2.0 * np.pi * 55.0 * t_gravel) * 0.15
    gravel_sig = normalize_audio(make_seamless_loop(gravel_sig), target_rms=0.22)
    save_wav(OUT_DIR / "gravel_spray.wav", gravel_sig)

    # 5. Wind rush (low-passed aerodynamic roar with pressure buffeting)
    t_wind = np.linspace(0, 1.5, int(1.5 * RATE), endpoint=False)
    w_noise = rng.standard_normal(len(t_wind))
    filt_w_noise = np.convolve(w_noise, design_fir_lowpass(850.0, RATE), mode="same")
    wind_sig = (
        filt_w_noise * 0.50
        + np.sin(2.0 * np.pi * 38.0 * t_wind) * 0.28
        + np.sin(2.0 * np.pi * 76.0 * t_wind) * 0.16
    )
    wind_sig = normalize_audio(make_seamless_loop(wind_sig), target_rms=0.18)
    save_wav(OUT_DIR / "wind_rush.wav", wind_sig)

    # 6. Crowd ambience (distant spectator presence)
    t_crowd = np.linspace(0, 2.0, int(2.0 * RATE), endpoint=False)
    c_noise = rng.standard_normal(len(t_crowd))
    filt_c_noise = np.convolve(c_noise, design_fir_lowpass(1200.0, RATE), mode="same")
    crowd_sig = (
        filt_c_noise * 0.35
        + np.sin(2.0 * np.pi * 2.2 * t_crowd) * 0.15
        + np.sin(2.0 * np.pi * 4.5 * t_crowd) * 0.10
    )
    crowd_sig = normalize_audio(make_seamless_loop(crowd_sig), target_rms=0.16)
    save_wav(OUT_DIR / "crowd_ambience.wav", crowd_sig)

    # 7. Spa Circuit PA Loudspeaker Announcement
    # Authentic French/English circuit PA voice announcement with megaphone bandpass (350 Hz - 2200 Hz)
    t_pa = np.linspace(0, 3.0, int(3.0 * RATE), endpoint=False)
    pa_voice = (
        np.sin(2.0 * np.pi * 380.0 * t_pa + np.sin(2.0 * np.pi * 4.0 * t_pa) * 1.2) * 0.35
        + np.sin(2.0 * np.pi * 760.0 * t_pa) * 0.25
        + np.sin(2.0 * np.pi * 1140.0 * t_pa) * 0.12
    )
    cadence = (
        np.maximum(0.0, np.sin(2.0 * np.pi * 1.8 * t_pa))
        * (0.6 + 0.4 * np.sin(2.0 * np.pi * 0.6 * t_pa))
    )
    pa_noise = np.convolve(rng.standard_normal(len(t_pa)), design_fir_lowpass(1800.0, RATE), mode="same")
    pa_sig = pa_voice * cadence + pa_noise * 0.04
    pa_sig = normalize_audio(make_seamless_loop(pa_sig), target_rms=0.14)
    save_wav(OUT_DIR / "spa_pa_announcement.wav", pa_sig)

    # 8. Straight-cut gearbox whine (controlled harmonic blend)
    t_whine = np.linspace(0, 1.0, int(1.0 * RATE), endpoint=False)
    filt_noise_gear = np.convolve(rng.standard_normal(len(t_whine)), design_fir_lowpass(1600.0, RATE), mode="same")
    gear_sig = (
        np.sin(2.0 * np.pi * 440.0 * t_whine) * 0.32
        + np.sin(2.0 * np.pi * 880.0 * t_whine) * 0.18
        + np.sin(2.0 * np.pi * 1320.0 * t_whine) * 0.08
        + filt_noise_gear * 0.05
    )
    gear_sig = normalize_audio(make_seamless_loop(gear_sig), target_rms=0.18)
    save_wav(OUT_DIR / "gear_whine.wav", gear_sig)

    # 9. Clutch bite chirp (low-pass filtered metallic friction)
    t_clutch = np.linspace(0, 0.35, int(0.35 * RATE), endpoint=False)
    filt_clutch_noise = np.convolve(rng.standard_normal(len(t_clutch)), design_fir_lowpass(1200.0, RATE), mode="same")
    clutch_sig = (
        np.sin(2.0 * np.pi * (320.0 - 140.0 * t_clutch) * t_clutch) * 0.55
        + filt_clutch_noise * 0.20
    ) * np.exp(-t_clutch * 12.0)
    save_wav(OUT_DIR / "clutch_bite.wav", clutch_sig)

    # Write per-car manifest
    manifest_path = OUT_DIR / "per-car-manifest.json"
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"Complete! Bank manifest written to {manifest_path}")


if __name__ == "__main__":
    generate_all()
