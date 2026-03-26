%% playStereoTones.m
% Author: Alessandro Ascani Orsini
% Version: 1.0
% Description:
%   Plays two different tones or two different WAV files in left/right ears.

function playStereoTones(mode,fL,fR,dur)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Usage:
    %   playStereoTones('tone')    % Generate tones (default)
    %   playStereoTones('file')    % Play two WAV files (left.wav, right.wav)
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    f_carry = 460;
    f_envelope = 40;
    dev = audiodevinfo;
    dev.output.Name

    if ~exist('mode', 'var') || isempty(mode)
        mode = 'tone';
    end
    if ~exist('fL', 'var') || isempty(fL)
        fL = f_carry+f_envelope;
    end
    if ~exist('fR', 'var') || isempty(fR)
        fR = f_carry;
    end
    if ~exist('dur', 'var') || isempty(dur)
        dur = 5.0;         % Duration in seconds
    end

    switch lower(mode)
        case 'tone'
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Generate two tones
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fs = 48000;        % Sample rate
            t = (0:1/fs:dur-1/fs)';

            left  = 0.2 * sin(2*pi*fL*t);   % A4 tone in left ear
            right = 0.2 * sin(2*pi*fR*t);   % E5 tone in right ear

            stereo = [left, right];          % Combine into stereo
            sound(stereo, fs);
            fprintf('Playing tones: Left=%i Hz, Right=%i Hz\n', fL,fR);

        case 'file'
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Play two separate WAV files
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [left, fs1]  = audioread('left.wav');
            [right, fs2] = audioread('right.wav');

            % Convert to mono if needed
            if size(left,2) > 1,  left = mean(left,2);  end
            if size(right,2) > 1, right = mean(right,2); end

            % Resample to same fs
            fs = 48000;
            if fs1 ~= fs
                left = resample(left, fs, fs1);
            end
            if fs2 ~= fs
                right = resample(right, fs, fs2);
            end

            % Pad shorter file
            L = max(length(left), length(right));
            left(L)  = 0;
            right(L) = 0;

            stereo = [left, right];
            sound(stereo, fs);
            fprintf('Playing left.wav (left) and right.wav (right)\n');

        otherwise
            error('Unknown mode: use ''tone'' or ''file''.');
    end
end