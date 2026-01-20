function [lpforce, binRaw, thresh] = process_force(forceRaw, sampling_frequency, lowpasscutoff, lowpassorder)
%% This function is scooped from 
% https://github.com/MdShakhawat-Hossain/ProcessAnalogData_SleepScore/blob/main/PreProcess/Helpers/Batch_Preprocess_TDMS_AnalogData.m
% From original function downsample, but this is not the case here.
arguments
    forceRaw
    sampling_frequency
    lowpasscutoff = 20;
    lowpassorder = 2;
end
%%
absforce = abs(forceRaw);


%% Design low-pass filter
[z,p,k] = butter(lowpassorder, lowpasscutoff/(sampling_frequency/2),'low');
[sos,g] = zp2sos(z,p,k);

% Filter force (no explicit edge "fix" – rely on filtfilt's internal padding)
%%
lpabsforce = filtfilt(sos, g, absforce - mean(absforce));
lpforce = filtfilt(sos, g, forceRaw - mean(forceRaw));
lpabsforce_norm = lpabsforce./prctile(lpabsforce,99.99);

% OPTIONAL: if you really want *very* gentle edge handling, you could
% truncate a tiny amount (e.g. 0.1 s) at start/end instead of copying
% segments, but here we keep the full length.

% ----- threshold GUI -----
t = (0:numel(forceRaw)-1)/sampling_frequency;

done   = false;
binRaw = [];
thresh = [];

figH = [];   % store figure handle

while ~done
    % Create figure if not already created
    figH = figure('Color','w','Name','Force Threshold');

    subplot(2,1,1); 
    plot(t, lpabsforce_norm); 
    title('Raw Force'); grid on;
    if ~isempty(thresh), yline(thresh,'r--'); end

    if ~isempty(binRaw)
        subplot(2,1,2); 
        plot(t, binRaw); 
        ylim([-0.1 1.1]); 
        grid on;
    end

    answ = inputdlg('Force threshold:','Threshold',1,{'0.2'});
    if isempty(answ), error('Cancelled'); end
    thresh = str2double(answ{1});

    binRaw = lpabsforce_norm > thresh;

    clf(figH);   % clear figure but keep same window

    subplot(2,1,1);
    plot(t, lpabsforce_norm); 
    yline(thresh,'r--');
    title('Raw Force with threshold'); 
    grid on;

    subplot(2,1,2);
    plot(t, binRaw); 
    ylim([-0.1 1.1]); 
    title('Binary force'); 
    grid on;

    resp = questdlg('Accept threshold?','Confirm','Yes','No','Yes');
    if strcmp(resp,'Yes')
        done = true;
    end
end

% Close the figure after threshold is accepted
if ishghandle(figH)
    close(figH);
end

end

