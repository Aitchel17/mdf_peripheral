base_path = 'G:\tmp\00_igkl\hql090\251016_hql090_sleep\HQL090_sleep251016_002';
%% 1. Load Data
peripheral_session = peripheral_mdf(base_path);
peripheral_session = peripheral_session.loadraw_analogdata;
% 2. Run Analysis
primary_analog = run_analog_analysis(peripheral_session);
%% Initialize Figure Struct
figStruct = struct();
figStruct.emg = peripheral_fig('EMG');
figStruct.rawemg = peripheral_fig('Low pass EMG');
figStruct.rawECoG = peripheral_fig('rawECoG');
figStruct.force = peripheral_fig('Force');
figStruct.spectrogram = peripheral_fig('ecog_spectrum');
figStruct.whisker = peripheral_fig('Whisker var');

%% EMG power figure
%%
figStruct.emg.reset_axis
figStruct.emg.plot_line(primary_analog.emg.resampled_power, Xaxis=primary_analog.emg.rs_taxis)
ylabel(figStruct.emg.ax, 'EMG power')
xlabel(figStruct.emg.ax, 'sec')

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
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum)

%% Behaviorcam processing
camera_session = analysis_camera(peripheral_session);
camera_session.get_whiskermovement(5);
%% pupil analysis
camera_session.run_pupil_analysis(peripheral_session.dir_struct.eye)

%% whisker figure
figStruct.whisker.plot_line(camera_session.whisker.var_mean_whisker,"XAxis",camera_session.whisker.var_taxis)
ylabel(figStruct.whisker.ax, 'Face mean variance')
xlabel(figStruct.whisker.ax, 'Time (sec)')
%%
figStruct.spectrogram.fig.Visible = 'off';
figStruct.force.fig.Visible = 'off';
figStruct.rawECoG.fig.Visible = 'off';
figStruct.rawemg.fig.Visible = 'off';
figStruct.emg.fig.Visible = 'on';
figStruct.whisker.fig.Visible = 'off';

%% 99. Behavior data analysis
session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
sleepscore = sleepscoring_gui(session_duration);
sleepscore.setup_figure(figStruct)
%%
sleepscore.setup_control_panel();
%%
sleepscore.goto_bin(1);


%%
% Setup Figure
obj.setup_figure(figStruct);
% Setup Control Panel
obj.setup_control_panel();
% Start Navigation
obj.goto_bin(1);

