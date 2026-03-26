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
- [Known Issues](#known-issues)

---

## System Overview

```
MATLAB Script
  |
  | Serial (9600 baud, binary float packets)
  |
Arduino Uno
  |-- Pins 12, 13 ──► Electrical stimulator(s) (left / right / both)
  |-- Pins 8, 9, 10 ──► EEG amplifier trigger input port
                              |
                         EEG Software
                    (BrainVision, ActiView, etc.)
                    records EEG + event markers
```

MATLAB sends a 6-parameter command packet before each trial. The Arduino simultaneously starts the stimulator and pulses the EEG trigger lines, embedding an event marker at the precise moment stimulation begins.

---

## Hardware Requirements

- **Arduino Uno** (or compatible)
- **Electrical stimulator** with TTL/digital input control (left and/or right channels)
- **EEG amplifier** with a digital trigger input port (DB-25 or equivalent), e.g.:
  - Brain Products BrainAmp
  - BioSemi ActiveTwo
  - g.tec g.USBamp
- Wiring: jumper wires from Arduino digital pins to stimulator and EEG trigger port
- USB cable (Arduino ↔ PC running MATLAB)

---

## Software Requirements

- **MATLAB** (R2019b or later recommended) with:
  - Signal Processing Toolbox (for `butter`, `filtfilt`)
  - Instrument Control Toolbox (for `serialport`)
  - [EEGLAB](https://sccn.ucsd.edu/eeglab/) (for `pop_saveset` used in preprocessing)
- **Arduino IDE** (for uploading firmware to the Arduino)
- Your EEG recording software of choice (run separately, manually)

---

## Hardware Setup & Wiring

### Stimulator Pins

| Arduino Pin | Function |
|-------------|----------|
| 12 | Left stimulator channel |
| 13 | Right stimulator channel |

Connect these to the TTL/digital trigger input of your stimulator device.

### EEG Trigger Pins

| Arduino Pin | Trigger Bit |
|-------------|-------------|
| 8 | Bit 0 (value 1) |
| 9 | Bit 1 (value 2) |
| 10 | Bit 2 (value 4) |

Connect pins 8, 9, 10 to bits 0, 1, 2 of your EEG amplifier's digital trigger input port. The amplifier will read the combined binary value as a trigger code (1–6) and embed it as a timestamped event marker in the EEG recording.

> **Important:** Ensure a common ground connection between the Arduino and the EEG amplifier trigger port.

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
└── docs/
    └── Notes on stimulation matlab and stim arduino.docx
```

### File Descriptions

#### Arduino

##### `StimArd_12_EEG_Trigger.ino`
Arduino firmware. Listens for 25-byte serial packets from MATLAB, decodes stimulation parameters, pulses EEG trigger pins, and drives the stimulator with precise square-wave pulses using a busy-wait timing loop (`busyDelayMicroseconds`) for microsecond-level accuracy.

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

1. **Start EEG recording software** manually and begin recording before proceeding.
2. Open MATLAB and set the correct serial port in `stimulation/Stimulation_EEG_experiment.m`:
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

The three Arduino pins (8, 9, 10) form a 3-bit binary trigger code that is sent to the EEG amplifier's digital input port at the start of each stimulation. The EEG software reads this as an integer event marker and stamps it into the recording.

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

These markers appear in EEG recording software as vertical event lines on the continuous EEG trace, labeled with the trigger value. During offline analysis, they are used to epoch the EEG data (e.g. extract −200 ms to +1000 ms windows around each trigger) and to link trials back to the behavioral ratings saved in the `.mat` file.

---

## Serial Communication Protocol

MATLAB sends a 25-byte packet of 6 single-precision floats (4 bytes each) before each trial:

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

After the experiment, load the exported EEG file into EEGLAB, then:

### 1. Bandpass Filter
Run `analysis/bpfEEG_prep.m` with an `EEG` structure loaded in the workspace:
```matlab
% In MATLAB, after loading data with EEGLAB:
addpath('analysis');
run('analysis/bpfEEG_prep.m')
% Applies 0.3–50 Hz filter to all channels and saves as .set
```

### 2. Verify Filter (optional)
```matlab
do_fft(EEG.data(1, :), EEG.srate);   % before filtering
do_fft(fData(1, :), EEG.srate);       % after filtering
```

### 3. Epoch & Analyze
Use EEGLAB's epoch extraction tools with the trigger codes (1–6) to segment the filtered EEG around stimulation onsets. Match epochs to behavioral ratings using `Result.trigger` and `Result.result` from the saved `.mat` file.

---

## Known Issues

- **Trigger code 7 bug** (`arduino/StimArd_12_EEG_Trigger/StimArd_12_EEG_Trigger.ino`, line 69): `case 7` attempts to set `triggerPins[3]` HIGH, but only indices 0–2 exist. This will cause undefined behavior. Trigger code 7 is generated in the MATLAB script but should be avoided until this is fixed.
- **Hardcoded serial port**: The COM port in `stimulation/Stimulation_EEG_experiment.m` (line 6) is set to `COM3`. Update this to match your system before running.
- **No EEG software integration**: The MATLAB script does not start, stop, or communicate with EEG recording software. The researcher must manually start recording before running the script.
- **Trigger pulse duration**: The trigger pins are set HIGH and then immediately reset to LOW in the same `loop()` iteration. Depending on loop execution time, the pulse width may be very short (~microseconds). Verify your EEG amplifier can reliably detect pulses of this duration.
