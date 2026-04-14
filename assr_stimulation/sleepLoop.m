%% On-ear-OS sleep-loop
clc
clear all
close all

codeStartDT = datetime('now','TimeZone','local');

% select path where recording is being created
repoRoot   = "/Users/alessandroascaniorsini/Documents/GitHub/Github_DataView-v3";
dataFolder = fullfile(repoRoot, "data-raw");
streamFolder = fullfile(repoRoot, "stream");  % contains PacketManager.py

% filter
bOrder = 1;
lowCutoff = .5; 
highCutoff = 400; 
winLen = 180; 
winRefresh = 300;
debugOn = true;

bands = struct( ...
    'delta', [0.5 4], ...
    'theta', [4 8], ...
    'alpha', [8 13], ...
    'beta',  [13 30], ...
    'gamma', [30 45] );
bandNames = fieldnames(bands);

% Find newest .bin file in data-raw
files = dir(fullfile(dataFolder, "*.bin"));
assert(~isempty(files), "No .bin files found in data-raw. Press Record in DataView first.");
dt = NaT(1,length(files));
for i = 1:length(files)
    dt(i) = datetime(files(i).date, 'InputFormat','dd-MMM-yyyy HH:mm:ss','Locale','en_US');
end
[~, idx] = max(dt);
blockPath = fullfile(files(idx).folder, files(idx).name);
fprintf("Tailing: %s\n", blockPath);

%% Extract file information (NeuroPulse)
[~, fname, ~] = fileparts(blockPath); % '2025.05.17.09.35.05_AAO-18'
parts = split(fname,'_');
ts_str = parts{1};
startTime = datetime(ts_str, 'InputFormat','yyyy.MM.dd.HH.mm.ss');

% --- CSV setup (same name as .bin) ---
csvPath = fullfile(files(idx).folder, fname + ".csv");

% Create header if file doesn't exist
if ~isfile(csvPath)
    header = table( ...
        codeStartDT, NaT, ...                        % codeStartDT, analysisStartDT
        NaN, NaN, NaN, ...                           % Ai, HR, R_AB
        NaN, NaN, NaN, NaN, NaN, ...                 % delta, theta, alpha, beta, gamma
        NaN, NaN, NaN, NaN, false, ...               % stim_offsetHz, stim_mDepth, stim_leveldBFS, stim_dur_s, stim_played
        'VariableNames', { ...
            'codeStartDT','analysisStartDT', ...
            'Ai','HR_bpm','R_AB', ...
            'P_delta','P_theta','P_alpha','P_beta','P_gamma', ...
            'stim_offsetHz','stim_mDepth','stim_leveldBFS','stim_dur_s','stim_played' ...
        } ...
    );
    writetable(header, csvPath); % writes header + one dummy row
    % remove dummy row by rewriting empty table with just headers
    writetable(header([],:), csvPath);
end

b2V = @(rawChaB) (rawChaB-2^11)*1.8./(2^12*1000);

HR_k = [];
R_ABk = [];
Ai = 0;
t = [];

selCh = 1; % <-- choose which channel to log to CSV (change if you want)

while true
    analysisStartDT = datetime('now','TimeZone','local');

    earData = fn_BionodeBinOpen(blockPath,12);
    fsBionode = earData.channelSampleRate;
    timeAxis = earData.time;

    winTime = max([1,(length(earData.time)-winLen*fsBionode)]):length(earData.time)-10;

    [bB, aB] = butter(bOrder, [lowCutoff highCutoff] / (fsBionode / 2), 'bandpass');

    segN  = min(length(winTime), 2*fsBionode);   % ~2 s segments
    winW  = hann(segN);
    nover = floor(segN/2);

    % prealloc
    bp  = NaN(earData.numChannels, numel(bandNames));
    HR  = NaN(earData.numChannels,1);
    R_AB = NaN(earData.numChannels,1);

    PPfiltChaB = earData.channelsData;

    for ch = 1:earData.numChannels
        PPfiltChaB(ch,:) = filtfilt(bB, aB, b2V(earData.channelsData(ch, :)));

        if debugOn
            sgtitle(sprintf("Channel %d", ch))
            subplot(earData.numChannels,1,ch)
            plot(timeAxis(winTime),PPfiltChaB(ch,winTime))
            xlabel("s"); ylabel("V");
            xlim([min(timeAxis(winTime)),max(timeAxis(winTime))])
        end

        % --- Power (pwelch) ---
        [Pxx,f] = pwelch(PPfiltChaB(ch,winTime), winW, nover, segN, fsBionode);

        for k = 1:numel(bandNames)
            fr = bands.(bandNames{k});
            m = (f >= fr(1)) & (f < fr(2));
            if any(m)
                bp(ch,k) = trapz(f(m), Pxx(m));
            end
        end

        % --- HR (peak detection) ---
        [pks,locs] = findpeaks(-PPfiltChaB(ch,winTime), ...
            'MinPeakDistance', 0.6*fsBionode, ...
            'MaxPeakWidth', 0.04*fsBionode, ...
            'MinPeakHeight', 1.5e-4);

        if ~isempty(pks)
            HR(ch) = 60*length(pks)/min([winLen,earData.time(end)]);
        end

        % --- Arousal ratios ---
        % beta = 4th, alpha = 3rd based on your band order
        R_AB(ch) = log10(bp(ch,4)./bp(ch,3));
    end

    % ---- Pick channel for logging (selCh) ----
    P_delta = bp(selCh,1);
    P_theta = bp(selCh,2);
    P_alpha = bp(selCh,3);
    P_beta  = bp(selCh,4);
    P_gamma = bp(selCh,5);

    HR_sel  = HR(selCh);
    R_AB_sel = R_AB(selCh);

    % ---- Update Ai (FIXED: gate should be ~isempty(HR), not HR_k) ----
    if ~isnan(HR_sel) && HR_sel > 40 && HR_sel < 120 && ~isnan(R_AB_sel)
        HR_k(end+1)   = HR_sel;
        R_ABk(end+1)  = R_AB_sel;

        if numel(HR_k) > 6
            Ai = 0.5*(HR_k(end)-mean(HR_k))./std(HR_k) + ...
                 0.5*(R_ABk(end)-mean(R_ABk))./std(R_ABk);
        end
        t(end+1) = earData.time(end);
    end

    % ---- Auditory stim parameters (depend on Ai) ----
    stim_played = false;
    stim_dur_s  = winRefresh;
    stim_offsetHz   = NaN;
    stim_mDepth     = NaN;
    stim_leveldBFS  = NaN;

    if Ai > 0
        stim_offsetHz  = min(max(8 + 6*Ai, 4), 20);
        stim_mDepth    = min(max(0.3 + 0.35*Ai, 0.2), 1.0);
        stim_leveldBFS = min(max(-12 + 3*Ai,  -14),  -6);

        playStereoTones_sleep( ...
            1000, ...
            40,  ...
            stim_offsetHz, ...
            stim_dur_s, ...
            48000, ...
            stim_mDepth, ...
            5, ...
            stim_leveldBFS, ...
            true);

        stim_played = true;
    end

    % ---- Log to CSV (append one row per loop) ----
    row = table( ...
        codeStartDT, analysisStartDT, ...
        Ai, HR_sel, R_AB_sel, ...
        P_delta, P_theta, P_alpha, P_beta, P_gamma, ...
        stim_offsetHz, stim_mDepth, stim_leveldBFS, stim_dur_s, stim_played, ...
        'VariableNames', { ...
            'codeStartDT','analysisStartDT', ...
            'Ai','HR_bpm','R_AB', ...
            'P_delta','P_theta','P_alpha','P_beta','P_gamma', ...
            'stim_offsetHz','stim_mDepth','stim_leveldBFS','stim_dur_s','stim_played' ...
        } ...
    );

    writetable(row, csvPath, 'WriteMode','append');

    fprintf('%f\n', Ai);

    pause(winRefresh);
end