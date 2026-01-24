%% 1. Load Data
base_path = 'G:\tmp\00_igkl\hql088\250927_hql088_sleep\HQL088_sleep250927_009';
peripheral_session = peripheral_mdf(base_path);

%% 2. Run or load Analysis

if exist(fullfile(peripheral_session.dir_struct.peripheral,"analysis_analog.mat"),"file") == 2
    primary_analog = analysis_analog.load_object(peripheral_session.dir_struct.peripheral);
else
    primary_analog = run_analog_analysis(peripheral_session);
end
%% Initialize Figure Struct
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

%% Behaviorcam processing
camera_session = analysis_camera(peripheral_session);
camera_session.get_whiskermovement(5);
%% pupil analysis
camera_session.run_pupil_analysis(peripheral_session.dir_struct.eye)

%% whisker figure
figStruct.whisker.plot_line(camera_session.whisker.var_mean_whisker,"XAxis",camera_session.whisker.var_taxis)
ylabel(figStruct.whisker.ax, 'Face mean variance')
xlabel(figStruct.whisker.ax, 'Time (sec)')


%% ECoG baseline measurement



%% Analog figure
%%
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
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.baseline_S,...
    primary_analog.ecog.ecogspectrum.T,primary_analog.ecog.ecogspectrum.F)
%%
%% 99. ECoG baseline selection
session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
ECoG_baseline = sleepscoring_gui(session_duration);
ECoG_baseline.setup_figure(figStruct)
ECoG_baseline.setup_control_panel();
%%
ECoG_baseline_5s = ECoG_baseline.get_results;
primary_analog.get_ecogbaseline(ECoG_baseline_5s.AwakeTimes,ECoG_baseline.Data.binWidth_s);

figStruct.spectrogram.reset_axis
figStruct.spectrogram.plot_ecogspectrum(primary_analog.ecog.ecogspectrum.baseline_S,...
    primary_analog.ecog.ecogspectrum.T, primary_analog.ecog.ecogspectrum.F)

%% Seconds bin to spectrogram
target_taxis = primary_analog.ecog.ecogspectrum.T;


%%
session_duration = str2double(peripheral_session.info.fcount)*str2double(peripheral_session.info.fduration(1:end-1));
sleep_score = sleepscoring_gui(session_duration);
sleep_score.setup_figure(figStruct)
sleep_score.setup_control_panel();
sleep_score.goto_bin(1)
sleep_result = sleep_score.get_results;
uiwait(sleep_score.figHandle);
%%

sleep_result = sleep_score.get_results;




%% Save Analysis Object
fprintf('Saving primary_analog object...\n');
primary_analog.save_object(output_dir);





%% Save Figures to Peripheral Folder
output_dir = peripheral_session.dir_struct.peripheral;
fields = fieldnames(figStruct);
fprintf('Saving figures to %s...\n', output_dir);

for i = 1:numel(fields)
    fName = fields{i};
    % Check if field is a valid peripheral_fig object
    if ~isempty(figStruct.(fName)) && isa(figStruct.(fName), 'peripheral_fig')
        figStruct.(fName).save_plot(output_dir);
    end
end
disp('All figures saved.');


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
