# nVision

Linux/WSL port of the nVision seizure-detection algorithm, preserving the MATLAB reference implementation and five-feature processing pipeline.

* * *

## ◈ What is nVision?

nVision processes intracranial EEG recordings through filtering, segmentation, feature extraction, normalization, ANN classification, and sliding-window thresholding.

* * *

## ◈ Architecture

![nVision C4 container diagram](docs/nvision-c4-container.svg)

* * *

## ◈ Installation

### MATLAB reference

nVision requires a current MATLAB installation with these toolboxes:

- Signal Processing
- Deep Learning
- Statistics and Machine Learning

1. Download and unzip the repository.
2. Set MATLAB's Current Folder to the nVision folder.
3. Run `nvision2013_parameters_5_vs_26_g_new.m`.

Toolboxes can be installed through `Apps > Get More Apps` in MATLAB.

### Linux / WSL port

```bash
cd nVision_core/python_port
bash setup_linux.sh
bash run_nvision.sh
```

* * *

## ◈ Figure 1

<p align="center"><img src="docs/figures/nvision-figure-1.jpg" alt="Figure 1" /></p>
<p align="center"><em>Trace sample of mouse iEEG. (A) 1100 s of an iEEG trace containing a *seizure and ^noise. (B) Magnified view of the seizure segment. (C) System block diagram. The telemetrically acquired iEEG signals are filtered and divided into 2‐s segments with a 1‐s overlap. Features are extracted from each segment, normalized, and fed to the ANN for classification. The ANN output undergoes sliding window‐thresholding to produce the time coordinates of the detected events. (D) The architecture of the constructed ANN. An input layer of 5 nodes, a hidden layer of 50 neurons, and a single neuron output layer.</em></p>

* * *

## ◈ Figure 3

<p align="center"><img src="docs/figures/nvision-figure-3.jpg" alt="Figure 3" /></p>
<p align="center"><em>Graphical user interface. Upper panel: (A) 1 h iEEG trace containing a detected seizure (indicated with *) in a recording of a pilocarpine‐treated mouse. (B) The five normalized features representing the displayed trace. (C) The corresponding output of the ANN. (D) Coordinates of all 9 detected seizures in the 3‐day‐long recording. Lower panel: 60 s display of the above seizure.</em></p>

* * *

## ◈ Figure 4

<p align="center"><img src="docs/figures/nvision-figure-4.jpg" alt="Figure 4" /></p>
<p align="center"><em>Seizure detection in injured and aged rats. (A) TBI is linked with a higher occurrence of seizure events that are longer in duration (B). (C) In TBI animals, a significantly larger proportion of SLEs were simultaneously detected by two or more electrodes compared to controls (p &lt; 0.0001; two‐way ANOVA). (D) Average seizure frequency in older (9–12 and 12–18 months) is significantly higher compared to young rats (2 months). (E) The proportion of animals with seizures is higher in animals older than 9 months compared to 2‐month‐old rats. (F) Representative traces and corresponding ANN score from epidural and hippocampal recordings in rats. *p &lt; 0.05; **p &lt; 0.01; ***p &lt; 0.001; ****p &lt; 0.0001.</em></p>

* * *

## ◈ Reference

Kamintsky L, van Hameren G, Weissberg I, Moradi P, Prager O, Ahmad AA, et al. [An algorithm for seizure detection in rodents](https://doi.org/10.1002/epi4.70070). *Epilepsia Open*. 2025. Open access under the [CC BY-NC-ND 4.0 license](https://creativecommons.org/licenses/by-nc-nd/4.0/).

* * *

nVision is currently maintained and curated by Hamza Imtiaz.
