
function [y, fs] = playStereoTones_ASSR(f_carry, f_assr, f_env, dur, fs, m, ramp_ms, level_dBFS, doPlay)
%% playStereoTones_ASSR  Generate and (optionally) play stereo ASSR stimuli.
%   Author: Alessandro Ascani Orsini
%   Version: 1.0
%
% Inputs (defaults in brackets):
%   f_carry     - Carrier frequency in Hz, same for both ears [1000]
%   f_assr      - Left-ear modulation (ASSR) frequency in Hz [40]
%   f_env       - Right-ear offset modulation in Hz [10]
%   dur         - Duration in seconds [10]
%   fs          - Sample rate in Hz [48000]
%   m           - Modulation depth from 0..1 (1 = full on/off) [1]
%   ramp_ms     - Raised-cosine onset/offset ramp in ms [5]
%   level_dBFS  - Overall output level relative to full-scale in dB [-6]
%   doPlay      - If true, play sound via sound(y,fs) [true]
%
% Outputs:
%   y  - Nx2 stereo waveform, column 1 = left, column 2 = right
%   fs - Sample rate
%
% Notes:
% - Left ear is amplitude-modulated at f_assr; right ear at f_env.
% - The modulation is sinusoidal and scaled to produce "on/off"-like pulses:
%       env = (1-m) + m * 0.5*(1 + sin(2*pi*f_mod*t))
%   so m=1 goes from 0 to 1; m=0 yields constant tone.
% - Hard-clip protection and dBFS level control included.
%
% Example:
%   playStereoTones_ASSR(1000, 40, 41, 60);  % 60 s, -6 dBFS, ramps
%
%   % Different parameters:
%   playStereoTones_ASSR(800, 37, 39, 20, 48000, 1, 10, -10, true);
%
if nargin < 1 || isempty(f_carry),   f_carry   = 2000; end
if nargin < 2 || isempty(f_assr),    f_assr    = 40;   end
if nargin < 3 || isempty(f_env),     f_env     = 5;   end
if nargin < 4 || isempty(dur),       dur       = 5;   end
if nargin < 5 || isempty(fs),        fs        = 48000;end
if nargin < 6 || isempty(m),         m         = 1;    end
if nargin < 7 || isempty(ramp_ms),   ramp_ms   = 1;    end
if nargin < 8 || isempty(level_dBFS),level_dBFS= -6;   end
if nargin < 9 || isempty(doPlay),    doPlay    = true; end

% Time vector
N = round(dur*fs);
t = (0:N-1)/fs;

% Carrier
carrier = sin(2*pi*f_carry*t);

% Sinusoidal amplitude envelopes (scaled 0..1 with depth m)
envL = (1-m) + m*0.5*(1 + sin(2*pi*f_assr*t)); % Left ear
envR = (1-m) + m*0.5*(1 + sin(2*pi*(f_assr+f_env) *t)); % Right ear

% Modulated signals
left  = envL .* carrier;
right = envR .* carrier;

% Raised-cosine onset/offset ramp
rampN = max(1, round(ramp_ms/1000*fs));
ramp  = 0.5*(1 - cos(pi*(0:rampN-1)/rampN));     % 0->1
win   = ones(1,N);
win(1:rampN)             = win(1:rampN) .* ramp;
win(end-rampN+1:end)     = win(end-rampN+1:end) .* fliplr(ramp);
left  = left  .* win;
right = right .* win;

% Normalize to dBFS target and protect from clipping
y = [left(:), right(:)];
peak = max(1e-12, max(abs(y),[],'all'));
y = y / peak; % peak-normalize to 1
scale = 10^(level_dBFS/20);
y = y * scale;
y = max(min(y, 0.999), -0.999); % safety clip

% Play
if doPlay
    sound(y, fs);
end
end
