%% 1. Load Data
sessiondir = 'G:\tmp\01_igkltdt\hql086\250920_hql086_whiskerb\HQL086_whiskerb250920_006';
%%
peripheral_session = peripheral_mdf(sessiondir);

%%


% 2. Run or load Analysis

if exist(fullfile(peripheral_session.dir_struct.peripheral,"analysis_analog.mat"),"file") == 2
    primary_analog = analysis_analog.load_object(peripheral_session.dir_struct.peripheral);
else
    primary_analog = run_analog_analysis(peripheral_session);
    primary_analog.save_object(peripheral_session.dir_struct.peripheral)
end

% Behaviorcam processing
if exist(fullfile(peripheral_session.dir_struct.peripheral,'analysis_camera.mat')) == 2
    load(fullfile(peripheral_session.dir_struct.peripheral,'analysis_camera.mat'),'camera_session')
else
    camera_session = analysis_camera(peripheral_session);
    camera_session.load_whisker(peripheral_session);
    camera_session.get_whiskermovement(5);
    camera_session.run_unet_analysis(peripheral_session.dir_struct.eye,true);
    camera_session.load_unet_pupil(peripheral_session.dir_struct.eye);
    camera_session.clean_pupil_outliers(1); % Remove blink artifacts
    save(fullfile(peripheral_session.dir_struct.peripheral,'analysis_camera.mat'),'camera_session')
end
%
% Initialize Figure Struct
close all
figStruct = struct();
figStruct.emg_power = peripheral_fig('EMG');
figStruct.rawemg = peripheral_fig('Low pass EMG');
figStruct.rawECoG = peripheral_fig('rawECoG');
figStruct.force = peripheral_fig('Force');
figStruct.spectrogram = peripheral_fig('ecog_spectrum');
figStruct.whisker = peripheral_fig('Whisker var');
figStruct.pupil = peripheral_fig('Pupil_dlc');

figStruct.emg_power.fig.Position = [30 7 8 3];
figStruct.rawemg.fig.Position = [21 7 8 3];%[30 7 8 3]%[21 3.5 8 3];
figStruct.rawECoG.fig.Position = [30 0.5 8 3];
figStruct.rawECoG.fig.Visible = 'off';
figStruct.spectrogram.fig.Position = [21 3.5 8 3];%[30 7 8 3];
figStruct.force.fig.Position = [21 0.5 8 3];
figStruct.whisker.fig.Position = [30 0.5 8 3];
figStruct.pupil.fig.Position = [30 3.5 8 3];
figStruct.pupil.fig.Visible = 'on';

% whisker figure
figStruct.whisker.plot_line(camera_session.whisker.var_mean_whisker,"XAxis",camera_session.whisker.var_taxis)
ylabel(figStruct.whisker.ax, 'Face mean variance')
xlabel(figStruct.whisker.ax, 'Time (sec)')

% Analog figure
figStruct.emg_power.reset_axis
figStruct.emg_power.plot_line(primary_analog.emg.resampled_power, Xaxis=primary_analog.emg.rs_taxis)
ylabel(figStruct.emg_power.ax, 'EMG power')
xlabel(figStruct.emg_power.ax, 'sec')

% Raw EMG figure
figStruct.rawemg.reset_axis
figStruct.rawemg.plot_line(primary_analog.emg.resampled_signal, Xaxis=primary_analog.emg.rs_taxis)
ylabel(figStruct.rawemg.ax, 'EMG (mV)')
xlabel(figStruct.rawemg.ax, 'Time (sec)')

% Raw ECoG figure
figStruct.rawECoG.reset_axis
figStruct.rawECoG.plot_line(primary_analog.ecog.resampled_ecog, Xaxis=primary_analog.emg.rs_taxis)
ylabel(figStruct.rawECoG.ax, 'ECoG (\muV)')
xlabel(figStruct.rawECoG.ax, 'Time (sec)')

% Force Figure
figStruct.force.reset_axis
figStruct.force.plot_line(primary_analog.force.lowpass_force, Xaxis=primary_analog.force.rs_taxis)
ylabel(figStruct.force.ax, 'Force (N)')
xlabel(figStruct.force.ax, 'Time (sec)')

% ECoG figure
figStruct.spectrogram.reset_axis
if isfield(primary_analog.ecog.ecogspectrum,'baseline_S')
    figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.baseline_S,...
        primary_analog.ecog.ecogspectrum.T,primary_analog.ecog.ecogspectrum.F)
else
    figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.log_norm_spectrum,...
        primary_analog.ecog.ecogspectrum.T,primary_analog.ecog.ecogspectrum.F)
end
% Pupil figure
figStruct.pupil.reset_axis
if isfield(camera_session.eye,'diameter')
    figStruct.pupil.plot_line(camera_session.eye.diameter, XAxis=camera_session.eye.t_axis)
end
ylabel(figStruct.pupil.ax, 'Pupil diameter')
xlabel(figStruct.pupil.ax, 'Time (sec)')

%% 99. ECoG baseline selection

% Load or initialize scoring gui
if exist(fullfile(peripheral_session.dir_struct.peripheral,"ECoG_gui.mat"))
    load(fullfile(peripheral_session.dir_struct.peripheral,"ECoG_gui.mat"));
else
    session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
    ECoG_gui = sleepscoring_gui(session_duration);
end
ECoG_gui.setup_figure(figStruct)
ECoG_gui.setup_control_panel();
uiwait(ECoG_gui.figHandle);
save(fullfile(peripheral_session.dir_struct.peripheral,'ECoG_gui.mat'),'ECoG_gui')

% ECoG baseline normalized spectrogram generation
ECoG_baseline = ECoG_gui.get_results('ECoG_baseline',peripheral_session.dir_struct.peripheral);
primary_analog.get_ecogbaseline(ECoG_baseline.AwakeTimes,ECoG_baseline.binwidth_sec);
primary_analog.save_object(peripheral_session.dir_struct.peripheral)
%
% Update ECoG using baseline normalized ECog
figStruct.spectrogram.reset_axis
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.baseline_S,...
    primary_analog.ecog.ecogspectrum.T, primary_analog.ecog.ecogspectrum.F)
% ECoG figure
figStruct.spectrogram.reset_axis
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.baseline_S,...
    primary_analog.ecog.ecogspectrum.T,primary_analog.ecog.ecogspectrum.F)

%% 04 Sleep analysis loading 
if exist(fullfile(peripheral_session.dir_struct.peripheral,"sleep_gui.mat"))
    load(fullfile(peripheral_session.dir_struct.peripheral,"sleep_gui.mat"));
else
    session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
    sleep_gui = sleepscoring_gui(session_duration);
end
%%
sleep_gui.setup_figure(figStruct)
sleep_gui.setup_control_panel();
sleep_gui.goto_bin(1)
uiwait(sleep_gui.figHandle);

%%
sleep_result = sleep_gui.get_results('sleep_score',peripheral_session.dir_struct.peripheral);
save(fullfile(peripheral_session.dir_struct.peripheral,'sleep_gui.mat'),'sleep_gui')
%%
sleep_gui.setup_figure(figStruct);
sleep_gui.save_figure('sleep_score_result',peripheral_session.dir_struct.peripheral)
close(sleep_gui.figHandle);

%%


%%
figStruct.spectrogram.fig.Visible = 'off';
figStruct.force.fig.Visible = 'off';
figStruct.rawECoG.fig.Visible = 'off';
figStruct.rawemg.fig.Visible = 'off';
figStruct.emg_power.fig.Visible = 'off';
figStruct.whisker.fig.Visible = 'off';
figStruct.pupil.fig.Visible = 'off';
%%
figStruct.spectrogram.fig.Visible = 'on';
figStruct.force.fig.Visible = 'on';
figStruct.rawECoG.fig.Visible = 'on';
figStruct.rawemg.fig.Visible = 'on';
figStruct.emg_power.fig.Visible = 'on';
figStruct.whisker.fig.Visible = 'on';
figStruct.pupil.fig.Visible = 'on';
