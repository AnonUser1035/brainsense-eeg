clc; clear all;


%% Summary

% This MATLAB script does 4 main jobs:
% Connects to the Arduino through serial
% Builds a randomized list of stimulation conditions
% Sends one trial at a time to the Arduino
% Collects your ratings and saves the results

%% Establish Serial Communication with Arduino


%creates variables stimulator and var
%creates if statement on if these variables exist

%stimulator variable connects to arduino port
%9600 = baud rate for bits per second
if exist('stimulator', 'var') == 0
    stimulator = serialport("/dev/cu.usbmodem1301", 9600);

%Because when serial communication starts, many Arduinos automatically reset.
%This pause gives the Arduino time to reboot and get ready.
    pause(2);


    flush(stimulator);  %flush clears old serial data from buffer so Buffer storage is renewed
    status = getpinstatus(stimulator); %checks current state of Arduino pin status


    configureTerminator(stimulator, "LF");
end

if exist('stimulator', 'var') == 1
    fprintf('Arduino Uno stimulator connected on %s \n', stimulator.Port);
else
    error('Error: Arduino stimulator not connected \n');
end

save_path = '../data/SensoryTesting/';  %results file

%% EEG set up stim parameters and trigger markers
% trigger types: 1, 2, 3, 4, 5, 6


% either 2 different PW and 3 different freq or 2 PW and 3 freq
PW = [5, 10];
freq = [2, 20, 45];
R = 20;
N = length( PW ) * length( freq ); %N = 6

%Each unique condition of PW, Frequency needs to repeat 20 times
%6 unique conditions means 120 trials

% loop through each frequency and each PW R times

% Create full trial lists for frequency and pulse width.
% repmat(...) repeats each parameter enough times so that every combination
% of PW and frequency occurs R times (total trials = R * length(PW) * length(freq)).
%
% freq_order: repeats each frequency for all PW conditions and repetitions,
% then sorts so identical frequencies are grouped together.
%
% PW_order: repeats pulse widths so they align with the frequency list,
% ensuring each PW is paired with every frequency the correct number of times.
%
% Together, these two vectors define the parameter values for all trials
% before randomization.

freq_order = sort( repmat( freq, 1, R * length( PW ) ) ); %freq repeated 40 times and sorted = 120
PW_order = repmat( PW, 1, R * length( freq ) );    %PW repeated 60 times and sorted = 120



a = randperm( R * N );    %create a vector of the 120 trials in random order for indexing

result.order = a;   %save order of stim presentations in structure 'result' needed for future analysis
result.freqO = freq_order;
result.PWO = PW_order;
result.PW = PW;
result.freq = freq;

% determine trigger type from order
param_pairs = nan( 3, N );  %param_pairs is a 3 x 6 matrix
param_pairs(1, :) = sort( repmat(PW, [1 length(freq)])); %1st row are the different PW for each frequency in order for the 120 trials
param_pairs(2, :) = repmat( freq, [1 length(PW)] );      %2nd row are the different frequencies for each PW
param_pairs(3, :) = [ 1 : N ];                           %3rd row are the 6 different trigger codes 1-6

% trigger sequence
sequence = vertcat( PW_order, freq_order );    %concatenate PW_order and freq_order
trigger_sequence = nan( 1, N*R );              %trigger sequence is a 1 x 120 matrix


%From the a variable with the randomized sorted 120 trials, we are now
%finding the associated pulse width and frequency for each randomized trial
%to be stored (sequence)

%we are then finding from this what is the trigger code
for i = 1:length( a )  %length(a) =120
    [~, trigger_sequence(i)] = find( param_pairs( 1,: ) == sequence( 1,a(i) ) & param_pairs( 2,: ) == sequence( 2,a(i) ));
end
%This is identifying what trigger code (1-6 corresponding to particular
%freq and pw of the randomized order of the a vector

result.param = param_pairs;
result.triggerSeq = trigger_sequence;  %storing param_pairs and trigger_sequence in result structure


%Human Response feedback ratings
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


%Out is the vector sent to arduino
out(3) = duration * 1000.0; %converts to ms
out(5) = stim_mode;


fprintf('Experiment starting in %d...', 3);
pause(1);
fprintf('%d...', 2);
pause(1);
fprintf('%d\r\n', 1);
pause(1);

for i = 1:length( a )
    fprintf('%d of %d| trigger %d \n', i, length(a), trigger_sequence( i ));
    out(1) = 1;    %turns on stimulation flag
    if PW_order( a(i) ) == 0
        out(1) = 0;
    end

    out(2) = 1000 / freq_order( a(i) );     %Period Parameter
    out(4) = PW_order( a(i) );              %Pulse Width Parameter
    out(6) = trigger_sequence( i );         % trigger type Parameter


    %Communication line to Arduino
    % Single means each value is a single precision float using 4 bytes
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
