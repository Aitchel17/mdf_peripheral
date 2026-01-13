function primary_analog = run_analog_analysis(peripheral_session)
%RUN_ANALOG_ANALYSIS Runs standard analysis on peripheral analog data
%   Takes a peripheral_mdf session object, extracts analog data,
%   and runs air_puff and ecog analysis using analysis_analog class.

primary_analog = [];

if isempty(peripheral_session.raw_analog)
    return;
end

% Create analysis_analog object using loaded info and data
% analysis_analog constructor: obj = analysis_analog(info, data)
primary_analog = analysis_analog(peripheral_session.raw_analog.info, peripheral_session.raw_analog.data);

%% Analyze Air Puff
if isfield(primary_analog.data, 'raw_Air_puff1')
    % Call get_airtable method
    primary_analog.airtable = primary_analog.get_airtable('raw_Air_puff1');
    disp('Air Puff Table:');
    disp(primary_analog.airtable);
end

%% Analyze ECoG
if isfield(primary_analog.data, 'raw_ECoG')
    % Call get_ecogspectrum method
    primary_analog.ecogspectrum = primary_analog.get_ecogspectrum('raw_ECoG');
end
end
