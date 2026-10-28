# Changelog

All notable changes to nVision are documented in this file.

## [0.2.0] - 2026-10-28

### Desktop viewer and navigation

- Replaced the Matplotlib display with a native PyQtGraph viewer containing a raw ECoG trace and synchronized ANN-output panel.
- Added drag-to-pan, mouse-wheel zoom, a recording-position scrollbar, visible-duration control, reset view, and readable time-range display.
- Render only the visible raw-data slice and decimate it when needed, keeping long recordings responsive.
- Display detected seizures as synchronized shaded regions across both panels and retain the ANN threshold reference line.
- Made the detected-events panel resizable and made event selection frame the selected seizure with context.

### Detection correctness and workflow

- Corrected exported and displayed seizure onsets to the first qualifying ANN epoch; duration, regions, navigation, JSON, CSV/MAT outputs, and returned results now use the corrected onset.
- Preserved existing interval/debounce behavior and ANN calculation.
- Moved detector controls into a confirmation-based Detection settings dialog with defaults restoration.
- Find seizures now calculates features when they are absent and reuses compatible cached features when available.
- Kept threshold classification as the desktop-GUI mode while retaining command-line classification options.
- Added an in-place Reset that clears session data and restores defaults without restarting the application.

### Crop recording

- Replaced automatic quiet-zone selection with Crop recording.
- Added single-clip and fixed-duration split-clip export for selected time ranges.
- Copy raw float32 `.dat` bytes in bounded chunks, avoiding full-file memory allocation for large recordings.
- Preserve the source recording, prevent accidental overwrites, and run crop jobs in the background with status feedback.

### Interface and distribution

- Redesigned the control area as dark-themed action cards for recording selection, output selection, settings, reset, crop, quiet selection, detection, and GitHub.
- Added clearer duration units, improved control arrows, contrast, font sizing, and panel alignment.
- Added the nVision GitHub card and a `bbbscience.com` footer label.
- Added PyQtGraph as a runtime dependency.
- Released and tagged version `0.2.0`; version `0.1.0` remains preserved as a Git tag.

## [0.1.0]

Initial tagged Python-port release.
