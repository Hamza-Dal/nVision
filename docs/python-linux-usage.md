# nVision Python and Linux usage

The Python port does not require MATLAB. It reads headerless little-endian
float32 `.dat` recordings and supports acquisition rates of 200, 500, and
1000 Hz.

## Windows PowerShell

From the Windows working copy:

```powershell
cd "C:\Users\mstrh\Downloads\Work\nVision Linux port\nVision_core\python_port"

python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

Launch the desktop GUI:

```powershell
.\.venv\Scripts\python.exe -m nvision.gui
```

The GUI lets you select a recording and sampling rate, navigate the recording,
select the current view as the quiet reference, calculate features, find
seizures, review events, and choose the output folder.

Run the command-line detector instead:

```powershell
.\.venv\Scripts\python.exe -m nvision `
  "C:\path\to\recording.dat" `
  --rate 200 `
  --output outputs\result.json
```

The CLI uses the standard 660–720 second quiet reference unless
`--quiet-start` and `--quiet-length` are supplied. The GUI uses the selected
quiet view, initially 0–60 seconds.

## Native Ubuntu or Debian desktop

Clone the repository into the Linux filesystem, then run the Linux setup:

```bash
git clone https://github.com/Hamza-Dal/nVision.git ~/nVision
cd ~/nVision/nVision_core/python_port

sudo apt install python3-venv
chmod +x setup_linux.sh run_nvision.sh run_nvision_gui.sh
./setup_linux.sh
```

Launch the GUI from a normal X11 or Wayland desktop session:

```bash
./run_nvision_gui.sh
```

Run the CLI:

```bash
./run_nvision.sh /path/to/recording.dat --rate 200 --output outputs/result.json
```

The GUI launcher checks that the local Linux `.venv` exists and that a display
session is available. It exits with an explanation if either requirement is
missing.

## WSL on this Windows machine

The Windows checkout is available through WSL at this exact path:

```bash
cd "/mnt/c/Users/mstrh/Downloads/Work/nVision Linux port/nVision_core/python_port"
```

The Windows `.venv` cannot be reused by Linux. If this is the same shared
checkout, recreate only the environment before running Linux:

```bash
rm -rf .venv
chmod +x setup_linux.sh run_nvision.sh run_nvision_gui.sh
./setup_linux.sh
./run_nvision_gui.sh
```

The GUI will open from WSL only when WSLg or another X11/Wayland display
configuration is available. Without GUI support, use the CLI launcher or use a
native Ubuntu desktop.

## Output files

When the GUI finds seizures, it writes these files to the selected output
folder:

- `nvision_result.json`: detection results and event metadata.
- `nvision_features.csv`: calculated five-feature rows.
- `nvision_result_analysis.mat`: MATLAB-compatible analysis arrays.

The CLI writes the JSON file specified by `--output` and creates matching
feature and analysis files beside it.

## Common problems

### `No such file or directory`

The terminal is not inside `nVision_core/python_port`. Run `pwd` and then use
the appropriate `cd` command above.

### `chmod: command not found`

The command was entered in PowerShell. Run the Linux commands in Ubuntu or a
WSL terminal. PowerShell uses the `.venv\\Scripts\\python.exe` commands shown
above.

### `Missing .venv`

Run `./setup_linux.sh` from `nVision_core/python_port` first.

### `No graphical Linux session detected`

The Linux GUI needs a desktop display. Use a native Ubuntu desktop, WSLg, or
run the CLI instead.
