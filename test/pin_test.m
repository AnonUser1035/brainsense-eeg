%% Pin Test Script
% Tests each Arduino pin one at a time (HIGH for 2 seconds, then LOW).
% Use this to verify wiring after resoldering — check which LED lights up
% and which signal appears on the EEG software for each pin.
%
% REQUIRES: Upload test/PinTest/PinTest.ino to the Arduino first.

clc; clear all;

%% Connect to Arduino
% stimulator = serialport('/dev/cu.usbmodem14101', 9600);  % macOS
stimulator = serialport('COM3', 9600);
configureTerminator(stimulator, "LF");
pause(2);  % wait for Arduino to reset after serial connection

fprintf('Connected on %s\n', stimulator.Port);

%% Define pins to test
pins = [8, 9, 10, 11, 12, 13];
pin_labels = {'Trigger Bit 0 (Red LED)', 'Trigger Bit 1 (Yellow LED)', ...
              'Trigger Bit 2 (Green LED)', 'Unknown (Blue LED)', ...
              'Stimulator Left (no LED)', 'Stimulator Right (no LED)'};

%% Test each pin
for i = 1:length(pins)
    fprintf('\n--- Test %d of %d ---\n', i, length(pins));
    fprintf('Activating pin %d (%s) for 2 seconds...\n', pins(i), pin_labels{i});

    writeline(stimulator, num2str(pins(i)));

    pause(3);  % 2s for the pulse + 1s buffer

    % Read any serial output from Arduino
    while stimulator.NumBytesAvailable > 0
        fprintf('  Arduino: %s\n', readline(stimulator));
    end

    response = input('What did you observe? (press Enter to continue, or type notes): ', 's');
    if ~isempty(response)
        fprintf('  Note for pin %d: %s\n', pins(i), response);
    end
end

fprintf('\n=== All pins tested ===\n');

%% Cleanup
clear stimulator;
