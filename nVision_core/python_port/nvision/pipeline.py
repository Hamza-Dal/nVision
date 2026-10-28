"""Core five-feature nVision pipeline translated from the MATLAB reference."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from scipy import io, signal, stats


FEATURE_NAMES = [
    "mean_square",
    "std",
    "absolute_difference_sum",
    "power_fraction_12_20hz",
    "power_fraction_20_40hz",
]
FEATURE_COUNT = 5
SUPPORTED_RATES = (200, 500, 1000)
RATE_DEFAULT = 200
THRESHOLD_DEFAULT = 1.2
SENSITIVITY_DEFAULT = 1.0
DURATION_DEFAULT = 6
INTERVAL_DEFAULT = 1
CLASSIFICATION_MODE_DEFAULT = (True, False)


def resolve_core_file(package_root: Path, filename: str) -> Path:
    """Locate a bundled filter/model asset in a full or flat Python checkout."""
    candidates = (package_root.parent / filename, package_root / filename)
    for candidate in candidates:
        if candidate.is_file():
            return candidate
    locations = ", ".join(str(candidate) for candidate in candidates)
    raise FileNotFoundError(f"nVision asset not found: {filename}. Checked: {locations}")


def read_dat_float32(path: Path) -> np.ndarray:
    """Read nVision's little-endian float32 .dat recording."""
    return np.fromfile(path, dtype="<f4")


def read_dat_segment(path: Path, start: int, count: int) -> np.ndarray:
    """Read a bounded segment without loading the complete recording."""
    if start < 0 or count < 0:
        raise ValueError("start and count must be non-negative")
    with path.open("rb") as handle:
        handle.seek(start * np.dtype("<f4").itemsize)
        return np.fromfile(handle, dtype="<f4", count=count)


def signal_preview(data: np.ndarray, rate: int, max_points: int = 20000) -> tuple[np.ndarray, np.ndarray]:
    """Return evenly sampled time/value arrays suitable for an overview plot."""
    values = np.asarray(data, dtype=float).reshape(-1)
    if values.size == 0:
        return np.empty(0, dtype=float), np.empty(0, dtype=float)
    step = max(1, int(np.ceil(values.size / max_points)))
    preview = np.asarray([chunk.mean() for chunk in np.array_split(values, int(np.ceil(values.size / step)))])
    times = np.linspace(0, values.size / rate, preview.size, endpoint=False)
    return times, preview


def load_filter(filter_path: Path, variable: str) -> np.ndarray:
    """Load one MATLAB FIR coefficient vector."""
    loaded = io.loadmat(filter_path)
    return np.asarray(loaded[variable]).squeeze().astype(float)


def load_rate_filters(core_path: Path, rate: int) -> tuple[np.ndarray, np.ndarray | None]:
    """Load the filters selected by the original winnyAll.m rate branches."""
    if rate not in SUPPORTED_RATES:
        raise ValueError(f"rate must be one of {SUPPORTED_RATES}, got {rate}")
    if rate == 200:
        hp_path = core_path / "HP_fs200_fc2_order200.mat"
        return load_filter(hp_path, "HP_fs200_fc2_order200"), None
    hp_path = core_path / "HP_fs500_fc2_order400.mat"
    lp_path = core_path / "LP_fs1000_fc250_order600.mat"
    return (
        load_filter(hp_path, "HP_fs500_fc2_order400"),
        load_filter(lp_path, "LP_fs1000_fc250_order600"),
    )


def fft_band_fraction(data: np.ndarray, rate: int, low: float, high: float) -> float:
    n = len(data)
    nfft = 2 ** int(np.ceil(np.log2(n)))
    freqs = np.linspace(0, rate / 2, nfft // 2 + 1)
    power = np.abs(np.fft.fft(data, nfft) / n)[: nfft // 2 + 1] ** 2
    start = np.flatnonzero(freqs > low)[0]
    end = np.flatnonzero(freqs > high)[0]
    return float(power[start:end].sum() / power.sum())


def parameters_5(data: np.ndarray, rate: int) -> np.ndarray:
    """Five features corresponding to MATLAB feature indices [1 3 4 21 22]."""
    data = np.asarray(data, dtype=float)
    return np.asarray(
        [
            np.mean(data**2),
            np.std(data, ddof=1),
            np.abs(np.diff(data)).sum(),
            fft_band_fraction(data, rate, 12, 20),
            fft_band_fraction(data, rate, 20, 40),
        ],
        dtype=float,
    )


def matlab_buffer_half_overlap(data: np.ndarray, window: int) -> np.ndarray:
    """Replicate buffer(data, window, window/2) column count and final padding."""
    step = window // 2
    count = int(np.ceil(len(data) / step))
    columns = []
    for index in range(count):
        column = data[index * step : index * step + window]
        if len(column) < window:
            column = np.pad(column, (0, window - len(column)), constant_values=0)
        columns.append(column)
    return np.column_stack(columns)


def winny_all(
    data: np.ndarray,
    rate: int,
    threshold: float,
    hp_b: np.ndarray,
    lp_b: np.ndarray | None = None,
) -> np.ndarray:
    """Five-feature translation of winnyAll.m for all original rates."""
    data = np.asarray(data, dtype=float).copy()
    if rate == 200:
        noise = np.isnan(data)
        data -= np.nanmean(data)
        data[noise] = 0
    else:
        noise = data == 100
        data[noise] = 0
        if rate == 1000:
            if lp_b is None:
                raise ValueError("1000 Hz processing requires a low-pass filter")
            data = signal.filtfilt(lp_b, [1.0], data, method="pad", padtype="odd")
            data = data[::2]
            noise = noise[::2]
            rate = 500
    data = signal.filtfilt(hp_b, [1.0], data, method="pad", padtype="odd")
    data[noise] = 100

    windows = matlab_buffer_half_overlap(data, rate * 2)
    rows = []
    for window_data in windows.T:
        if np.mean(np.abs(window_data) > threshold) or np.std(window_data) == 0:
            rows.append(np.full(FEATURE_COUNT, np.nan))
        else:
            rows.append(parameters_5(window_data, rate))
    return np.asarray(rows)


def process_feature_chunks(
    raw: np.ndarray,
    rate: int,
    threshold: float,
    hp_b: np.ndarray,
    lp_b: np.ndarray | None = None,
) -> np.ndarray:
    """Process the recording in the same 3,600-second chunks as MATLAB."""
    chunk_size = 3600 * rate
    chunks = [raw[start : start + chunk_size] for start in range(0, len(raw), chunk_size)]
    return np.vstack([winny_all(chunk, rate, threshold, hp_b, lp_b) for chunk in chunks])


def mapminmax_fit(x: np.ndarray, ymin: float = -1.0, ymax: float = 1.0):
    x = np.asarray(x, dtype=float)
    xmin = np.min(x, axis=1, keepdims=True)
    xmax = np.max(x, axis=1, keepdims=True)
    gain = (ymax - ymin) / np.where(xmax == xmin, 1.0, xmax - xmin)
    settings = {"xmin": xmin, "xmax": xmax, "gain": gain, "ymin": ymin, "ymax": ymax}
    return (x - xmin) * gain + ymin, settings


def mapminmax_apply(x: np.ndarray, settings: dict) -> np.ndarray:
    x = np.asarray(x, dtype=float)
    return (x - settings["xmin"]) * settings["gain"] + settings["ymin"]


def load_net219_numeric(path: Path):
    m = io.loadmat(path, squeeze_me=True)
    weights = {
        "IW": np.asarray(m["IW"], dtype=float).reshape(50, 5),
        "LW": np.asarray(m["LW"], dtype=float).reshape(1, 50),
        "b1": np.asarray(m["b1"], dtype=float).reshape(50, 1),
        "b2": np.asarray(m["b2"], dtype=float).reshape(1, 1),
        "xmin": np.asarray(m["xmin"], dtype=float).reshape(5),
        "xmax": np.asarray(m["xmax"], dtype=float).reshape(5),
    }
    return weights, float(m["ymin"]), float(m["ymax"])


def forward_net219(features: np.ndarray, model) -> np.ndarray:
    weights, ymin, ymax = model
    x = np.asarray(features, dtype=float)
    if x.ndim == 1:
        x = x[:, None]
    scale = (ymax - ymin) / np.where(weights["xmax"] == weights["xmin"], 1.0, weights["xmax"] - weights["xmin"])
    x = (x - weights["xmin"][:, None]) * scale[:, None] + ymin
    hidden = np.tanh(weights["IW"] @ x + weights["b1"])
    return (weights["LW"] @ hidden + weights["b2"]).reshape(-1)


def classify_feature_rows(feature_rows: np.ndarray, quiet_settings: dict, model) -> np.ndarray:
    mapped = mapminmax_apply(np.asarray(feature_rows, dtype=float).T, quiet_settings)
    return forward_net219(mapped, model)


def _slope_candidates(values: np.ndarray, sensitivity: float, window: int = 6) -> np.ndarray:
    """Translate the optional MATLAB slope classification branch."""
    candidates = []
    for end in range(window - 1, len(values)):
        vec = values[end - window + 1 : end + 1]
        if np.isnan(vec).any():
            continue
        outliers = np.abs(vec - np.mean(vec)) > np.std(vec)
        usable = ~outliers
        if usable.sum() < 2:
            continue
        slope = np.polyfit(np.arange(1, window + 1)[usable], vec[usable], 1)[0]
        if slope >= sensitivity * 0.4:
            candidates.append(end)
    return np.asarray(candidates, dtype=int)


def find_seizures(
    outputs: np.ndarray,
    sensitivity: float = SENSITIVITY_DEFAULT,
    duration: int = DURATION_DEFAULT,
    interval: float = INTERVAL_DEFAULT,
    classification_mode: tuple[bool, bool] = CLASSIFICATION_MODE_DEFAULT,
) -> tuple[np.ndarray, np.ndarray]:
    """Apply OG nVision threshold/slope classification and duration statistics."""
    values = np.asarray(outputs, dtype=float).reshape(-1)
    candidates = []
    if classification_mode[0] and len(values) >= duration:
        hits = np.isfinite(values) & (values > sensitivity)
        rolling = np.convolve(hits.astype(int), np.ones(duration, dtype=int), mode="valid") >= duration
        candidates.extend((np.flatnonzero(rolling) + duration - 1).tolist())
    if classification_mode[1]:
        candidates.extend(_slope_candidates(values, sensitivity))
    accepted_endpoints = []
    for index in sorted(set(candidates)):
        if not accepted_endpoints or index > accepted_endpoints[-1] + interval * 60:
            accepted_endpoints.append(int(index))

    event_starts = np.empty(len(accepted_endpoints), dtype=int)
    durations = np.zeros((7, len(accepted_endpoints)), dtype=float)
    window_size = max(1, int(interval * 60))
    for n, event_index in enumerate(accepted_endpoints):
        onset = max(0, event_index - duration + 1)
        event_starts[n] = onset
        end = min(len(values), onset + 60)
        run = values[onset:end] >= sensitivity
        seizure_length = int(np.argmax(~run)) if (~run).any() else len(run)
        durations[0, n] = seizure_length
        window = values[onset : min(len(values), onset + window_size)]
        positive = window[np.isfinite(window) & (window >= sensitivity)]
        finite = window[np.isfinite(window)]
        last_epoch = int(np.flatnonzero(np.isfinite(window) & (window >= sensitivity))[-1] + 1) if positive.size else 0
        durations[1, n] = last_epoch
        durations[2, n] = positive.size
        durations[3, n] = positive.size / last_epoch if last_epoch else 0
        durations[4, n] = positive.mean() if positive.size else np.nan
        durations[5, n] = finite[:last_epoch].mean() if last_epoch else np.nan
        durations[6, n] = finite.mean() if finite.size else np.nan
    return event_starts, durations


def _json_value(value):
    if isinstance(value, (float, np.floating)) and not np.isfinite(value):
        return None
    return value


def export_result_json(
    path: Path,
    event_starts: np.ndarray,
    network_output: np.ndarray,
    feature_rows: np.ndarray,
    rate: int,
    threshold: float,
    quiet_start: float,
    quiet_length: float,
    sensitivity: float,
    duration: int,
    interval: float,
    classification_mode: tuple[bool, bool],
    durations: np.ndarray,
) -> Path:
    output = np.asarray(network_output, dtype=float).reshape(-1)
    payload = {
        "format": "nVision-python-result-v1",
        "sample_rate_hz": int(rate),
        "noise_threshold": float(threshold),
        "sensitivity": float(sensitivity),
        "duration_seconds": int(duration),
        "interval_minutes": float(interval),
        "classification_mode": [bool(v) for v in classification_mode],
        "quiet_reference_start_seconds": float(quiet_start),
        "quiet_reference_seconds": float(quiet_length),
        "feature_names": FEATURE_NAMES,
        "feature_shape": list(np.asarray(feature_rows).shape),
        "network_output": [_json_value(v) for v in output.tolist()],
        "events": [
            {"start_epoch": int(index), "start_seconds": int(index),
             "duration": [None if not np.isfinite(v) else float(v) for v in durations[:, n]]}
            for n, index in enumerate(np.asarray(event_starts).reshape(-1))
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return path


def calculate_features(
    input_path: Path,
    filter_path: Path,
    rate: int = RATE_DEFAULT,
    threshold: float = THRESHOLD_DEFAULT,
) -> dict:
    """Load a recording and calculate its five-feature rows."""
    raw = read_dat_float32(input_path)
    if raw.size == 0:
        raise ValueError("The input recording is empty or unreadable.")
    hp, lp = load_rate_filters(filter_path.parent, rate)
    features = process_feature_chunks(raw, rate, threshold, hp, lp)
    return {
        "raw": raw,
        "features": features,
        "hp": hp,
        "lp": lp,
        "rate": rate,
        "threshold": threshold,
        "signal_preview": signal_preview(raw, rate),
        "sample_count": int(raw.size),
    }


def classify_prepared_features(
    prepared: dict,
    network_path: Path,
    quiet_start: int = 0,
    quiet_length: int = 60,
    sensitivity: float = SENSITIVITY_DEFAULT,
    duration: int = DURATION_DEFAULT,
    interval: float = INTERVAL_DEFAULT,
    classification_mode: tuple[bool, bool] = CLASSIFICATION_MODE_DEFAULT,
) -> dict:
    """Normalize prepared features, classify them, and find seizure events."""
    raw = np.asarray(prepared["raw"])
    rate = int(prepared["rate"])
    if quiet_start < 0 or quiet_length <= 0:
        raise ValueError("The quiet reference must have a positive duration and non-negative start.")
    quiet_end = (quiet_start + quiet_length) * rate
    if raw.size < quiet_end:
        raise ValueError(
            f"The recording is too short for the quiet reference: requires "
            f"{quiet_end / rate:.0f} seconds, has {raw.size / rate:.1f} seconds."
        )
    quiet_begin = quiet_start * rate
    quiet_features = winny_all(raw[quiet_begin:quiet_end], rate, prepared["threshold"], prepared["hp"], prepared["lp"])
    _, quiet_settings = mapminmax_fit(quiet_features.T)
    model = load_net219_numeric(network_path)
    network_output = classify_feature_rows(prepared["features"], quiet_settings, model)
    events, durations = find_seizures(network_output, sensitivity, duration, interval, classification_mode)
    return {
        "network_output": network_output,
        "events": events,
        "durations": durations,
        "quiet_start": quiet_start,
        "quiet_length": quiet_length,
        "sensitivity": sensitivity,
        "duration": duration,
        "interval": interval,
        "classification_mode": classification_mode,
    }


def run_pipeline(
    input_path: Path,
    output_path: Path,
    filter_path: Path,
    network_path: Path,
    quiet_start: int = 660,
    quiet_length: int = 60,
    rate: int = RATE_DEFAULT,
    threshold: float = THRESHOLD_DEFAULT,
    sensitivity: float = SENSITIVITY_DEFAULT,
    duration: int = DURATION_DEFAULT,
    interval: float = INTERVAL_DEFAULT,
    classification_mode: tuple[bool, bool] = CLASSIFICATION_MODE_DEFAULT,
    use_features: np.ndarray | None = None,
) -> dict:
    if use_features is not None and np.asarray(use_features).tolist() != [True, False, True, True] + [False] * 16 + [True, True] + [False] * 4:
        raise ValueError("The exported net_219 configuration requires OG features [1, 3, 4, 21, 22].")
    prepared = calculate_features(input_path, filter_path, rate, threshold)
    classified = classify_prepared_features(
        prepared, network_path, quiet_start, quiet_length, sensitivity,
        duration, interval, classification_mode,
    )
    raw = prepared["raw"]
    features = prepared["features"]
    network_output = classified["network_output"]
    events = classified["events"]
    durations = classified["durations"]
    export_result_json(output_path, events, network_output, features, rate, threshold, quiet_start, quiet_length,
                       sensitivity, duration, interval, classification_mode, durations)
    feature_output = output_path.with_name(output_path.stem + "_features.csv")
    analysis_output = output_path.with_name(output_path.stem + "_analysis.mat")
    np.savetxt(feature_output, features, delimiter=",", header=",".join(FEATURE_NAMES), comments="")
    io.savemat(analysis_output, {
        "allfeat_nomap": features.T,
        "network_output": network_output,
        "starts": events,
        "durations": durations,
        "rate": rate,
        "threshold": threshold,
        "sensitivity": sensitivity,
        "duration": duration,
        "interval": interval,
        "classification_mode": np.asarray(classification_mode, dtype=np.uint8),
        "feature_names": np.asarray(FEATURE_NAMES, dtype=object),
    })
    return {
        "output_path": str(output_path),
        "feature_output": str(feature_output),
        "analysis_output": str(analysis_output),
        "feature_rows": len(features),
        "events": events,
        "durations": durations,
        "feature_rows_data": features,
        "network_output": network_output,
        "signal_preview": prepared["signal_preview"],
        "sample_count": int(raw.size),
    }
