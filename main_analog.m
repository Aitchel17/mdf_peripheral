base_path = 'G:\tmp\00_igkl\hql090\251016_hql090_sleep\HQL090_sleep251016_006';
%% 1. Load Data
peripheral_session = peripheral_mdf(base_path);
peripheral_session = peripheral_session.loadraw_analogdata;
%% 2. Run Analysis
primary_analog = run_analog_analysis(peripheral_session);
%% Initialize Figure Struct
figStruct = struct();

% EMG power figure
figStruct.emg = peripheral_fig('EMG');
figStruct.emg.reset_axis
figStruct.emg.plot_line(primary_analog.emg.resampled_power, Xaxis=primary_analog.emg.rs_taxis)
% Raw EMG figure
figStruct.rawemg = peripheral_fig('rawEMG');
figStruct.rawemg.reset_axis
figStruct.rawemg.plot_line(primary_analog.emg.resampled_signal, Xaxis=primary_analog.emg.rs_taxis)
% Raw ECoG figure
figStruct.rawECoG = peripheral_fig('rawECoG');
figStruct.rawECoG.reset_axis
figStruct.rawECoG.plot_line(primary_analog.ecog.resampled_ecog, Xaxis=primary_analog.emg.rs_taxis)
% Force Figure
figStruct.force = peripheral_fig('Force');
figStruct.force.reset_axis
figStruct.force.plot_line(primary_analog.force.lowpass_force, Xaxis=primary_analog.force.rs_taxis)
% ECoG figure
figStruct.spectrogram = peripheral_fig('ecog_spectrum');
figStruct.spectrogram.reset_axis
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum)
%%
figStruct.spectrogram.fig.Visible = 'off';
figStruct.force.fig.Visible = 'off';
figStruct.rawECoG.fig.Visible = 'off';
figStruct.rawemg.fig.Visible = 'off';
figStruct.emg.fig.Visible = 'off';
%% Behaviorcam processing
camera_session = analysis_camera(peripheral_session);
camera_session.get_whiskermovement(5);
%% whisker figure
figStruct.whisker = peripheral_fig('Whisker var');
figStruct.whisker.plot_line(camera_session.whisker.var_mean_whisker,"XAxis",camera_session.whisker.var_taxis)
ylabel(figStruct.whisker.ax, 'Whisker var 1prc')

%%
figStruct.whisker.fig.Visible = 'off';


%%
session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
sleepscore = sleepscoring_gui(figStruct, session_duration);

%% 99. Behavior data analysis


%% ---------------------------------------------------------
%% Example: Integrated Sleep Scoring Workflow
%% ---------------------------------------------------------

% 1. Create a composite figure (5 rows)
% 1. Pack figures into struct
% (Already done above)
figStruct.pupil       = [];             % Initialize Pupil field as empty (none available)

% 2. Run the "Pure GUI" Scoring
% Note: Define NBins based on data duration and bin width
binWidth = 5;                           % Set bin width in seconds
duration = max(primary_analog.emg.rs_taxis); % Calculate total duration from EMG time axis
NBins = floor(duration / binWidth);     % Calculate total number of bins

fprintf('Starting Sleep Scoring GUI...\n');
trainingTable = CreateTrainingDataSet_SleepAnalog(figStruct, NBins, binWidth); % Call scoring function with struct

% 3. Save Results (Manually, since GUI is pure)
% save('MyScoringResults.mat', 'trainingTable');
