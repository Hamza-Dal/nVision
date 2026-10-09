# nVision Python port

This package contains the five-feature Python path for nVision. It uses the
exported `net_219_numeric.mat` weights and does not require MATLAB at runtime.

Run from this directory:

```powershell
python -m nvision "C:\path\to\recording.dat" --rate 200 --quiet-start 660 --quiet-length 60
```

Use `--rate 200`, `--rate 500`, or `--rate 1000`. The 1000 Hz path applies the
original 250 Hz low-pass filter, decimates to 500 Hz, and then applies the
500 Hz 2 Hz high-pass filter. The 200 and 500 Hz paths use their original
high-pass filters.

Detection settings are configurable with `--threshold`, `--sensitivity`,
`--duration`, `--interval`, and `--classification-mode` (`threshold`, `slope`,
or `both`). The default settings match the OG nVision defaults: threshold 1.2,
sensitivity 1, duration 6 seconds, interval 1 minute, and threshold
classification.

The default output is `nvision_result.json` in the current directory. The run
also writes a feature CSV and an analysis MAT file beside it. Use `--output` to
choose another output path.

The implementation supports the three OG sampling-rate paths, the five-feature
classifier using features `[1, 3, 4, 21, 22]`, quiet normalization, threshold
and slope classification, event duration statistics, and JSON/CSV/MAT export.

## Linux setup

On Linux, from this directory:

```bash
chmod +x setup_linux.sh run_nvision.sh
./setup_linux.sh
./run_nvision.sh /path/to/recording.dat --rate 200 --output outputs/result.json
```

The scripts use a local `.venv`; MATLAB is not required. The input must be the
headerless little-endian float32 `.dat` format used by nVision. The `--rate`
value must match the recording's acquisition rate. Linux users need
`python3-venv` and a normal desktop display session for the GUI.

## Graphical interface

Install the GUI dependencies with the same setup script, then launch:

```bash
chmod +x setup_linux.sh run_nvision.sh run_nvision_gui.sh
./setup_linux.sh
./run_nvision_gui.sh
```

The GUI requires a normal Ubuntu desktop session using X11 or Wayland. It uses
the same Python pipeline as the CLI. Select a `.dat` recording, choose its
acquisition rate, select an output folder, calculate features, and find
seizures. The GUI writes the JSON result, feature CSV, and analysis MAT file
to the selected output folder.

For complete Windows, native Ubuntu, and WSL instructions, see
[`docs/python-linux-usage.md`](../../docs/python-linux-usage.md).
