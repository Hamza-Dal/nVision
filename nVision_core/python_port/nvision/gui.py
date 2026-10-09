"""Minimal desktop interface for the license-free nVision pipeline."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from scipy import io
from PySide6.QtCore import QObject, QThread, Signal, Slot
from PySide6.QtGui import QFont
from PySide6.QtWidgets import (
    QApplication, QFileDialog, QFormLayout, QHBoxLayout, QLabel, QLineEdit,
    QMainWindow, QMessageBox, QPushButton, QComboBox, QDoubleSpinBox,
    QSpinBox, QStatusBar, QTableWidget, QTableWidgetItem, QVBoxLayout,
    QWidget, QHeaderView,
)

import matplotlib

matplotlib.use("QtAgg")
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from matplotlib.figure import Figure

from .pipeline import (
    calculate_features,
    classify_prepared_features,
    export_result_json,
    read_dat_float32,
    read_dat_segment,
    signal_preview,
)


FEATURE_NAMES = (
    "mean_square", "std", "absolute_difference_sum",
    "power_fraction_12_20hz", "power_fraction_20_40hz",
)


class WorkWorker(QObject):
    finished = Signal(object)
    failed = Signal(str)
    status = Signal(str)

    def __init__(self, operation: str, input_path: Path, output_dir: Path, rate: int,
                 quiet_start: int = 0, quiet_length: int = 60, prepared: dict | None = None) -> None:
        super().__init__()
        self.operation, self.input_path, self.output_dir = operation, input_path, output_dir
        self.rate, self.quiet_start, self.quiet_length = rate, quiet_start, quiet_length
        self.prepared = prepared

    @Slot()
    def run(self) -> None:
        try:
            package_root = Path(__file__).resolve().parents[1]
            filter_path = package_root.parent / "HP_fs200_fc2_order200.mat"
            network_path = package_root / "net_219_numeric.mat"
            prepared = self.prepared
            if prepared is None:
                self.status.emit("Calculating features…")
                prepared = calculate_features(self.input_path, filter_path, self.rate)
            feature_path = self.output_dir / "nvision_features.csv"
            np.savetxt(feature_path, prepared["features"], delimiter=",", header=",".join(FEATURE_NAMES), comments="")
            if self.operation == "features":
                self.finished.emit({"prepared": prepared, "feature_path": feature_path})
                return

            self.status.emit("Finding seizures…")
            classified = classify_prepared_features(
                prepared, network_path, self.quiet_start, self.quiet_length,
            )
            output_path = self.output_dir / "nvision_result.json"
            events, durations = classified["events"], classified["durations"]
            export_result_json(
                output_path, events, classified["network_output"], prepared["features"],
                self.rate, prepared["threshold"], self.quiet_start, self.quiet_length,
                classified["sensitivity"], classified["duration"], classified["interval"],
                classified["classification_mode"], durations,
            )
            analysis_path = output_path.with_name(output_path.stem + "_analysis.mat")
            io.savemat(analysis_path, {
                "allfeat_nomap": prepared["features"].T,
                "network_output": classified["network_output"], "starts": events,
                "durations": durations, "rate": self.rate, "threshold": prepared["threshold"],
                "sensitivity": classified["sensitivity"], "duration": classified["duration"],
                "interval": classified["interval"],
                "classification_mode": np.asarray(classified["classification_mode"], dtype=np.uint8),
                "feature_names": np.asarray(FEATURE_NAMES, dtype=object),
            })
            self.finished.emit({
                "prepared": prepared, "classified": classified,
                "output_path": output_path, "feature_path": feature_path,
                "analysis_path": analysis_path,
            })
        except Exception as exc:
            self.failed.emit(str(exc))


class PlotCanvas(FigureCanvas):
    def __init__(self) -> None:
        self.figure = Figure(figsize=(12, 10), tight_layout=False)
        grid = self.figure.add_gridspec(3, 1, height_ratios=(1.25, 1.25, 1.0))
        self.overview = self.figure.add_subplot(grid[0, 0])
        self.detail = self.figure.add_subplot(grid[1, 0])
        self.ann = self.figure.add_subplot(grid[2, 0])
        self.figure.subplots_adjust(left=0.14, right=0.98, top=0.96, bottom=0.07, hspace=0.85)
        super().__init__(self.figure)


class MainWindow(QMainWindow):
    def __init__(self) -> None:
        super().__init__()
        self.setWindowTitle("nVision — seizure detection")
        self.resize(1500, 1000)
        self.result: dict | None = None
        self.preview: dict | None = None
        self.input_path: Path | None = None
        self.worker_thread: QThread | None = None
        self.worker: QObject | None = None
        self.view_start, self.quiet_start, self.quiet_length = 0, 0, 60

        self.input_edit = QLineEdit(); self.input_edit.setPlaceholderText("Select a headerless float32 .dat recording")
        input_button = QPushButton("Browse…"); input_button.clicked.connect(self.select_input)
        self.rate_combo = QComboBox(); self.rate_combo.addItems(["200", "500", "1000"])
        self.rate_combo.currentTextChanged.connect(self.rate_changed)
        self.output_edit = QLineEdit(); output_button = QPushButton("Browse…"); output_button.clicked.connect(self.select_output)
        self.window_spin = QSpinBox(); self.window_spin.setRange(1, 86400); self.window_spin.setValue(60); self.window_spin.valueChanged.connect(self.window_changed)
        self.goto_spin = QDoubleSpinBox(); self.goto_spin.setRange(0, 1_000_000_000); self.goto_spin.setDecimals(1); self.goto_spin.setSuffix(" s")
        goto_button = QPushButton("Go to time"); goto_button.clicked.connect(self.go_to_time)
        self.quiet_button = QPushButton("Select current view as quiet"); self.quiet_button.clicked.connect(self.select_current_quiet)
        self.features_button = QPushButton("Calculate features"); self.features_button.clicked.connect(self.calculate_features_clicked)
        self.seizures_button = QPushButton("Find seizures"); self.seizures_button.clicked.connect(self.find_seizures_clicked)
        self.previous_button = QPushButton("◀ Previous"); self.previous_button.clicked.connect(lambda: self.shift_view(-1))
        self.next_button = QPushButton("Next ▶"); self.next_button.clicked.connect(lambda: self.shift_view(1))
        self.start_button = QPushButton("|◀ Start"); self.start_button.clicked.connect(lambda: self.set_view(0))
        self.end_button = QPushButton("End ▶|"); self.end_button.clicked.connect(self.go_to_end)

        form = QFormLayout()
        input_row = QHBoxLayout(); input_row.addWidget(self.input_edit); input_row.addWidget(input_button); form.addRow("Recording", input_row)
        form.addRow("Sampling rate (Hz)", self.rate_combo)
        output_row = QHBoxLayout(); output_row.addWidget(self.output_edit); output_row.addWidget(output_button); form.addRow("Output folder", output_row)
        nav_row = QHBoxLayout()
        nav_row.addWidget(QLabel("Window size (s)")); nav_row.addWidget(self.window_spin); nav_row.addWidget(QLabel("Go to")); nav_row.addWidget(self.goto_spin); nav_row.addWidget(goto_button)
        nav_row.addWidget(self.start_button); nav_row.addWidget(self.previous_button); nav_row.addWidget(self.next_button); nav_row.addWidget(self.end_button)
        form.addRow("Time view", nav_row)
        action_row = QHBoxLayout(); action_row.addWidget(self.quiet_button); action_row.addWidget(self.features_button); action_row.addWidget(self.seizures_button); form.addRow("Actions", action_row)

        self.summary = QLabel("Select a recording to begin.")
        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(["Event", "Start (s)", "Duration (s)", "Mean output", "Positive epochs"])
        self.table.setSelectionBehavior(QTableWidget.SelectRows); self.table.setMinimumWidth(320)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch); self.table.itemSelectionChanged.connect(self.event_selected)
        self.canvas = PlotCanvas()

        results_panel = QVBoxLayout()
        results_panel.addWidget(QLabel("Detected events"))
        results_panel.addWidget(self.table, 1)
        results_row = QHBoxLayout()
        results_row.addWidget(self.canvas, 3)
        results_row.addLayout(results_panel, 1)
        central = QWidget(); layout = QVBoxLayout(central); layout.addLayout(form); layout.addWidget(self.summary); layout.addLayout(results_row, 1)
        self.setCentralWidget(central); self.setStatusBar(QStatusBar())

    @Slot()
    def select_input(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Select recording", "", "Data files (*.dat);;All files (*)")
        if not path: return
        self.input_path = Path(path); self.input_edit.setText(path); self.output_edit.setText(str(self.input_path.parent / "outputs")); self.result = None; self.table.setRowCount(0); self.view_start = 0; self.load_preview()

    def load_preview(self) -> None:
        if self.input_path is None: return
        try:
            raw = read_dat_float32(self.input_path)
            if raw.size == 0: raise ValueError("The input recording is empty or unreadable.")
            times, values = signal_preview(raw, int(self.rate_combo.currentText()))
            self.preview = {"sample_count": int(raw.size), "preview": (times, values)}; self.goto_spin.setMaximum(max(0.0, raw.size / int(self.rate_combo.currentText()))); self.draw_plots()
        except Exception as exc: QMessageBox.critical(self, "Recording error", str(exc))

    @Slot()
    def select_output(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Select output folder")
        if path: self.output_edit.setText(path)

    def output_dir(self) -> Path | None:
        if self.input_path is None: QMessageBox.warning(self, "Input required", "Select a recording first."); return None
        output = Path(self.output_edit.text().strip() or str(self.input_path.parent / "outputs"))
        try: output.mkdir(parents=True, exist_ok=True); return output
        except OSError as exc: QMessageBox.critical(self, "Output error", str(exc)); return None

    def start_worker(self, operation: str) -> None:
        output = self.output_dir()
        if output is None or self.input_path is None: return
        self.features_button.setEnabled(False); self.seizures_button.setEnabled(False); self.worker_thread = QThread(self)
        prepared = self.result if operation == "seizures" and self.result is not None and "features" in self.result else None
        self.worker = WorkWorker(operation, self.input_path, output, int(self.rate_combo.currentText()), self.quiet_start, self.quiet_length, prepared); self.worker.moveToThread(self.worker_thread)
        self.worker_thread.started.connect(self.worker.run); self.worker.status.connect(self.statusBar().showMessage); self.worker.finished.connect(self.processing_finished); self.worker.failed.connect(self.processing_failed); self.worker.finished.connect(self.worker_thread.quit); self.worker.failed.connect(self.worker_thread.quit); self.worker_thread.finished.connect(self.worker_done); self.worker_thread.start()

    @Slot()
    def calculate_features_clicked(self) -> None: self.start_worker("features")

    @Slot()
    def find_seizures_clicked(self) -> None:
        self.start_worker("seizures")

    @Slot(str)
    def rate_changed(self, _rate: str) -> None:
        if self.input_path is not None:
            self.result = None
            self.table.setRowCount(0)
            self.load_preview()

    @Slot(object)
    def processing_finished(self, payload: dict) -> None:
        prepared = payload["prepared"]
        if self.preview is None: self.preview = {"sample_count": prepared["sample_count"], "preview": prepared["signal_preview"]}
        self.result = {**prepared, **payload.get("classified", {}), "input_path": self.input_path}
        if "classified" in payload:
            self.populate_events(payload["classified"]); self.statusBar().showMessage(f"Complete — results saved to {payload['output_path']}")
        else: self.statusBar().showMessage(f"Features calculated — saved to {payload['feature_path']}")
        self.update_summary(); self.draw_plots()

    def populate_events(self, classified: dict) -> None:
        events, durations = np.asarray(classified["events"]), np.asarray(classified["durations"]); self.table.setRowCount(len(events))
        for row, event in enumerate(events):
            values = [str(row + 1), str(int(event)), f"{durations[0, row]:.1f}", f"{durations[4, row]:.3f}" if np.isfinite(durations[4, row]) else "—", f"{durations[2, row]:.0f}"]
            for col, value in enumerate(values): self.table.setItem(row, col, QTableWidgetItem(value))

    def update_summary(self) -> None:
        if self.result is None: return
        length = self.result["sample_count"] / self.result["rate"]; count = len(self.result.get("events", []))
        self.summary.setText(f"Recording: {length:.1f} s  |  Windows: {len(self.result['features'])}  |  Detected events: {count}  |  Quiet: {self.quiet_start}–{self.quiet_start + self.quiet_length} s")

    @Slot(str)
    def processing_failed(self, message: str) -> None: QMessageBox.critical(self, "nVision error", message); self.statusBar().showMessage("Operation failed")

    @Slot()
    def worker_done(self) -> None:
        self.features_button.setEnabled(True); self.seizures_button.setEnabled(True); self.worker = None; self.worker_thread = None

    def max_start(self) -> int:
        if self.preview is None: return 0
        return max(0, int(self.preview["sample_count"] / int(self.rate_combo.currentText()) - self.window_spin.value()))

    def set_view(self, start: float) -> None:
        self.view_start = max(0, min(int(start), self.max_start())); self.goto_spin.setValue(self.view_start); self.draw_plots()

    def shift_view(self, direction: int) -> None: self.set_view(self.view_start + direction * self.window_spin.value())
    def go_to_end(self) -> None: self.set_view(self.max_start())
    def go_to_time(self) -> None: self.set_view(self.goto_spin.value())
    def window_changed(self) -> None: self.set_view(self.view_start)

    def select_current_quiet(self) -> None:
        self.quiet_start, self.quiet_length = self.view_start, self.window_spin.value(); self.update_summary(); self.statusBar().showMessage(f"Quiet reference set to {self.quiet_start}–{self.quiet_start + self.quiet_length} s")

    def draw_plots(self) -> None:
        if self.preview is None: return
        axes = (self.canvas.overview, self.canvas.detail, self.canvas.ann)
        for axis in axes: axis.clear()
        times, values = self.preview["preview"]
        recording_length = self.preview["sample_count"] / int(self.rate_combo.currentText())
        context_length = min(recording_length, max(self.window_spin.value() * 10, 600))
        context_start = max(0, min(self.view_start - (context_length - self.window_spin.value()) / 2, recording_length - context_length))
        context_end = context_start + context_length
        context_mask = (times >= context_start) & (times <= context_end)
        axes[0].plot(times[context_mask], values[context_mask], linewidth=0.7, color="#315a7d")
        axes[0].axvspan(self.view_start, self.view_start + self.window_spin.value(), color="#e7a43b", alpha=0.25)
        if self.result is not None:
            for event in self.result.get("events", []): axes[0].axvline(int(event), color="#c43d3d", alpha=0.65)
        axes[0].set_xlim(context_start, context_end)
        axes[0].set_title(""); axes[0].set_xlabel(""); axes[0].set_ylabel("Signal")
        axes[0].text(-0.075, 0.5, f"Recording context\n({context_start:.0f}–{context_end:.0f} s)", transform=axes[0].transAxes, rotation=90, va="center", ha="center")
        rate = int(self.rate_combo.currentText()); start = self.view_start * rate; detail = read_dat_segment(self.input_path, start, self.window_spin.value() * rate) if self.input_path else np.empty(0); detail_time = self.view_start + np.arange(detail.size) / rate
        detail_end = min(recording_length, self.view_start + self.window_spin.value())
        axes[1].plot(detail_time, detail, linewidth=0.6, color="#315a7d"); axes[1].set_xlim(self.view_start, detail_end); axes[1].set_title(""); axes[1].set_xlabel(""); axes[1].set_ylabel("Signal")
        axes[1].ticklabel_format(axis="y", style="sci", scilimits=(0, 0), useMathText=True)
        axes[1].text(-0.075, 0.5, f"Current view\n({self.view_start}–{detail_end:.0f} s)", transform=axes[1].transAxes, rotation=90, va="center", ha="center")
        if self.result is not None and "network_output" in self.result:
            output = np.asarray(self.result["network_output"])
            output_times = np.arange(output.size, dtype=float)
            ann_mask = (output_times >= context_start) & (output_times <= context_end)
            axes[2].plot(output_times[ann_mask], output[ann_mask], linewidth=0.8, color="#754c9b")
            axes[2].axhline(1.0, color="#c43d3d", linestyle="--", linewidth=0.8)
            axes[2].set_xlim(context_start, context_end)
        axes[2].set_title(""); axes[2].set_xlabel("Time (s)"); axes[2].set_ylabel("Output")
        axes[2].text(-0.075, 0.5, "ANN output", transform=axes[2].transAxes, rotation=90, va="center", ha="center")
        self.canvas.draw_idle()

    @Slot()
    def event_selected(self) -> None:
        if self.result is not None and self.table.currentRow() >= 0: self.set_view(int(self.result["events"][self.table.currentRow()]))


def main() -> int:
    app = QApplication(sys.argv); app.setFont(QFont("Arial", 11)); window = MainWindow(); window.showMaximized(); return app.exec()


if __name__ == "__main__": raise SystemExit(main())
