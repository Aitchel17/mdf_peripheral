function [data_res,t_res,ds_fps] = process_resample(data, inFPS, target_fps, taxis)
arguments
    data
    inFPS
    target_fps
    taxis = []
end

% Forced resampling
% Estimate Sampling Frequency
[p, q] = rat(target_fps / inFPS, 1e-6);
data_res = resample(double(data), p, q);

ds_fps = inFPS * (p/q);

if ~isempty(taxis)
    t_start = taxis(1);
    t_end = taxis(end);
else
    t_start = 0;
    t_end = (length(data)-1)/inFPS;
end

% Generate new time axis
t_res = linspace(t_start, t_end, length(data_res));

resampled_struct.data = data_res;
resampled_struct.taxis = t_res;
resampled_struct.ds_fps = ds_fps;

end