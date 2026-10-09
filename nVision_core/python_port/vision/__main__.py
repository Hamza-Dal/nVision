"""Command-line entry point for python -m vision."""

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
    parser.add_argument("--rate", type=int, default=200)
    parser.add_argument("--threshold", type=float, default=1.2)
    parser.add_argument("--filter", dest="filter_path", type=Path)
    parser.add_argument("--network", dest="network_path", type=Path)
    args = parser.parse_args()

    package_root = Path(__file__).resolve().parents[1]
    filter_path = args.filter_path or package_root.parent / "HP_fs200_fc2_order200.mat"
    network_path = args.network_path or package_root.parent / "net_219_numeric.mat"
    result = run_pipeline(
        args.input,
        args.output,
        filter_path,
        network_path,
        args.quiet_start,
        args.quiet_length,
        args.rate,
        args.threshold,
    )
    print(result["output_path"])
    print(f"Feature rows: {result['feature_rows']}")
    print(f"Detected events: {len(result['events'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
