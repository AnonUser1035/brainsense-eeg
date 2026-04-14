%% run_ASSR_BinauralBeatTask_auto.m
% Fully automatic ASSR + binaural beat task.
% 
% Requires:
%   - playStereoTones.m
%   - playStereoTones_ASSR.m
%
% Output:
%   - ASSR_BB_taskLog.csv : onset times (laptop clock, ms) for each trial.

clear; clc;

%% ----------------- General parameters -----------------
fs          = 48000;    % Sample rate [Hz]
f_carry     = 2000;     % Carrier freq for ASSR [Hz]
f_assr      = 40;       % Left-ear ASSR modulation frequency [Hz]
beatFreq    = 7;        % Desired binaural-beat / diff frequency [Hz]
m           = 1.0;      % Modulation depth (1 = full)
ramp_ms     = 10;       % On/off ramp [ms]

% Durations
dur_HEADCHK = 5;        % Headphone check [s]
dur_ASSR    = 20;       % ASSR baseline trial [s]
dur_BB      = 30;       % Binaural-beat ASSR trial [s]

% Digital levels (be careful with physical SPL!)
level_ASSR_dBFS = -6;   % Baseline ASSR level
level_BB_dBFS   = 0;    % Near max digital level (control volume on amp/DAC)

% Repetitions
nTrials_ASSR = 5;
nTrials_BB   = 10;

% Inter-trial interval
ITI = 3;  % seconds (silence)

%% ----------------- Logging structure -----------------
logIdx = 0;
taskLog = struct('block',{},'trial',{},'type',{}, ...
                 'onsetDateTime',{},'onsetPOSIX',{}, ...
                 'duration_s',{},'f_assr',{},'beatFreq',{}, ...
                 'note',{});

fprintf('================ ASSR + Binaural Beat Task ================\n');
fprintf('Script start time (local): %s\n', ...
    char(datetime('now','TimeZone','local','Format','yyyy-MM-dd HH:mm:ss.SSS')));
fprintf('No user input required. Make sure EEG is already recording.\n');
fprintf('===========================================================\n\n');

%% ----------------- Short initial delay -----------------
% Small delay so you can hit "Run" and then settle.
initial_delay = 5; % seconds
fprintf('Initial delay: %.1f s\n', initial_delay);
pause(initial_delay);

%% ----------------- Headphone / stereo sanity check -----------------
fprintf('\n[HEADPHONE CHECK] Playing stereo test tones for %.1f s...\n', dur_HEADCHK);
fprintf('This is just for you to confirm L/R separation; no markers are logged.\n');

% Uses your playStereoTones(mode,fL,fR,dur) with defaults
playStereoTones('tone', [], [], dur_HEADCHK);

pause(2);  % Small gap before main blocks

%% ----------------- BLOCK 1: ASSR baseline -----------------
fprintf('\n[BLOCK 1] ASSR baseline\n');
fprintf('  Carrier: %.0f Hz, modulation: %.1f Hz (both ears)\n', f_carry, f_assr);
fprintf('  Trials: %d, duration each: %.1f s, ITI: %.1f s\n\n', ...
    nTrials_ASSR, dur_ASSR, ITI);

for tr = 1:nTrials_ASSR
    % Log onset *before* calling the audio function
    tNow = datetime('now','TimeZone','local');
    tStr = char(datetime(tNow,'Format','yyyy-MM-dd HH:mm:ss.SSS'));
    
    fprintf('[%s] BLOCK=ASSR_BASELINE, TRIAL=%d START\n', tStr, tr);
    
    logIdx = logIdx + 1;
    taskLog(logIdx).block         = 'ASSR_BASELINE';
    taskLog(logIdx).trial         = tr;
    taskLog(logIdx).type          = 'ASSR';
    taskLog(logIdx).onsetDateTime = tNow;
    taskLog(logIdx).onsetPOSIX    = posixtime(tNow);
    taskLog(logIdx).duration_s    = dur_ASSR;
    taskLog(logIdx).f_assr        = f_assr;
    taskLog(logIdx).beatFreq      = 0;          % no binaural beat here
    taskLog(logIdx).note          = 'ASSR same modulation both ears';
    
    % f_env = 0 => same modulation in both ears
    f_env = 0;
    playStereoTones_ASSR( ...
        f_carry, ...        % carrier
        f_assr, ...         % left modulation
        f_env, ...          % right offset (0 = same)
        dur_ASSR, ...       % duration
        fs, ...             % sample rate
        m, ...              % modulation depth
        ramp_ms, ...        % ramp
        level_ASSR_dBFS, ...% level
        true ...            % play
    );
    
    fprintf('  TRIAL %d finished. ITI = %.1f s\n', tr, ITI);
    pause(ITI);
end

%% ----------------- BLOCK 2: ASSR-encoded binaural beat -----------------
fprintf('\n[BLOCK 2] ASSR-encoded binaural beat\n');
fprintf('  Left modulation:  %.1f Hz\n', f_assr);
fprintf('  Right modulation: %.1f Hz\n', f_assr + beatFreq);
fprintf('  Expected EEG beat (difference): %.1f Hz\n', beatFreq);
fprintf('  Trials: %d, duration each: %.1f s, ITI: %.1f s\n\n', ...
    nTrials_BB, dur_BB, ITI);

for tr = 1:nTrials_BB
    tNow = datetime('now','TimeZone','local');
    tStr = char(datetime(tNow,'Format','yyyy-MM-dd HH:mm:ss.SSS'));
    
    fprintf('[%s] BLOCK=BINAURAL_ASSR, TRIAL=%d START\n', tStr, tr);
    
    logIdx = logIdx + 1;
    taskLog(logIdx).block         = 'BINAURAL_ASSR';
    taskLog(logIdx).trial         = tr;
    taskLog(logIdx).type          = 'ASSR_BINAURAL';
    taskLog(logIdx).onsetDateTime = tNow;
    taskLog(logIdx).onsetPOSIX    = posixtime(tNow);
    taskLog(logIdx).duration_s    = dur_BB;
    taskLog(logIdx).f_assr        = f_assr;
    taskLog(logIdx).beatFreq      = beatFreq;
    taskLog(logIdx).note          = 'ASSR binaural beat (L vs R modulation offset)';
    
    % f_env is the offset between left and right modulation:
    %   Left:  f_assr
    %   Right: f_assr + f_env
    f_env = beatFreq;
    playStereoTones_ASSR( ...
        f_carry, ...        % carrier
        f_assr, ...         % left modulation
        f_env, ...          % right modulation offset
        dur_BB, ...         % duration
        fs, ...             % sample rate
        m, ...              % modulation depth
        ramp_ms, ...        % ramp
        level_BB_dBFS, ...  % higher level
        true ...            % play
    );
    
    fprintf('  TRIAL %d finished. ITI = %.1f s\n', tr, ITI);
    pause(ITI);
end

%% ----------------- Save log -----------------
taskTable = struct2table(taskLog);

logFileName = sprintf('ASSR_BB_taskLog_%s.csv', ...
    char(datetime('now','TimeZone','local','Format','yyyyMMdd_HHmmss')));
writetable(taskTable, logFileName);

fprintf('\n================ TASK COMPLETE ================\n');
fprintf('Log saved to: %s\n', logFileName);
fprintf('Columns:\n');
disp(taskTable.Properties.VariableNames');
fprintf('===============================================\n');