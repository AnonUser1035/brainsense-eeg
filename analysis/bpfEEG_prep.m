%% BPF for preprocessing

data = EEG.data;
fs = EEG.srate;
numChan = size(data,1);
fData = zeros(size(data));
for i = 1:numChan
    fData(i,:) = bp_filter(double(data(i,:)),0.3,50,fs);
end
EEG.data = single(fData);

%% check if filtering is good
% do_fft(data(1, :),fs); % fft on before filter
% do_fft(fData(1,:), fs); % fft on after filter

%% save .set DO NOT SKIP THIS STEP
pop_saveset(EEG);
