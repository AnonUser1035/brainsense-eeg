clc; clear all;
%% Establish Serial Communication with Arduino

if exist('stimulator', 'var') == 0
%     stimulator = serialport('/dev/cu.usbmodem14101', 9600);
    stimulator = serialport('COM3', 9600); 
    flush(stimulator);
    status = getpinstatus(stimulator);
    configureTerminator(stimulator, "LF");
end

if exist('stimulator', 'var') == 1
    fprintf('Arduino Uno stimulator connected on %s \n', stimulator.Port);
else
    error('Error: Arduino stimulator not connected \n');
end

save_path = '../data/SensoryTesting/';

%% EEG set up stim parameters and trigger markers
% trigger types: 1, 2, 3, 4, 5, 6, 7

% either 2 different PW and 3 different freq or 2 PW and 3 freq
PW = [5, 10];
freq = [2, 20, 45]; 
R = 20;
N = length( PW ) * length( freq );

% loop through each frequency and each PW R times
freq_order = sort( repmat( freq, 1, R * length( PW ) ) );
PW_order = repmat( PW, 1, R * length( freq ) );
a = randperm( R * N );    %create a vector with repitions*num freq*num pulses numbers in random order

result.order = a;   %save order of stim presentations in case needed for future analysis
result.freqO = freq_order;
result.PWO = PW_order;
result.PW = PW;
result.freq = freq;

% determine trigger type from order
param_pairs = nan( 3, N );
param_pairs(1, :) = sort( repmat(PW, [1 length(freq)]));
param_pairs(2, :) = repmat( freq, [1 length(PW)] );
param_pairs(3, :) = [ 1 : N ];

% trigger sequence
sequence = vertcat( PW_order, freq_order );
trigger_sequence = nan( 1, N*R );
for i = 1:length( a )
    [~, trigger_sequence(i)] = find( param_pairs( 1,: ) == sequence( 1,a(i) ) & param_pairs( 2,: ) == sequence( 2,a(i) ));
end

result.param = param_pairs;
result.triggerSeq = trigger_sequence;

sens = nan( 1, N*R );
perc = nan( 1, N*R );

%% EEG experiment

% Create Visual fixpoint
% figure('WindowState', 'fullscreen', ...
%        'MenuBar', 'none', ...
%        'ToolBar', 'none');
% ax = axes('Units','Normalize','Position',[0 0 1 1]);
% xlim([-1, 1]);
% ylim([-1, 1]);
% set(gca,'Color','k');
% set(gca,'TickLength',[0 0])
% hold on;
% plot([-0.03, 0.03], [0.5, 0.5], 'w', 'LineWidth', 5);
% plot([0, 0], [0.45, 0.55], 'w', 'LineWidth', 5);
% hold off;

jitter_max = 1;
jitter_min = -1;

stim_mode = input('Enter stim_mode (0-left, 1-right, 2-both): ');
delay = 4;
duration = 2;
out(3) = duration * 1000.0;
out(5) = stim_mode;


fprintf('Experiment starting in %d...', 3);
pause(1);
fprintf('%d...', 2);
pause(1);
fprintf('%d\r\n', 1);
pause(1);

for i = 1:length( a )
    fprintf('%d of %d| trigger %d \n', i, length(a), trigger_sequence( i ));
    out(1) = 1;
    if PW_order( a(i) ) == 0
        out(1) = 0;
    end
    
    out(2) = 1000 / freq_order( a(i) );
    out(4) = PW_order( a(i) );
    out(6) = trigger_sequence( i ); % trigger type
    
    write(stimulator, out, 'single');
    jitter = (jitter_max - jitter_min) * rand() + jitter_min;   %add some jitter to the delay between stimulation presentations
    pause(duration + delay + jitter);
    
    % rate sensation and perception
    sens(i) = input('Rate (1 - innocuous, 7 - intense): ');
    perc(i) = input('Rate (1 - natural, 7 - electrical): ');
    
    if mod(i, 20) == 0
		% rest every 20 repetitions to avoid fatigue
		input('Please hit enter to continue: ');
    end
end
% 
result.sens = sens;
result.perc = perc;

disp('REMEMBER TO SAVE DATA! ')

%% Save
close all

Result.result = result;
Result.frequency = freq;
Result.pulsewidth = PW;
Result.duration = duration;
Result.amplitude = 1.2;
Result.trigger = trigger_sequence;

x = input('file name selection [1 - EEG_TENS, 2 - EEG_THERMAL]: ');
if x == 1
    fname = 'EEG_TENS';
elseif x == 2
    fname = 'EEG_THERMAL';
end

filename = strrep( datestr(datetime('now')),':','_' );    %get date and time, replace ':' with '_' so you can save
filename = strcat( save_path, fname, filename,'.mat' );


save(filename, 'Result' );


