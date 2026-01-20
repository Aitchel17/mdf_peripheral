%% Wrapper script for sleepscoring_gui class
% This script demonstrates how to usage the class-based sleep scoring GUI.
% It assumes you have 'figStruct' and data parameters ready, usually from main_analog.m

% 1. Setup Mock Data (if running standalone)
if ~exist('figStruct', 'var')
    % If running independently, warn user or verify data exists
    % For this wrapper, we assume variables exist in base workspace
    warning('figStruct not found. Run main_analog.m up to the scoring section first.');
    return;
end

if ~exist('binWidth', 'var'), binWidth = 5; end
if ~exist('NBins', 'var')
    % Try to calculate from existing data if possible
    if isfield(figStruct, 'emg') && isvalid(figStruct.emg.ax)
        % This is tricky without access to raw data, so rely on variables
        NBins = 100; % Default fallback
    end
end

% 2. Instantiate the GUI
% This replaces the call to CreateTrainingDataSet_SleepAnalog
gui = sleepscoring_gui(figStruct, NBins, binWidth);

% 3. Run interacting
disp('GUI Launched. Score using buttons or keys (n,r,w).');
disp('Close the GUI window when finished.');

% 4. Wait for completion (optional, if you want blocking behavior)
% waitfor(gui.figHandle);

% 5. Retrieve Results
% After closing, valid object handle might need management or event listening
% Ideally, the class handles data export or returns it via a method before deletion.
% Since 'gui' is a handle, if the figure is deleted, the object might still exist
% but properties depending on figure handle will fail.
% The 'close_request_handler' in the class notifies 'ScoringComplete'.

% access results from the object properties (if it still exists)
if isvalid(gui)
    trainingTable = gui.get_results();
    assignin('base', 'trainingTable', trainingTable);
    disp('Results saved to workspace variable "trainingTable".');
else
    disp('GUI object deleted.');
end
