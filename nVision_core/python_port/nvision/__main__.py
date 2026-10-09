"""Command-line entry point for python -m nvision."""

from __future__ import annotations

import argparse
from pathlib import Path

from .pipeline import run_pipeline


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the five-feature nVision detector.")
    parser.add_argument("input", type=Path, help="float32 .dat ECoG input")
    parser.add_argument("--quiet-start", type=int, default=660, help="quiet-window start in seconds")
    parser.add_argument("--quiet-length", type=int, default=60, help="quiet-window length in seconds")
    parser.add_argument("--output", type=Path, default=Path("nvision_result.json"))
    parser.add_argument("--rate", type=int, choices=(200, 500, 1000), default=200)
    parser.add_argument("--threshold", type=float, default=1.2)
    parser.add_argument("--sensitivity", type=float, default=1.0)
    parser.add_argument("--duration", type=int, default=6, help="minimum seizure duration in seconds")
    parser.add_argument("--interval", type=int, default=1, help="minimum interval between events in minutes")
    parser.add_argument("--classification-mode", choices=("threshold", "slope", "both"), default="threshold")
    parser.add_argument("--filter", dest="filter_path", type=Path)
    parser.add_argument("--network", dest="network_path", type=Path)
    args = parser.parse_args()

    classification_mode = {
        "threshold": (True, False),
        "slope": (False, True),
        "both": (True, True),
    }[args.classification_mode]

    package_root = Path(__file__).resolve().parents[1]
    filter_path = args.filter_path or package_root.parent / "HP_fs200_fc2_order200.mat"
    network_path = args.network_path or package_root / "net_219_numeric.mat"
    result = run_pipeline(
        args.input,
        args.output,
        filter_path,
        network_path,
        args.quiet_start,
        args.quiet_length,
        args.rate,
        args.threshold,
        args.sensitivity,
        args.duration,
        args.interval,
        classification_mode,
    )
    print(result["output_path"])
    print(f"Feature rows: {result['feature_rows']}")
    print(f"Detected events: {len(result['events'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
