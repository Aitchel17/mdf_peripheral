function [emgPower, emgSignal] = process_emg(emgRaw, sampling_frequency,...
                                            bandPower, bandSignal, FilterOrder, kernelWidth)

%% This function is scooped from 
% https://github.com/MdShakhawat-Hossain/ProcessAnalogData_SleepScore/blob/main/PreProcess/Helpers/Batch_Preprocess_TDMS_AnalogData.m
% From original function downsample, but this is not the case here.
arguments
    emgRaw
    sampling_frequency
    bandPower = [100 300]
    bandSignal = [10 100]
    FilterOrder = 3
    kernelWidth = 0.5
end

nyquist = sampling_frequency/2;
%% EMG POWER FILTER (100–300 Hz)
bandPower(2) = min(bandPower(2), nyquist*0.9);

[z,p,k] = butter(FilterOrder, bandPower/nyquist);
[sos,g] = zp2sos(z,p,k);
mean_subtractedEMG = emgRaw - mean(emgRaw);
filteredEMG = filtfilt(sos,g, mean_subtractedEMG); % mean subtracted EMG

kernel = gausswin(max(3,round(kernelWidth*sampling_frequency)));
kernel = kernel/sum(kernel);
emgPower = log10(conv(filteredEMG.^2, kernel, 'same'));


%% EMG SIGNAL FILTER (10–100 Hz)
bandSignal(2) = min(bandSignal(2), nyquist*0.9);
[z2,p2,k2] = butter(FilterOrder, bandSignal/nyquist);
[sos2,g2] = zp2sos(z2,p2,k2);
emgSignal = filtfilt(sos2,g2, emgRaw - mean(emgRaw));

end

