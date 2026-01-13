base_path = 'G:\tmp\00_igkl\hql088\250927_hql088_sleep\HQL088_sleep250927_005';
%% 1. Load Data
peripheral_session = peripheral_mdf(base_path);
peripheral_session = peripheral_session.loadraw_analogdata;
%% 2. Run Analysis
primary_analog = run_analog_analysis(peripheral_session);
%%
ecog_fig = peripheral_fig('ecog_spectrum');
%%
ecog_fig.reset_axis
%%
ecog_fig.plot_ecogspectrum(primary_analog.ecogspectrum)
%%
% Save Figure State (Data + Settings)
save_path = fullfile(peripheral_session.dir_struct.peripheral, 'ecogspectrum_state.mat');
save(save_path,"ecog_fig")
%% To Load and Reconstruct:
load(save_path);

%%
ecog_fig_loaded = peripheral_fig(loaded_state.state.fig_name);
ecog_fig_loaded.plot_state = loaded_state.state.plot_state;
ecog_fig_loaded.reconstruct();
%%
plot_ecogspectrum(primary_analog.ecogspectrum)
%% 99. Behavior data analysis