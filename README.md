# BrainSense EEG — Synchronized Sensory Stimulation & EEG Recording

A research system for synchronized EEG data collection combining a 64-channel EEG system with a BrainSense in-ear EEG device. MATLAB orchestrates experiment protocols — including electrical/thermal stimulation and auditory steady-state response (ASSR) paradigms — while an Arduino handles real-time hardware control and EEG trigger generation.

---

## Table of Contents

- [System Overview](#system-overview)
- [Hardware Requirements](#hardware-requirements)
- [Software Requirements](#software-requirements)
- [Hardware Setup & Wiring](#hardware-setup--wiring)
- [Repository Structure](#repository-structure)
- [Stimulation Paradigms](#stimulation-paradigms)
  - [Electrical/Thermal Stimulation](#electricalthermal-stimulation)
  - [ASSR Auditory Stimulation](#assr-auditory-stimulation)
- [Running an Experiment](#running-an-experiment)
- [Experiment Protocol Details](#experiment-protocol-details)
- [EEG Trigger System](#eeg-trigger-system)
- [Serial Communication Protocol](#serial-communication-protocol)
- [Post-Processing](#post-processing)
- [Testing & Debugging](#testing--debugging)
- [Known Issues](#known-issues)

---

## System Overview

```
Experiment PC (MATLAB)
  |
  | Serial (9600 baud, binary float packets)
  |
Arduino Uno
  |-- Pins 8, 9, 10, 11 ──► Breadboard LEDs ──► EEG amplifier trigger input port
  |-- Pins 12, 13 ──────────► Electrical stimulator(s) (left / right / both)
  |                                                        |
  |                                                   EEG amplifier
  |                                                        |
  |                                                   EEG PC
  |                                              (Neuroscan SCAN 4.5)
  |                                          records EEG + event markers
```

The Experiment PC runs MATLAB and sends a 6-parameter command packet before each trial. The Arduino simultaneously drives the stimulator pins and pulses the EEG trigger lines, embedding event markers at the precise moment stimulation begins. The EEG PC (running Neuroscan SCAN 4.5) records the EEG data and trigger events. The two PCs are separate — the EEG recording must be started manually before running the experiment.

### Synchronization

The Arduino trigger system serves as the synchronization mechanism between the Experiment PC and the EEG PC. When MATLAB sends a stimulation command, the Arduino pulses the trigger pins, which the amplifier forwards to SCAN 4.5 as timestamped event markers. This embeds the experiment timing directly into the EEG recording, eliminating the need for clock synchronization between the two PCs.

> **Note:** The EEG PC may not have internet access, so recorded timestamps use relative time rather than absolute time. The trigger markers provide the ground truth for aligning stimulation events with EEG data.

---

## Hardware Requirements

- **Arduino Uno** (or compatible)
- **Breadboard** with LEDs connected to trigger pins for visual confirmation
- **Electrical stimulator** with TTL/digital input control (left and/or right channels)
- **EEG amplifier** with a digital trigger input port
- **Connector cable**: 8-pin top row + 1 ground pin bottom row, connecting Arduino (via breadboard) to amplifier
- USB cable (Arduino ↔ Experiment PC running MATLAB)

---

## Software Requirements

- **Neuroscan SCAN 4.5** (EEG recording software, runs on the EEG PC)
- **MATLAB** (R2019b or later recommended) with:
  - Signal Processing Toolbox (for `butter`, `filtfilt`)
  - Instrument Control Toolbox (for `serialport`)
  - [EEGLAB](https://sccn.ucsd.edu/eeglab/) (for post-processing — see [EEGLAB Setup](#eeglab-setup))
- **Arduino IDE** (for uploading firmware to the Arduino)

### EEGLAB Setup

1. Download EEGLAB from [sccn.ucsd.edu/eeglab](https://sccn.ucsd.edu/eeglab/) (requires name and affiliation).
   - Alternatively, install via MATLAB's Add-On Explorer.
2. Install the **Neuroscan `.cnt` import plugin**:
   - In EEGLAB, go to **File > Manage EEGLAB extensions**.
   - Search for and install the Neuroscan `.cnt` file reader plugin.
   - Verify it appears: the import option should be available under **File > Import data**.
3. Add EEGLAB to your MATLAB path:
   ```matlab
   addpath('path/to/eeglab');
   eeglab;  % launches GUI and adds subfolders to path
   ```

> **Note:** If you need additional EEGLAB extensions and the GUI plugin manager doesn't work, you may need to install them via the MATLAB terminal/command window.

---

## Hardware Setup & Wiring

### Arduino Pin Assignments

| Arduino Pin | Breadboard LED | Function |
|-------------|---------------|----------|
| 8 | Blue | EEG trigger bit 0 |
| 9 | Green | EEG trigger bit 1 |
| 10 | Yellow | EEG trigger bit 2 |
| 11 | Red | <!-- TODO: confirm function — not driven by firmware but blinks when code runs --> |
| 12 | — | Left stimulator channel (not currently connected) |
| 13 | — | Right stimulator channel (not currently connected) |

<!-- TODO: Confirm pin 11 function — red LED blinks when code runs but firmware doesn't drive pin 11 -->
<!-- TODO: Confirm whether pins 12/13 are needed for current experiment -->

### Breadboard to DB-25 Connector Wiring

The breadboard connects to the EEG amplifier via a DB-25 connector cable. The 8-pin connector on the breadboard side has 8 data pins on the top row and 1 ground pin on the bottom row.

**Signal pins (Arduino → LED → DB-25):**

| Wire # | Source | LED | DB-25 Pin |
|--------|--------|-----|-----------|
| 1 | Arduino pin 8 | Blue | 10 |
| 2 | Arduino pin 9 | Green | 11 |
| 3 | Arduino pin 10 | Yellow | 13 |
| 4 | Arduino pin 11 | Red | 12 |

**Ground pins (all tied together on the breadboard):**

| Wire # | Source | DB-25 Pin |
|--------|--------|-----------|
| 5 | GND | 9 |
| 6 | GND | 8 |
| 7 | GND | 7 |
| 8 | GND | 6 |
| GND | GND | 14 (bottom row) |

> **Note:** Wires 5–8 are all soldered together on the breadboard and connected to ground. Wire GND connects to pin 14 on the bottom row of the DB-25; all other wires connect to the top row.

> **Important:** After resoldering or reconnecting the connector, use the pin test (`test/pin_test.m`) to verify correct wiring.

### Uploading Arduino Firmware

1. Open `arduino/StimArd_12_EEG_Trigger/StimArd_12_EEG_Trigger.ino` in the Arduino IDE.
2. Select your board (Arduino Uno) and the correct COM port.
3. Upload the sketch.

---

## Repository Structure

```
brainsense-eeg/
├── arduino/
│   └── StimArd_12_EEG_Trigger/
│       └── StimArd_12_EEG_Trigger.ino   # Arduino firmware for stimulation & EEG triggering
├── stimulation/
│   ├── Stimulation_EEG_experiment.m     # Main electrical/thermal stimulation experiment
│   ├── playStereoTones.m               # Basic stereo tone generation utility
│   └── playStereoTones_ASSR.m          # ASSR auditory stimulation generator
├── analysis/
│   ├── bp_filter.m                     # Butterworth bandpass filter function
│   ├── bpfEEG_prep.m                   # EEG preprocessing script (EEGLAB)
│   └── do_fft.m                        # FFT analysis/visualization function
├── test/
│   ├── PinTest/
│   │   └── PinTest.ino                 # Arduino sketch for individual pin testing
│   └── pin_test.m                      # MATLAB script to drive pin test
└── docs/
    └── Notes on stimulation matlab and stim arduino.docx
```

### File Descriptions

#### Arduino

##### `StimArd_12_EEG_Trigger.ino`
Arduino firmware. Listens for 24-byte serial packets from MATLAB, decodes stimulation parameters, pulses EEG trigger pins, and drives the stimulator with precise square-wave pulses using a busy-wait timing loop (`busyDelayMicroseconds`) for microsecond-level accuracy.

#### Stimulation

##### `Stimulation_EEG_experiment.m`
Main MATLAB experiment controller for electrical/thermal stimulation. Establishes serial connection to Arduino, randomizes trial order, loops through 120 trials sending stimulation commands, collects subject ratings after each trial, and saves results to a `.mat` file.

##### `playStereoTones_ASSR.m`
Generates and plays stereo auditory steady-state response (ASSR) stimuli. Produces amplitude-modulated tones where each ear receives a carrier tone modulated at different frequencies — the left ear at the ASSR frequency (default 40 Hz) and the right ear at an offset frequency (default ASSR + 5 Hz). This enables frequency-tagging analysis in the recorded EEG to identify neural responses locked to each ear's modulation rate.

```matlab
[y, fs] = playStereoTones_ASSR(f_carry, f_assr, f_env, dur, fs, m, ramp_ms, level_dBFS, doPlay)
% f_carry    - Carrier frequency in Hz [2000]
% f_assr     - Left-ear modulation (ASSR) frequency in Hz [40]
% f_env      - Right-ear offset modulation in Hz [5]
% dur        - Duration in seconds [5]
% fs         - Sample rate in Hz [48000]
% m          - Modulation depth 0..1 (1 = full on/off) [1]
% ramp_ms    - Raised-cosine onset/offset ramp in ms [1]
% level_dBFS - Output level relative to full-scale in dB [-6]
% doPlay     - Play sound via sound(y,fs) [true]
```

Example:
```matlab
playStereoTones_ASSR(1000, 40, 41, 60);  % 60 s, default settings
```

##### `playStereoTones.m`
Basic stereo tone generation utility. Supports two modes: `'tone'` generates pure sine tones at specified frequencies for each ear, and `'file'` plays two WAV files routed to left and right channels. Used for testing audio output and basic binaural stimulation.

```matlab
playStereoTones('tone', fL, fR, dur)
% mode - 'tone' or 'file'
% fL   - Left ear frequency in Hz [500]
% fR   - Right ear frequency in Hz [460]
% dur  - Duration in seconds [5]
```

#### Analysis

##### `bp_filter.m`
Wrapper function for a 5th-order zero-phase Butterworth bandpass filter using MATLAB's `butter` and `filtfilt`.

```matlab
filt_signal = bp_filter(signal, low_thresh, high_thresh, fs)
% signal     - 1D signal vector
% low_thresh - lower cutoff frequency (Hz)
% high_thresh- upper cutoff frequency (Hz)
% fs         - sampling rate (Hz)
```

##### `bpfEEG_prep.m`
Preprocessing script. Applies a 0.3–50 Hz bandpass filter to all channels of a loaded EEGLAB `EEG` structure, converts back to single precision, and saves the result as a `.set` file. Run this after loading raw EEG data into EEGLAB.

##### `do_fft.m`
FFT utility. Detrends a signal, computes the single-sided magnitude spectrum, and plots it. Useful for verifying filter effectiveness before/after preprocessing.

```matlab
[Y, f] = do_fft(signal, Fs)
% signal - 1D signal vector
% Fs     - sampling rate (Hz)
% Y      - FFT magnitude values
% f      - frequency axis (Hz)
```

#### Test

##### `PinTest/PinTest.ino`
Arduino test sketch. Receives a pin number over serial, sets it HIGH for 2 seconds, then LOW. Use with `pin_test.m` to verify wiring after resoldering.

##### `pin_test.m`
MATLAB script that drives the pin test. Cycles through all 6 pins (8, 9, 10, 11, 12, 13) one at a time, pausing after each for the user to note which LED lit up and what appeared on the EEG software.

---

## Stimulation Paradigms

### Electrical/Thermal Stimulation

The primary experiment delivers precisely timed electrical (TENS) or thermal sensory stimulation via an Arduino-controlled stimulator. MATLAB sends command packets over serial to the Arduino, which simultaneously drives the stimulator and pulses EEG trigger lines to embed event markers at the exact moment of stimulation onset. See [Running an Experiment](#running-an-experiment) for setup and execution.

### ASSR Auditory Stimulation

The ASSR paradigm uses amplitude-modulated tones to elicit auditory steady-state responses — periodic neural signals that can be detected in the EEG at the modulation frequency. This is used alongside the BrainSense in-ear EEG device as a comparison point to the 64-channel system.

- **Left ear:** Carrier tone modulated at the ASSR frequency (default 40 Hz)
- **Right ear:** Carrier tone modulated at ASSR + offset frequency (default 40 + 5 = 45 Hz)
- **Modulation:** Sinusoidal envelope, `env = (1-m) + m * 0.5*(1 + sin(2*pi*f_mod*t))`, where `m=1` produces full on/off modulation
- **Output:** Peak-normalized with dBFS level control and raised-cosine ramps to avoid spectral splatter

Run with:
```matlab
% 60-second stimulus, 1 kHz carrier, 40 Hz left / 45 Hz right modulation
[y, fs] = playStereoTones_ASSR(1000, 40, 5, 60);
```

---

## Running an Experiment

### Electrical/Thermal Stimulation

1. **Start Neuroscan SCAN 4.5** on the EEG PC and begin recording before proceeding.
2. Open MATLAB on the Experiment PC and set the correct serial port in `stimulation/Stimulation_EEG_experiment.m`:
   ```matlab
   stimulator = serialport('COM3', 9600);   % Windows
   % stimulator = serialport('/dev/cu.usbmodem14101', 9600);  % macOS
   ```
3. Set the save path if needed:
   ```matlab
   save_path = '../data/SensoryTesting/';
   ```
4. Run `stimulation/Stimulation_EEG_experiment.m`.
5. When prompted, enter the stimulation mode:
   - `0` — left channel only
   - `1` — right channel only
   - `2` — both channels
6. The experiment will count down 3 seconds and begin automatically.
7. After each trial, enter the subject's ratings at the MATLAB prompts:
   - **Sensation** (1 = innocuous → 7 = intense)
   - **Perception** (1 = natural → 7 = electrical)
8. Press Enter at rest prompts (every 20 trials).
9. After the final trial, select filename type (`1` = EEG_TENS, `2` = EEG_THERMAL). The `.mat` file is saved automatically with a timestamp.

### ASSR Auditory Stimulation

1. **Start EEG recording** on both the 64-channel system and BrainSense device.
2. Ensure audio output is properly configured and calibrated.
3. In MATLAB, run:
   ```matlab
   addpath('stimulation');
   playStereoTones_ASSR(1000, 40, 5, 60);  % Adjust parameters as needed
   ```
4. The function plays immediately by default. Set `doPlay=false` to generate the waveform without playback.

---

## Experiment Protocol Details

| Parameter | Value |
|-----------|-------|
| Pulse widths | 5 ms, 10 ms |
| Frequencies | 2 Hz, 20 Hz, 45 Hz |
| Conditions | 6 (2 PW × 3 freq) |
| Repetitions per condition | 20 |
| Total trials | 120 (randomized) |
| Stimulation duration | 2 seconds |
| Inter-trial delay | 4 seconds (fixed) + ±1 s jitter |
| Stimulation amplitude | 1.2 (saved as metadata) |

### Saved Output (`.mat`)

The saved `Result` struct contains:

| Field | Description |
|-------|-------------|
| `result.order` | Randomized trial index sequence |
| `result.freqO` | Frequency for each trial |
| `result.PWO` | Pulse width for each trial |
| `result.param` | Parameter pair lookup table |
| `result.triggerSeq` | Trigger code for each trial |
| `result.sens` | Subject sensation ratings (1–7) |
| `result.perc` | Subject perception ratings (1–7) |
| `Result.frequency` | Tested frequencies |
| `Result.pulsewidth` | Tested pulse widths |
| `Result.duration` | Stimulation duration (s) |
| `Result.amplitude` | Stimulation amplitude |
| `Result.trigger` | Full trigger sequence |

---

## EEG Trigger System

The three Arduino pins (8, 9, 10) form a 3-bit binary trigger code that is sent to the EEG amplifier's digital input port at the start of each stimulation. Neuroscan SCAN 4.5 reads this as an integer event marker and stamps it into the recording.

### Trigger Code Mapping

Each of the 6 parameter conditions (2 pulse widths × 3 frequencies) is assigned a unique trigger code 1–6:

| Trigger Code | Pins HIGH | Typical Use |
|:---:|:---:|---|
| 1 | 8 | Condition 1 |
| 2 | 9 | Condition 2 |
| 3 | 10 | Condition 3 |
| 4 | 8, 9 | Condition 4 |
| 5 | 8, 10 | Condition 5 |
| 6 | 9, 10 | Condition 6 |

These markers appear in SCAN 4.5 as timestamped event markers in the continuous EEG trace. During offline analysis, they are used to epoch the EEG data (e.g. extract −200 ms to +1000 ms windows around each trigger) and to link trials back to the behavioral ratings saved in the `.mat` file.

---

## Serial Communication Protocol

MATLAB sends a 24-byte packet of 6 single-precision floats (4 bytes each) before each trial:

| Bytes | Parameter | Type | Description |
|-------|-----------|------|-------------|
| 0–3 | Stim flag | float | `1.0` = start stimulation, `0.0` = stop |
| 4–7 | Period | float | Pulse period in ms (= 1000 / frequency) |
| 8–11 | Duration | float | Total stimulation time in ms |
| 12–15 | Pulse width | float | Width of each pulse in ms |
| 16–19 | Stim mode | float | `0` = left, `1` = right, `2` = both |
| 20–23 | Trigger mode | float | Trigger code 1–6 |

Sent from MATLAB as:
```matlab
write(stimulator, out, 'single');
```

---

## Post-Processing

### Recording Notes

- There is no way to exclude channels during recording in SCAN 4.5. All channels are recorded; unwanted channels must be removed during post-processing.
- To delete bad channels: load the `.cnt` file, then use **Edit > Transforms > Delete bad channels**, then re-export.

### Workflow

#### 0. Import Neuroscan Data into EEGLAB
```matlab
eeglab;  % start EEGLAB
% File > Import data > Using EEGLAB functions and plugins > From Neuroscan .cnt file
EEG = pop_loadcnt('path/to/recording.cnt');
```

#### 1. Bandpass Filter
Run `analysis/bpfEEG_prep.m` with an `EEG` structure loaded in the workspace:
```matlab
addpath('analysis');
run('analysis/bpfEEG_prep.m')
% Applies 0.3–50 Hz filter to all channels and saves as .set
```

#### 2. Verify Filter (optional)
```matlab
do_fft(EEG.data(1, :), EEG.srate);   % before filtering
do_fft(fData(1, :), EEG.srate);       % after filtering
```

#### 3. Epoch & Analyze
Use EEGLAB's epoch extraction tools with the trigger codes (1–6) to segment the filtered EEG around stimulation onsets. Match epochs to behavioral ratings using `Result.trigger` and `Result.result` from the saved `.mat` file.

---

## Testing & Debugging

### Pin Test

Use the pin test to verify wiring after resoldering or reconnecting the Arduino-to-amplifier connector.

1. Upload `test/PinTest/PinTest.ino` to the Arduino via the Arduino IDE.
2. Run `test/pin_test.m` in MATLAB.
3. The script activates each pin (8, 9, 10, 11, 12, 13) one at a time for 2 seconds.
4. For each pin, note:
   - Which LED lights up on the breadboard
   - Whether a trigger event appears in SCAN 4.5
5. **Re-upload the main firmware** (`arduino/StimArd_12_EEG_Trigger/StimArd_12_EEG_Trigger.ino`) when done testing.

### LED Indicator Reference

| LED Color | Arduino Pin | Expected Behavior |
|-----------|-------------|-------------------|
| Blue | 8 | Lights when trigger bit 0 is active |
| Green | 9 | Lights when trigger bit 1 is active |
| Yellow | 10 | Lights when trigger bit 2 is active |
| Red | 11 | <!-- TODO: confirm function --> Blinks when experiment code runs (cause TBD) |

<!-- TODO: Document expected default LED state (all lit except blue when properly connected) -->

### Troubleshooting

- **No LEDs light up:** Check breadboard-to-Arduino contact (known to cause issues — see Tuesday incident).
- **Wrong LED lights up:** Wiring was likely swapped during resoldering. Run the pin test to identify the mapping and either rewire or update the firmware pin assignments.
- **LEDs work but no EEG trigger in SCAN 4.5:** Check the connector between the breadboard and the amplifier. Verify common ground is connected.

---

## Known Issues

- **Hardcoded serial port**: The COM port in `stimulation/Stimulation_EEG_experiment.m` (line 6) is set to `COM3`. Update this to match your system before running.
- **No EEG software integration**: The MATLAB script does not start, stop, or communicate with SCAN 4.5. The researcher must manually start recording before running the script.
- **Trigger pulse duration**: The trigger pins are set HIGH and then immediately reset to LOW in the same `loop()` iteration. Depending on loop execution time, the pulse width may be very short (~microseconds). Verify your EEG amplifier can reliably detect pulses of this duration.
- **Pin 11 undocumented**: The red LED on pin 11 is wired to the amplifier connector (DB-25 pin 12) but the firmware does not drive it. Its function is unknown — it blinks when the experiment code runs, possibly due to electrical coupling on the breadboard.
- **Relative timestamps**: The EEG PC may lack internet access, so SCAN 4.5 records relative time only. Use Arduino trigger markers (not wall-clock time) to align data.
