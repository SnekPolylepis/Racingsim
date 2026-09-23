"""Build a small offline RPM/load bank from the vendored CC0 recordings.

First run tools/decode_engine_recordings.gd with Godot 4.6.2. Only NumPy
2.3.5 and Python's standard library are needed here. Reference RPMs are
sound-design anchors, not measurements of the unidentified recorded cars.
"""
import hashlib
import json
import wave
from pathlib import Path

import numpy as np

if np.__version__ != "2.3.5":
    raise RuntimeError("Use the pinned NumPy 2.3.5 build runtime")

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/audio"
OUT.mkdir(exist_ok=True)
RATE = 44100


def read(stem):
    with wave.open(str(ROOT / "tests/audio-study" / (stem + ".wav")), "rb") as wav:
        assert wav.getframerate() == RATE and wav.getsampwidth() == 2
        return np.frombuffer(wav.readframes(wav.getnframes()), "<i2").astype(float) / 32768


def filter_audio(x, high=6500):
    frequencies = np.fft.rfftfreq(len(x), 1 / RATE)
    response = (frequencies / np.sqrt(frequencies**2 + 45**2)) ** 2
    response /= np.sqrt(1 + (frequencies / high) ** 6)
    return np.fft.irfft(np.fft.rfft(x - x.mean()) * response, n=len(x))


def steady_pitch(x, bounds, target):
    # Track the same harmonic family within a narrow range, then resample the
    # source's cumulative engine cycles. This removes the recorded rev ramp;
    # the game's live RPM owns the rise/fall instead of repeating a rev clip.
    n = 8192
    centres = np.arange(n // 2, len(x) - n // 2, int(RATE * .025))
    frequencies = np.fft.rfftfreq(n, 1 / RATE)
    candidates = np.arange(bounds[0], bounds[1], .25)
    pitches = []
    for centre in centres:
        spectrum = abs(np.fft.rfft(x[centre - n // 2:centre + n // 2] * np.hanning(n)))
        score = sum(np.log1p(np.interp(candidates * k, frequencies, spectrum)) / k**.35
                    for k in range(1, 7))
        pitches.append(candidates[score.argmax()])
    # A short median filter prevents one spectral peak from causing a chirp.
    padded = np.pad(pitches, (2, 2), mode="edge")
    pitches = np.array([np.median(padded[i:i + 5]) for i in range(len(pitches))])
    pitch = np.interp(np.arange(len(x)), centres, pitches)
    cycles = np.cumsum(pitch) / RATE
    positions = np.interp(np.arange(0, cycles[-1], target / RATE), cycles, np.arange(len(x)))
    return np.interp(positions, np.arange(len(x)), x), float(np.median(pitches))


def loop(x, target):
    # Whole-cycle overlap makes the repeat seam continuous without a silent gap.
    fade = round(round(.09 * target) / target * RATE)
    blend = np.linspace(0, 1, fade, endpoint=False)
    return np.concatenate([x[fade:-fade], x[-fade:] * (1 - blend) + x[:fade] * blend])


def write(name, x):
    x -= x.mean()
    gain = min(.22 / max(1e-6, np.sqrt(np.mean(x * x))), .88 / max(abs(x)))
    pcm = np.rint(x * gain * 32767).astype("<i2")
    path = OUT / (name + ".wav")
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    return {"file": path.relative_to(ROOT).as_posix(), "frames": len(pcm),
            "seconds": len(pcm) / RATE, "peak": float(max(abs(pcm.astype(float))) / 32768),
            "rms": float(np.sqrt(np.mean((pcm.astype(float) / 32768) ** 2))),
            "seam_step": float(abs(int(pcm[0]) - int(pcm[-1])) / 32768),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


specs = [
    ("idle", "ferrari-idle", 8.0, 3.0, (85, 125), 1250),
    ("low", "ferrari-acceleration", 6.0, 1.35, (85, 130), 2400),
    ("mid", "ferrari-acceleration", 24.0, 1.4, (160, 220), 4200),
    ("high", "ferrari-acceleration", 30.0, 1.4, (260, 350), 6800),
]
manifest = {"decoder": "Godot 4.6.2", "numpy": np.__version__, "rate": RATE,
            "reference_rpm_note": "Tuned anchors; recorded model/RPM are unspecified", "bands": []}
for name, stem, start, duration, bounds, rpm in specs:
    source = read(stem)
    segment = filter_audio(source[round(start * RATE):round((start + duration) * RATE)])
    steady, detected = steady_pitch(segment, bounds, rpm / 20)
    steady = loop(steady, rpm / 20)
    row = {"band": name, "source": stem + ".mp3", "start_seconds": start,
           "duration_seconds": duration, "tracked_hz_median": detected, "reference_rpm": rpm,
           "power": write("engine-" + name, steady.copy()),
           "coast": write("coast-" + name, filter_audio(steady.copy(), 1800))}
    manifest["bands"].append(row)
    print(name, "reference RPM", rpm, "tracked Hz", round(detected, 2),
          "loop seconds", round(row["power"]["seconds"], 3), "peak", round(row["power"]["peak"], 3))
(OUT / "bank-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
