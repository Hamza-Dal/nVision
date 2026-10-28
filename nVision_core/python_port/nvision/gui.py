"""Minimal desktop interface for the license-free nVision pipeline."""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from scipy import io
from PySide6.QtCore import QObject, QThread, Signal, Slot, Qt, QPoint
from PySide6.QtGui import QColor, QFont, QPainter, QPen, QPolygon
from PySide6.QtCore import QUrl
from PySide6.QtGui import QDesktopServices
from PySide6.QtWidgets import (
    QApplication, QFileDialog, QFormLayout, QHBoxLayout, QLabel, QLineEdit,
    QMainWindow, QMessageBox, QPushButton, QComboBox, QDoubleSpinBox,
    QSpinBox, QStatusBar, QTableWidget, QTableWidgetItem, QVBoxLayout,
    QWidget, QHeaderView, QScrollBar, QDialog, QDialogButtonBox, QGridLayout, QSplitter,
    QSizePolicy,
)
import pyqtgraph as pg

from .pipeline import (
    CLASSIFICATION_MODE_DEFAULT,
    DURATION_DEFAULT,
    INTERVAL_DEFAULT,
    SENSITIVITY_DEFAULT,
    THRESHOLD_DEFAULT,
    calculate_features,
    classify_prepared_features,
    export_result_json,
    read_dat_segment,
    resolve_core_file,
)


FEATURE_NAMES = (
    "mean_square", "std", "absolute_difference_sum",
    "power_fraction_12_20hz", "power_fraction_20_40hz",
)
FLOAT32_BYTES = np.dtype("<f4").itemsize
CROP_COPY_BYTES = 4 * 1024 * 1024


def crop_filename(folder: Path, source: Path, start_sample: int, end_sample: int, rate: int,
                  part: int, total_parts: int) -> Path:
    """Return a non-overwriting filename that documents the saved time range."""
    start_seconds, end_seconds = start_sample / rate, end_sample / rate
    suffix = f"_part-{part:03d}" if total_parts > 1 else ""
    stem = f"{source.stem}_crop_{start_seconds:g}s-{end_seconds:g}s{suffix}"
    candidate, duplicate = folder / f"{stem}.dat", 2
    while candidate.exists():
        candidate = folder / f"{stem}_{duplicate}.dat"
        duplicate += 1
    return candidate


class WorkWorker(QObject):
    finished = Signal(object)
    failed = Signal(str)
    status = Signal(str)

    def __init__(self, operation: str, input_path: Path, output_dir: Path, rate: int,
                 noise_threshold: float = THRESHOLD_DEFAULT,
                 sensitivity: float = SENSITIVITY_DEFAULT,
                 duration: int = DURATION_DEFAULT,
                 interval: float = INTERVAL_DEFAULT,
                 classification_mode: tuple[bool, bool] = CLASSIFICATION_MODE_DEFAULT,
                 quiet_start: int = 0, quiet_length: int = 60, prepared: dict | None = None) -> None:
        super().__init__()
        self.operation, self.input_path, self.output_dir = operation, input_path, output_dir
        self.rate, self.quiet_start, self.quiet_length = rate, quiet_start, quiet_length
        self.noise_threshold = noise_threshold
        self.sensitivity, self.duration, self.interval = sensitivity, duration, interval
        self.classification_mode = classification_mode
        self.prepared = prepared

    @Slot()
    def run(self) -> None:
        try:
            package_root = Path(__file__).resolve().parents[1]
            filter_path = resolve_core_file(package_root, "HP_fs200_fc2_order200.mat")
            network_path = resolve_core_file(package_root, "net_219_numeric.mat")
            prepared = self.prepared
            if prepared is None:
                self.status.emit("Calculating features…")
                prepared = calculate_features(self.input_path, filter_path, self.rate, self.noise_threshold)
            feature_path = self.output_dir / "nvision_features.csv"
            np.savetxt(feature_path, prepared["features"], delimiter=",", header=",".join(FEATURE_NAMES), comments="")
            if self.operation == "features":
                self.finished.emit({"prepared": prepared, "feature_path": feature_path})
                return

            self.status.emit("Finding seizures…")
            classified = classify_prepared_features(
                prepared, network_path, self.quiet_start, self.quiet_length,
                self.sensitivity, self.duration, self.interval, self.classification_mode,
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


class CropWorker(QObject):
    """Copy selected float32 sample ranges without materializing the source recording."""

    finished = Signal(object)
    failed = Signal(str)
    status = Signal(str)

    def __init__(self, input_path: Path, destination: Path,
                 ranges: list[tuple[int, int]], rate: int) -> None:
        super().__init__()
        self.input_path, self.destination, self.ranges, self.rate = input_path, destination, ranges, rate

    @Slot()
    def run(self) -> None:
        try:
            created: list[Path] = []
            total = len(self.ranges)
            for part, (start_sample, end_sample) in enumerate(self.ranges, start=1):
                self.status.emit(f"Saving crop {part} of {total}…")
                target = crop_filename(
                    self.destination, self.input_path, start_sample, end_sample,
                    self.rate, part, total,
                )
                remaining = (end_sample - start_sample) * FLOAT32_BYTES
                with self.input_path.open("rb") as source, target.open("xb") as output:
                    source.seek(start_sample * FLOAT32_BYTES)
                    while remaining:
                        block = source.read(min(CROP_COPY_BYTES, remaining))
                        if not block:
                            raise OSError("The recording ended before the requested crop range.")
                        output.write(block)
                        remaining -= len(block)
                created.append(target)
            self.finished.emit(created)
        except Exception as exc:
            self.failed.emit(str(exc))


class TraceViewer(pg.GraphicsLayoutWidget):
    """Two linked plots for the visible raw trace and ANN output."""

    range_changed = Signal(float, float)

    def __init__(self) -> None:
        super().__init__()
        self.setBackground("#10161b")
        self.raw_plot = self.addPlot(row=0, col=0)
        self.ann_plot = self.addPlot(row=1, col=0)
        self.raw_plot.setLabel("left", "Signal", size="14pt")
        self.ann_plot.setLabel("left", "ANN output", size="14pt")
        self.ann_plot.setLabel("bottom", "Time", units="s", size="14pt")
        for plot in (self.raw_plot, self.ann_plot):
            plot.showGrid(x=True, y=True, alpha=0.3)
            for axis_name in ("left", "bottom"):
                axis = plot.getAxis(axis_name)
                axis.setPen(pg.mkPen("#afc5cf"))
                axis.setTextPen(pg.mkPen("#e6f2f6"))
                axis.setStyle(tickFont=QFont("Arial", 12), tickTextOffset=8)
        self.raw_plot.setMouseEnabled(x=True, y=True)
        self.ann_plot.setMouseEnabled(x=True, y=True)
        self.ann_plot.setXLink(self.raw_plot)
        self.raw_curve = self.raw_plot.plot(pen=pg.mkPen("#67c8e8", width=1))
        self.ann_curve = self.ann_plot.plot(pen=pg.mkPen("#c795e8", width=1.2))
        self.threshold_line = pg.InfiniteLine(
            pos=1.0, angle=0, pen=pg.mkPen("#c43d3d", style=Qt.PenStyle.DashLine)
        )
        self.ann_plot.addItem(self.threshold_line)
        self._event_regions: list[tuple[pg.LinearRegionItem, pg.LinearRegionItem]] = []
        self.raw_plot.getViewBox().sigXRangeChanged.connect(self._emit_range)

    def _emit_range(self, _view_box: object, value_range: tuple[float, float]) -> None:
        self.range_changed.emit(float(value_range[0]), float(value_range[1]))

    def set_trace(self, times: np.ndarray, values: np.ndarray) -> None:
        self.raw_curve.setData(times, values)
        if values.size:
            self.raw_plot.enableAutoRange(axis="y", enable=True)

    def set_ann(self, times: np.ndarray, values: np.ndarray) -> None:
        self.ann_curve.setData(times, values)
        if values.size:
            lower = min(0.0, float(np.nanmin(values)))
            upper = max(1.1, float(np.nanmax(values)))
            padding = max(0.05, (upper - lower) * 0.08)
            self.ann_plot.setYRange(lower - padding, upper + padding, padding=0)

    def set_x_range(self, start: float, end: float) -> None:
        self.raw_plot.setXRange(start, end, padding=0)

    def set_events(self, events: np.ndarray, durations: np.ndarray, start: float, end: float) -> None:
        for raw_region, ann_region in self._event_regions:
            self.raw_plot.removeItem(raw_region)
            self.ann_plot.removeItem(ann_region)
        self._event_regions.clear()
        for index, event in enumerate(events):
            event_start = float(event)
            event_duration = max(0.0, float(durations[0, index]))
            event_end = event_start + event_duration
            if event_end < start or event_start > end:
                continue
            regions = []
            for plot in (self.raw_plot, self.ann_plot):
                region = pg.LinearRegionItem(
                    values=(event_start, event_end), orientation="vertical", movable=False,
                    brush=pg.mkBrush(196, 61, 61, 55), pen=pg.mkPen(196, 61, 61, 150),
                )
                plot.addItem(region)
                regions.append(region)
            self._event_regions.append((regions[0], regions[1]))


def draw_spin_arrows(widget: QWidget) -> None:
    """Draw high-contrast arrow glyphs because platform arrows can disappear in dark Qt themes."""
    painter = QPainter(widget)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.setBrush(QColor("#e6f2f6"))
    painter.setPen(Qt.PenStyle.NoPen)
    right = widget.width() - 15
    painter.drawPolygon(QPolygon([QPoint(right - 6, 15), QPoint(right + 6, 15), QPoint(right, 8)]))
    bottom = widget.height() - 9
    painter.drawPolygon(QPolygon([QPoint(right - 6, bottom - 7), QPoint(right + 6, bottom - 7), QPoint(right, bottom)]))
    painter.end()


class VisibleArrowSpinBox(QSpinBox):
    def paintEvent(self, event: object) -> None:
        super().paintEvent(event)
        draw_spin_arrows(self)


class VisibleArrowDoubleSpinBox(QDoubleSpinBox):
    def paintEvent(self, event: object) -> None:
        super().paintEvent(event)
        draw_spin_arrows(self)


class AdaptiveTimeSpinBox(VisibleArrowDoubleSpinBox):
    """Store seconds while presenting compact whole-second, minute, or hour text."""

    def __init__(self) -> None:
        super().__init__()
        self.setDecimals(0)

    @staticmethod
    def _unit_for(seconds: float) -> tuple[float, str]:
        if seconds <= 180:
            return 1.0, "s"
        if seconds <= 360 * 60:
            return 60.0, "min"
        return 3600.0, "h"

    def textFromValue(self, value: float) -> str:
        scale, unit = self._unit_for(value)
        return f"{round(value / scale):.0f} {unit}"

    def valueFromText(self, text: str) -> float:
        parts = text.strip().lower().split()
        try:
            value = float(parts[0])
        except (IndexError, ValueError):
            return self.value()
        units = {"s": 1.0, "sec": 1.0, "seconds": 1.0, "min": 60.0, "m": 60.0,
                 "minutes": 60.0, "h": 3600.0, "hr": 3600.0, "hours": 3600.0}
        scale = units.get(parts[1], self._unit_for(self.value())[0]) if len(parts) > 1 else self._unit_for(self.value())[0]
        return value * scale

    def stepBy(self, steps: int) -> None:
        scale, _ = self._unit_for(self.value())
        self.setValue(self.value() + steps * scale)


class VisibleArrowComboBox(QComboBox):
    def paintEvent(self, event: object) -> None:
        super().paintEvent(event)
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(QColor("#e6f2f6"), 2.5))
        right, middle = self.width() - 13, self.height() // 2
        painter.drawLine(right - 6, middle - 3, right, middle + 3)
        painter.drawLine(right, middle + 3, right + 6, middle - 3)
        painter.end()


class NeuroWeaveCard(QPushButton):
    """Clickable brand card using NeuroWeave's compact brain-mark geometry."""

    def __init__(self) -> None:
        super().__init__("GitHub")
        self.setProperty("actionCard", True)
        self.setMinimumSize(190, 88)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        self.setToolTip("Open the nVision project on GitHub")

    def paintEvent(self, event: object) -> None:
        super().paintEvent(event)
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)
        painter.setPen(QPen(QColor("#dce9ed"), 2))
        scale, offset_x, offset_y = 1.2, 10, 23
        left = [(16, 5), (14, 3), (11, 3), (9, 5), (6, 5), (4, 8),
                (4, 11), (2, 13), (2, 17), (4, 20), (4, 23), (7, 27),
                (11, 28), (14, 26), (16, 23)]
        right = [(32 - x, y) for x, y in left]
        def point(value: tuple[int, int]) -> tuple[int, int]:
            return (round(offset_x + value[0] * scale), round(offset_y + value[1] * scale))
        for points in (left, right):
            for start, end in zip(points, points[1:]):
                a, b = point(start), point(end)
                painter.drawLine(a[0], a[1], b[0], b[1])
        for points in (((16, 5), (16, 27)), ((9, 5), (10, 10), (7, 12)),
                       ((23, 5), (22, 10), (25, 12)), ((4, 20), (9, 20), (11, 24)),
                       ((28, 20), (23, 20), (21, 24))):
            for start, end in zip(points, points[1:]):
                a, b = point(start), point(end)
                painter.drawLine(a[0], a[1], b[0], b[1])
        painter.end()


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
        self._updating_view = False

        self.input_edit = QLineEdit(); self.input_edit.setPlaceholderText("Select a headerless float32 .dat recording")
        self.rate_combo = VisibleArrowComboBox(); self.rate_combo.addItems(["200", "500", "1000"])
        self.rate_combo.currentTextChanged.connect(self.rate_changed)
        self.noise_threshold_spin = VisibleArrowDoubleSpinBox(); self.noise_threshold_spin.setRange(0.0, 1_000_000.0); self.noise_threshold_spin.setDecimals(2); self.noise_threshold_spin.setSingleStep(0.01); self.noise_threshold_spin.setValue(THRESHOLD_DEFAULT)
        self.sensitivity_spin = VisibleArrowDoubleSpinBox(); self.sensitivity_spin.setRange(0.0, 1_000_000.0); self.sensitivity_spin.setDecimals(2); self.sensitivity_spin.setSingleStep(0.01); self.sensitivity_spin.setValue(SENSITIVITY_DEFAULT)
        self.duration_spin = VisibleArrowSpinBox(); self.duration_spin.setRange(1, 86_400); self.duration_spin.setSuffix(" s"); self.duration_spin.setValue(DURATION_DEFAULT)
        self.interval_spin = VisibleArrowSpinBox(); self.interval_spin.setRange(1, 604_800); self.interval_spin.setValue(INTERVAL_DEFAULT)
        self.interval_unit_combo = VisibleArrowComboBox(); self.interval_unit_combo.addItem("min", "minutes"); self.interval_unit_combo.addItem("s", "seconds")
        self.output_edit = QLineEdit()
        self.window_spin = VisibleArrowSpinBox(); self.window_spin.setRange(1, 86400); self.window_spin.setValue(60); self.window_spin.setSuffix(" s"); self.window_spin.valueChanged.connect(self.window_changed)
        self.position_scroll = QScrollBar(Qt.Orientation.Horizontal); self.position_scroll.setRange(0, 0); self.position_scroll.valueChanged.connect(self.scroll_view_changed)
        self.reset_view_button = QPushButton("Reset view"); self.reset_view_button.clicked.connect(self.reset_view)
        self.view_label = QLabel("Visible: —")
        self.visible_duration_label = QLabel("Visible duration")
        for control in (self.visible_duration_label, self.window_spin, self.reset_view_button, self.view_label):
            control.setFixedSize(180, 38)
        self.settings_dialog = self.create_settings_dialog()
        self.crop_dialog = self.create_crop_dialog()

        self.select_recording_card = self.action_card("Select recording", self.select_input)
        self.output_folder_card = self.action_card("Output folder", self.select_output)
        self.detection_settings_card = self.action_card("Detection\nsettings", self.show_settings_dialog)
        self.reset_card = self.action_card("Reset", self.reset_session)
        self.quiet_card = self.action_card("Select current\nview as quiet", self.select_current_quiet)
        self.crop_card = self.action_card("Crop recording", self.show_crop_dialog)
        self.seizures_button = self.action_card("Find seizures", self.find_seizures_clicked)
        self.brand_card = NeuroWeaveCard(); self.brand_card.clicked.connect(self.open_project_github)

        controls = QGridLayout()
        controls.setHorizontalSpacing(18); controls.setVerticalSpacing(14)
        cards = (
            (self.select_recording_card, 0, 0), (self.output_folder_card, 0, 1),
            (self.detection_settings_card, 0, 2), (self.reset_card, 0, 3),
            (self.crop_card, 1, 0), (self.quiet_card, 1, 1),
            (self.seizures_button, 1, 2), (self.brand_card, 1, 3),
        )
        for card, row, column in cards: controls.addWidget(card, row, column)
        for column in range(4): controls.setColumnStretch(column, 1)

        nav_row = QHBoxLayout()
        nav_row.setSpacing(10)
        nav_row.addWidget(self.visible_duration_label); nav_row.addWidget(self.window_spin)
        nav_row.addWidget(self.position_scroll, 1); nav_row.addWidget(self.reset_view_button); nav_row.addWidget(self.view_label)
        navigation = QWidget(); navigation.setObjectName("traceNavigation"); navigation.setLayout(nav_row)

        self.summary = QLabel("Select a recording to begin.")
        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(["Event", "Start (s)", "Duration (s)", "Mean output", "Positive epochs"])
        self.table.setSelectionBehavior(QTableWidget.SelectRows); self.table.setMinimumWidth(320)
        self.table.horizontalHeader().setSectionResizeMode(QHeaderView.Stretch); self.table.itemSelectionChanged.connect(self.event_selected)
        self.canvas = TraceViewer(); self.canvas.range_changed.connect(self.viewer_range_changed)

        results_panel = QVBoxLayout()
        self.detected_events_label = QLabel("Detected events")
        self.detected_events_label.setStyleSheet("font-size: 19px; font-weight: 600;")
        results_panel.addWidget(self.detected_events_label, alignment=Qt.AlignmentFlag.AlignTop)
        results_panel.addWidget(self.table, 1)
        results_widget = QWidget(); results_widget.setLayout(results_panel)
        self.results_splitter = QSplitter(Qt.Orientation.Horizontal)
        self.results_splitter.setChildrenCollapsible(False)
        self.results_splitter.addWidget(self.canvas)
        self.results_splitter.addWidget(results_widget)
        self.results_splitter.setStretchFactor(0, 3); self.results_splitter.setStretchFactor(1, 1)
        self.results_splitter.setSizes([1500, 400])
        central = QWidget(); layout = QVBoxLayout(central); layout.addLayout(controls); layout.addWidget(navigation); layout.addWidget(self.summary); layout.addWidget(self.results_splitter, 1)
        self.setCentralWidget(central); self.setStatusBar(QStatusBar())
        self.bbbscience_label = QLabel("bbbscience.com")
        self.statusBar().addPermanentWidget(self.bbbscience_label)
        self.apply_control_panel_style()

    def action_card(self, label: str, callback: object | None = None) -> QPushButton:
        card = QPushButton(label)
        card.setProperty("actionCard", True)
        card.setMinimumSize(190, 88)
        card.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
        if callback is not None: card.clicked.connect(callback)
        return card

    def create_settings_dialog(self) -> QDialog:
        dialog = QDialog(self)
        dialog.setWindowTitle("Detection settings")
        dialog.setModal(True)
        form = QFormLayout(dialog)
        form.addRow("Sampling rate, Hz", self.rate_combo)
        form.addRow("Noise threshold", self.noise_threshold_spin)
        form.addRow("Sensitivity", self.sensitivity_spin)
        form.addRow("Minimum seizure duration, s", self.duration_spin)
        interval_row = QHBoxLayout(); interval_row.addWidget(self.interval_spin); interval_row.addWidget(self.interval_unit_combo)
        form.addRow("Minimum seizure interval, min or s", interval_row)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel)
        defaults_button = buttons.addButton("Defaults", QDialogButtonBox.ButtonRole.ResetRole)
        defaults_button.clicked.connect(self.reset_detection_defaults)
        buttons.accepted.connect(dialog.accept); buttons.rejected.connect(dialog.reject)
        form.addRow(buttons)
        return dialog

    def create_crop_dialog(self) -> QDialog:
        dialog = QDialog(self)
        dialog.setWindowTitle("Crop recording")
        dialog.setModal(True)
        form = QFormLayout(dialog)
        self.crop_start_spin = AdaptiveTimeSpinBox()
        self.crop_end_spin = AdaptiveTimeSpinBox()
        self.crop_mode_combo = VisibleArrowComboBox()
        self.crop_mode_combo.addItem("Single clip", "single")
        self.crop_mode_combo.addItem("Split into segments", "segments")
        self.crop_segment_spin = AdaptiveTimeSpinBox(); self.crop_segment_spin.setRange(1, 1_000_000_000); self.crop_segment_spin.setValue(600)
        self.crop_destination_edit = QLineEdit(); self.crop_destination_edit.setReadOnly(True)
        choose_destination = QPushButton("Choose folder…"); choose_destination.clicked.connect(self.select_crop_destination)
        self.crop_destination_edit.setFixedHeight(38); choose_destination.setFixedHeight(38)
        destination_row = QHBoxLayout(); destination_row.addWidget(self.crop_destination_edit); destination_row.addWidget(choose_destination)
        form.addRow("Start time", self.crop_start_spin)
        form.addRow("End time", self.crop_end_spin)
        form.addRow("Save", destination_row)
        form.addRow("Mode", self.crop_mode_combo)
        form.addRow("Segment duration", self.crop_segment_spin)
        self.crop_mode_combo.currentIndexChanged.connect(self.update_crop_mode)
        buttons = QDialogButtonBox(QDialogButtonBox.StandardButton.Save | QDialogButtonBox.StandardButton.Cancel)
        buttons.accepted.connect(dialog.accept); buttons.rejected.connect(dialog.reject)
        form.addRow(buttons)
        self.update_crop_mode()
        return dialog

    @Slot()
    def update_crop_mode(self) -> None:
        self.crop_segment_spin.setEnabled(self.crop_mode_combo.currentData() == "segments")

    @Slot()
    def select_crop_destination(self) -> None:
        path = QFileDialog.getExistingDirectory(self.crop_dialog, "Choose crop destination")
        if path:
            self.crop_destination_edit.setText(path)

    @Slot()
    def show_crop_dialog(self) -> None:
        if self.input_path is None or self.preview is None:
            QMessageBox.warning(self, "Recording required", "Select a recording before creating a crop.")
            return
        if self.worker_thread is not None:
            QMessageBox.information(self, "Operation in progress", "Wait for the current operation to finish before cropping.")
            return
        length = self.preview["sample_count"] / int(self.rate_combo.currentText())
        start = float(self.view_start)
        end = min(length, start + self.window_spin.value())
        self.crop_start_spin.setRange(0.0, length); self.crop_end_spin.setRange(0.0, length)
        self.crop_start_spin.setValue(start); self.crop_end_spin.setValue(end)
        self.crop_destination_edit.clear()
        if self.crop_dialog.exec() != QDialog.DialogCode.Accepted:
            return
        destination_text = self.crop_destination_edit.text().strip()
        if not destination_text:
            QMessageBox.warning(self, "Destination required", "Choose a folder for the cropped recording.")
            return
        self.start_crop(Path(destination_text), length)

    def start_crop(self, destination: Path, recording_length: float) -> None:
        start, end = self.crop_start_spin.value(), self.crop_end_spin.value()
        if start < 0 or end > recording_length or start >= end:
            QMessageBox.warning(self, "Invalid time range", "Start and end must be within the recording, with end after start.")
            return
        rate = int(self.rate_combo.currentText())
        start_sample = int(round(start * rate)); end_sample = int(round(end * rate))
        if start_sample >= end_sample:
            QMessageBox.warning(self, "Invalid time range", "The selected range contains no complete samples.")
            return
        if self.crop_mode_combo.currentData() == "segments":
            segment_samples = int(round(self.crop_segment_spin.value() * rate))
            if segment_samples <= 0:
                QMessageBox.warning(self, "Invalid segment duration", "Segment duration must be greater than zero.")
                return
            ranges = [(sample, min(sample + segment_samples, end_sample)) for sample in range(start_sample, end_sample, segment_samples)]
        else:
            ranges = [(start_sample, end_sample)]
        try:
            destination.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            QMessageBox.critical(self, "Crop destination error", str(exc))
            return
        self.seizures_button.setEnabled(False); self.crop_card.setEnabled(False)
        self.worker_thread = QThread(self)
        self.worker = CropWorker(self.input_path, destination, ranges, rate)
        self.worker.moveToThread(self.worker_thread)
        self.worker_thread.started.connect(self.worker.run)
        self.worker.status.connect(self.statusBar().showMessage)
        self.worker.finished.connect(self.crop_finished); self.worker.failed.connect(self.processing_failed)
        self.worker.finished.connect(self.worker_thread.quit); self.worker.failed.connect(self.worker_thread.quit)
        self.worker_thread.finished.connect(self.worker_done)
        self.worker_thread.start()

    @Slot(object)
    def crop_finished(self, files: list[Path]) -> None:
        self.statusBar().showMessage(f"Saved {len(files)} cropped recording{'s' if len(files) != 1 else ''} to {files[0].parent}")

    def show_settings_dialog(self) -> None:
        original = (
            self.rate_combo.currentIndex(), self.noise_threshold_spin.value(),
            self.sensitivity_spin.value(), self.duration_spin.value(),
            self.interval_spin.value(), self.interval_unit_combo.currentIndex(),
        )
        if self.settings_dialog.exec() == QDialog.DialogCode.Accepted:
            self.statusBar().showMessage("Detection settings updated.")
            return
        self.rate_combo.setCurrentIndex(original[0])
        self.noise_threshold_spin.setValue(original[1])
        self.sensitivity_spin.setValue(original[2])
        self.duration_spin.setValue(original[3])
        self.interval_spin.setValue(original[4])
        self.interval_unit_combo.setCurrentIndex(original[5])

    @Slot()
    def reset_detection_defaults(self) -> None:
        self.rate_combo.setCurrentText("200")
        self.noise_threshold_spin.setValue(THRESHOLD_DEFAULT)
        self.sensitivity_spin.setValue(SENSITIVITY_DEFAULT)
        self.duration_spin.setValue(DURATION_DEFAULT)
        self.interval_spin.setValue(INTERVAL_DEFAULT)
        self.interval_unit_combo.setCurrentIndex(0)

    def selected_interval_minutes(self) -> float:
        interval = float(self.interval_spin.value())
        return interval / 60.0 if self.interval_unit_combo.currentData() == "seconds" else interval

    def apply_control_panel_style(self) -> None:
        self.setStyleSheet("""
            QMainWindow, QWidget {
                background: #151a1e; color: #e6f2f6; font-size: 14px;
            }
            QLabel { background: transparent; }
            QPushButton[actionCard="true"] {
                background: #1f6d8d; color: white; border: 2px solid #0d3548;
                border-radius: 0; font-size: 19px; font-weight: 600; padding: 10px;
            }
            QPushButton[actionCard="true"]:hover { background: #2b83a5; }
            QPushButton[actionCard="true"]:focus { border: 3px solid #93d4e8; }
            QPushButton[actionCard="true"]:disabled {
                background: #607078; color: #c2cbd0; border-color: #48565c;
            }
            QWidget#traceNavigation {
                background: #24313a; border: 1px solid #3f5966; padding: 8px;
                color: #e6f2f6; font-size: 19px;
            }
            QWidget#traceNavigation QLabel, QWidget#traceNavigation QSpinBox,
            QWidget#traceNavigation QPushButton { font-size: 19px; }
            QDialog { background: #20282e; color: #e6f2f6; }
            QComboBox, QDoubleSpinBox, QSpinBox, QLineEdit {
                background: #10161b; color: #f5fbfd; border: 1px solid #557180;
                padding: 4px; min-height: 24px; font-size: 16px;
            }
            QComboBox::drop-down {
                subcontrol-origin: border; subcontrol-position: top right;
                width: 30px; border-left: 1px solid #557180;
            }
            QComboBox::down-arrow { image: none; width: 0; height: 0; }
            QSpinBox::up-button, QDoubleSpinBox::up-button {
                subcontrol-origin: border; subcontrol-position: top right;
                width: 30px; height: 18px; border-left: 1px solid #557180;
            }
            QSpinBox::down-button, QDoubleSpinBox::down-button {
                subcontrol-origin: border; subcontrol-position: bottom right;
                width: 30px; height: 18px; border-left: 1px solid #557180;
            }
            QSpinBox::up-arrow, QDoubleSpinBox::up-arrow {
                width: 10px; height: 10px;
            }
            QSpinBox::down-arrow, QDoubleSpinBox::down-arrow {
                width: 10px; height: 10px;
            }
            QTableWidget { background: #10161b; color: #e6f2f6; gridline-color: #38515d; }
            QHeaderView::section { background: #24313a; color: #e6f2f6; padding: 6px; border: 0; }
            QSplitter::handle:horizontal { background: #4e6e7b; width: 8px; }
            QScrollBar:horizontal { background: #10161b; height: 16px; margin: 0; }
            QScrollBar::handle:horizontal { background: #559ac0; min-width: 30px; }
            QPushButton:not([actionCard="true"]) {
                background: #345363; color: #f5fbfd; border: 1px solid #628394; padding: 5px;
            }
            QStatusBar { background: #151a1e; color: #a9cbd8; border: 0; font-size: 14px; }
            QStatusBar::item { border: 0; }
        """)

    @Slot()
    def open_project_github(self) -> None:
        QDesktopServices.openUrl(QUrl("https://github.com/Hamza-Dal/nVision"))

    @Slot()
    def reset_session(self) -> None:
        self.input_path = None; self.preview = None; self.result = None
        self.input_edit.clear(); self.output_edit.clear(); self.table.setRowCount(0)
        self.view_start, self.quiet_start, self.quiet_length = 0, 0, 60
        self.reset_detection_defaults()
        self.window_spin.setValue(60)
        self.position_scroll.setRange(0, 0); self.view_label.setText("Visible: —")
        self.canvas.set_trace(np.empty(0), np.empty(0))
        self.canvas.set_ann(np.empty(0), np.empty(0))
        self.canvas.set_events(np.empty(0), np.empty((7, 0)), 0, 0)
        self.summary.setText("Select a recording to begin.")
        self.statusBar().showMessage("Session reset.")

    @Slot()
    def select_input(self) -> None:
        path, _ = QFileDialog.getOpenFileName(self, "Select recording", "", "Data files (*.dat);;All files (*)")
        if not path: return
        self.input_path = Path(path); self.input_edit.setText(path); self.output_edit.setText(str(self.input_path.parent / "outputs")); self.result = None; self.table.setRowCount(0); self.view_start = 0; self.load_preview()
        self.summary.setText(f"Recording selected: {self.input_path.name}  |  Output: {self.output_edit.text()}")
        self.statusBar().showMessage(f"Recording selected: {self.input_path.name}")

    def load_preview(self) -> None:
        if self.input_path is None: return
        try:
            sample_count = self.input_path.stat().st_size // np.dtype("<f4").itemsize
            if sample_count == 0: raise ValueError("The input recording is empty or unreadable.")
            self.preview = {"sample_count": int(sample_count)}
            self.configure_view_controls()
            self.set_view(0)
        except Exception as exc: QMessageBox.critical(self, "Recording error", str(exc))

    @Slot()
    def select_output(self) -> None:
        path = QFileDialog.getExistingDirectory(self, "Select output folder")
        if path:
            self.output_edit.setText(path)
            self.summary.setText(f"Output folder selected: {path}")
            self.statusBar().showMessage(f"Output folder selected: {path}")

    def output_dir(self) -> Path | None:
        if self.input_path is None: QMessageBox.warning(self, "Input required", "Select a recording first."); return None
        output = Path(self.output_edit.text().strip() or str(self.input_path.parent / "outputs"))
        try: output.mkdir(parents=True, exist_ok=True); return output
        except OSError as exc: QMessageBox.critical(self, "Output error", str(exc)); return None

    def start_worker(self, operation: str) -> None:
        output = self.output_dir()
        if output is None or self.input_path is None: return
        self.seizures_button.setEnabled(False); self.crop_card.setEnabled(False); self.worker_thread = QThread(self)
        prepared = (
            self.result if operation == "seizures" and self.result is not None
            and "features" in self.result
            and float(self.result["threshold"]) == self.noise_threshold_spin.value()
            else None
        )
        self.worker = WorkWorker(
            operation, self.input_path, output, int(self.rate_combo.currentText()),
            self.noise_threshold_spin.value(), self.sensitivity_spin.value(),
            self.duration_spin.value(), self.selected_interval_minutes(), CLASSIFICATION_MODE_DEFAULT,
            self.quiet_start, self.quiet_length, prepared,
        ); self.worker.moveToThread(self.worker_thread)
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
        if self.preview is None: self.preview = {"sample_count": prepared["sample_count"]}
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
        self.summary.setText(f"Recording: {length:.1f} s  |  Windows: {len(self.result['features'])}  |  Detected events: {count}  |  Quiet: {self.quiet_start}–{self.quiet_start + self.quiet_length} s  |  Noise: {self.result['threshold']:.2f}  |  Sensitivity: {self.result.get('sensitivity', self.sensitivity_spin.value()):.2f}")

    @Slot(str)
    def processing_failed(self, message: str) -> None: QMessageBox.critical(self, "nVision error", message); self.statusBar().showMessage("Operation failed")

    @Slot()
    def worker_done(self) -> None:
        self.seizures_button.setEnabled(True); self.crop_card.setEnabled(True); self.worker = None; self.worker_thread = None

    def max_start(self) -> int:
        if self.preview is None: return 0
        return max(0, int(self.preview["sample_count"] / int(self.rate_combo.currentText()) - self.window_spin.value()))

    def set_view(self, start: float) -> None:
        self._updating_view = True
        try:
            self.view_start = max(0, min(int(start), self.max_start()))
            self.configure_view_controls()
            self.draw_plots()
        finally:
            self._updating_view = False

    def configure_view_controls(self) -> None:
        if self.preview is None: return
        self._updating_view = True
        try:
            duration = self.window_spin.value()
            self.position_scroll.setRange(0, self.max_start())
            self.position_scroll.setPageStep(duration)
            self.position_scroll.setSingleStep(max(1, duration // 10))
            self.position_scroll.setValue(self.view_start)
            handle_width = max(42, min(260, 42 + int(180 * min(duration, 1800) / 1800)))
            self.position_scroll.setStyleSheet(f"""
                QScrollBar:horizontal {{ background: #10161b; height: 22px; margin: 0; }}
                QScrollBar::handle:horizontal {{ background: #559ac0; min-width: {handle_width}px; }}
                QScrollBar::add-line:horizontal, QScrollBar::sub-line:horizontal {{ width: 0; }}
            """)
        finally:
            self._updating_view = False

    @Slot(int)
    def scroll_view_changed(self, value: int) -> None:
        if not self._updating_view: self.set_view(value)

    @Slot()
    def reset_view(self) -> None:
        self.set_view(0)

    def window_changed(self) -> None: self.set_view(self.view_start)

    @Slot(float, float)
    def viewer_range_changed(self, start: float, end: float) -> None:
        if self._updating_view or self.preview is None: return
        recording_length = self.preview["sample_count"] / int(self.rate_combo.currentText())
        duration = max(1, min(int(round(end - start)), max(1, int(np.ceil(recording_length)))))
        clamped_start = max(0, min(start, max(0.0, recording_length - duration)))
        self._updating_view = True
        try:
            self.window_spin.blockSignals(True); self.window_spin.setValue(duration); self.window_spin.blockSignals(False)
            self.view_start = int(clamped_start)
            self.configure_view_controls()
            self.draw_plots()
        finally:
            self._updating_view = False

    def select_current_quiet(self) -> None:
        if self.preview is None:
            QMessageBox.warning(self, "Recording required", "Select a recording before choosing a quiet view.")
            return
        self.quiet_start, self.quiet_length = self.view_start, self.window_spin.value(); self.update_summary(); self.statusBar().showMessage(f"Quiet reference set to {self.quiet_start}–{self.quiet_start + self.quiet_length} s")

    @staticmethod
    def format_view_time(seconds: float) -> str:
        seconds = max(0.0, float(seconds))
        if seconds <= 360:
            return f"{round(seconds):.0f} s"
        minutes = seconds / 60.0
        if minutes <= 1800:
            return f"{round(minutes):.0f} min"
        return f"{round(seconds / 3600.0):.0f} h"

    def draw_plots(self) -> None:
        if self.preview is None: return
        rate = int(self.rate_combo.currentText())
        recording_length = self.preview["sample_count"] / rate
        start = float(self.view_start)
        end = min(recording_length, start + self.window_spin.value())
        sample_start = int(start * rate)
        sample_count = max(0, int(np.ceil((end - start) * rate)))
        trace = read_dat_segment(self.input_path, sample_start, sample_count) if self.input_path else np.empty(0)
        max_display_points = 20_000
        step = max(1, int(np.ceil(trace.size / max_display_points)))
        trace_times = start + np.arange(0, trace.size, step, dtype=float) / rate
        self.canvas.set_trace(trace_times, trace[::step])
        if self.result is not None and "network_output" in self.result:
            output = np.asarray(self.result["network_output"])
            output_start = max(0, int(np.floor(start)))
            output_end = min(output.size, int(np.ceil(end)) + 1)
            self.canvas.set_ann(np.arange(output_start, output_end, dtype=float), output[output_start:output_end])
            self.canvas.set_events(
                np.asarray(self.result.get("events", [])),
                np.asarray(self.result.get("durations", np.empty((7, 0)))), start, end,
            )
        else:
            self.canvas.set_ann(np.empty(0), np.empty(0))
            self.canvas.set_events(np.empty(0), np.empty((7, 0)), start, end)
        self.canvas.set_x_range(start, end)
        self.view_label.setText(f"Visible: {self.format_view_time(start)}–{self.format_view_time(end)}")

    @Slot()
    def event_selected(self) -> None:
        if self.result is None or self.table.currentRow() < 0:
            return
        row = self.table.currentRow()
        event_start = float(self.result["events"][row])
        event_duration = max(1.0, float(self.result["durations"][0, row]))
        visible_duration = max(1, int(np.ceil(event_duration * 2)))
        self.window_spin.setValue(visible_duration)
        self.set_view(event_start - event_duration / 2)


def main() -> int:
    app = QApplication(sys.argv); app.setFont(QFont("Arial", 11)); window = MainWindow(); window.showMaximized(); return app.exec()


if __name__ == "__main__": raise SystemExit(main())
