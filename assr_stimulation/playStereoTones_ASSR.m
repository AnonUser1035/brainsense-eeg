
function [y, fs] = playStereoTones_ASSR(f_carry, f_assr, f_env, dur, fs, m, ramp_ms, level_dBFS, doPlay, window_style)
%% playStereoTones_ASSR  Generate and (optionally) play stereo ASSR stimuli.
%   Author: Alessandro Ascani Orsini
%   Version: 1.1
%
% Inputs (defaults in brackets):
%   f_carry      - Carrier frequency in Hz, same for both ears [2000]
%   f_assr       - Left-ear modulation (ASSR) frequency in Hz [40]
%   f_env        - Right-ear offset modulation in Hz [5]
%   dur          - Duration in seconds [5]
%   fs           - Sample rate in Hz [48000]
%   m            - Modulation depth from 0..1 (1 = full on/off) [1]
%   ramp_ms      - Onset/offset ramp duration in ms; used only when
%                  window_style='ramp' [1]
%   level_dBFS   - Overall output level relative to full-scale in dB [-6]
%   doPlay       - If true, play sound via sound(y,fs) [true]
%   window_style - 'ramp' (default): short raised-cosine onset/offset ramp
%                  'fade': long 1/3-steady-1/3 fade for sleep stimulation
%
% Outputs:
%   y  - Nx2 stereo waveform, column 1 = left, column 2 = right
%   fs - Sample rate
%
% Notes:
% - Left ear is amplitude-modulated at f_assr; right ear at f_assr+f_env.
% - The modulation is sinusoidal and scaled to produce "on/off"-like pulses:
%       env = (1-m) + m * 0.5*(1 + sin(2*pi*f_mod*t))
%   so m=1 goes from 0 to 1; m=0 yields constant tone.
% - Hard-clip protection and dBFS level control included.
%
% Examples:
%   % Waking ASSR task (short ramp, default):
%   playStereoTones_ASSR(1000, 40, 41, 60);
%
%   % Sleep stimulation (long fade):
%   playStereoTones_ASSR(1000, 40, 8, 300, 48000, 0.5, 5, -12, true, 'fade');
%
if nargin < 1  || isempty(f_carry),      f_carry      = 2000;   end
if nargin < 2  || isempty(f_assr),       f_assr       = 40;     end
if nargin < 3  || isempty(f_env),        f_env        = 5;      end
if nargin < 4  || isempty(dur),          dur          = 5;      end
if nargin < 5  || isempty(fs),           fs           = 48000;  end
if nargin < 6  || isempty(m),            m            = 1;      end
if nargin < 7  || isempty(ramp_ms),      ramp_ms      = 1;      end
if nargin < 8  || isempty(level_dBFS),   level_dBFS   = -6;     end
if nargin < 9  || isempty(doPlay),       doPlay       = true;   end
if nargin < 10 || isempty(window_style), window_style = 'ramp'; end

% Time vector
N = round(dur*fs);
t = (0:N-1)/fs;

% Carrier
carrier = sin(2*pi*f_carry*t);

% Sinusoidal amplitude envelopes (scaled 0..1 with depth m)
envL = (1-m) + m*0.5*(1 + sin(2*pi*f_assr*t));           % Left ear
envR = (1-m) + m*0.5*(1 + sin(2*pi*(f_assr+f_env)*t));   % Right ear

% Modulated signals
left  = envL .* carrier;
right = envR .* carrier;

% Window
switch lower(window_style)
    case 'ramp'
        % Short raised-cosine onset/offset ramp
        rampN = max(1, round(ramp_ms/1000*fs));
        ramp  = 0.5*(1 - cos(pi*(0:rampN-1)/rampN));
        win   = ones(1, N);
        win(1:rampN)         = win(1:rampN) .* ramp;
        win(end-rampN+1:end) = win(end-rampN+1:end) .* fliplr(ramp);
    case 'fade'
        % Long 1/3 fade-in / 1/3 steady / 1/3 fade-out (for sleep)
        fadeN   = floor(N/3);
        steadyN = N - 2*fadeN;
        fadeIn  = 0.5*(1 - cos(pi*(0:fadeN-1)/fadeN));
        win     = [fadeIn, ones(1,steadyN), fliplr(fadeIn)];
        win     = win(1:N);
    otherwise
        error('window_style must be ''ramp'' or ''fade''.');
end

left  = left  .* win;
right = right .* win;

% Normalize to dBFS target and protect from clipping
y = [left(:), right(:)];
peak = max(1e-12, max(abs(y),[],'all'));
y = y / peak;
scale = 10^(level_dBFS/20);
y = y * scale;
y = max(min(y, 0.999), -0.999);

% Play
if doPlay
    sound(y, fs);
end
end
