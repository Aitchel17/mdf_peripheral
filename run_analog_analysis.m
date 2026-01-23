function primary_analog = run_analog_analysis(peripheral_session)
%RUN_ANALOG_ANALYSIS Runs standard analysis on peripheral analog data
%   Takes a peripheral_mdf session object, extracts analog data,
%   and runs air_puff and ecog analysis using analysis_analog class.


% Create analysis_analog object using loaded info and data
% analysis_analog constructor: obj = analysis_analog(info, data)
primary_analog = analysis_analog(peripheral_session.raw_analog.info, peripheral_session.loadanalog_data);

%% Analyze Air Puff
if isfield(primary_analog.rawdata, 'raw_Air_puff1')
    % Call get_airtable method
    primary_analog.get_airtable('raw_Air_puff1');
else
    fprintf('no raw_Air_puff1 in primary_analog.data')
end

%% Analyze ECoG
if isfield(primary_analog.rawdata, 'raw_ECoG')
    % Call get_ecogspectrum method
    primary_analog.get_ecogspectrum('raw_ECoG'); % calculate ECoG
    %% EMG processing followed by ECoG processing
    if isfield(primary_analog.rawdata, 'raw_EMG')
        primary_analog.get_emgpower('raw_EMG')
    end
    %% Force processing followed by ECoG processing
    if isfield(primary_analog.rawdata, 'raw_Force')
        primary_analog.get_binaryforce('raw_Force')
    end
    %% Locomotion processing followed by ECoG processing

else
    fprintf('no raw_ECoG in primary_analog.data\n')
end

%%

primary_analog.save_object(peripheral_session.dir_struct.peripheral)
%%

end
