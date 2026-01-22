classdef analysis_analog < handle
    %ANALYSIS_ANALOG Summary of this class goes here
    %   Detailed explanation goes here

    properties
        info = struct()
        rawdata = struct()
        airtable = table()
        ecog = struct()
        emg = struct()
        force = struct()
        ball = struct()
        samplingfrequency
        ampsetup = struct('ecog_dam80',10000,'emg_dam80',1000,'force_dagan',50)
        ampbandpass = struct('ecog_dam80',[0.1 1000],'emg_dam80',[0.1 1000])
        tekscanForcesensor = struct('Quickstartboard_outputVoltage',5,'A210sensor_newton',4.4)
    end

    methods
        function obj = analysis_analog(info_struct,data_struct)
            %ANALYSIS_ANALOG Construct an instance of this class
            %   Detailed explanation goes here
            obj.info = info_struct;
            obj.rawdata = data_struct;
            obj.samplingfrequency = str2double(obj.info.analogfreq(1:end-2));
            total_datapoints = str2double(obj.info.analogcount);
            obj.rawdata.taxis = linspace(0,total_datapoints/obj.samplingfrequency,total_datapoints);
        end

        function get_airtable(obj, airpuff_fieldname)
            % find single air puff initiation
            binary_airpuff = obj.rawdata.(airpuff_fieldname)>0; % binarize data on or off
            diff_airpuff = diff(binary_airpuff); % differentiate rising and faling
            stim_on_idx = find(diff_airpuff ==1); % find rising edge, each data point is cumulative point when stim on
            stim_off_idx = find(diff_airpuff ==-1); % find falling edge
            stim_on_time = obj.rawdata.taxis(stim_on_idx); % match time scale, each data point is time when stim on
            stim_off_time = obj.rawdata.taxis(stim_off_idx+1);
            stim_on_int = diff(stim_on_time); % slope of stim on time point = frequency of stim
            % find session boundary, inter session interval should be
            % longer then 10 sec
            session_boundary_idx = find(stim_on_int>10); % the interval between session should longer then 10 sec
            session_end = [stim_off_time(session_boundary_idx),stim_off_time(end)];
            session_start = [stim_on_time(1),stim_on_time(session_boundary_idx+1)];
            session_duration = session_end-session_start;
            stim_on_off_idx = stim_off_idx-stim_on_idx;
            stim_on_on_idx = stim_on_idx(2:end)-stim_on_idx(1:end-1);
            stim_duty = stim_on_off_idx(1:end-1)./stim_on_on_idx;
            session_frequency = [];
            session_duty = [];
            for session_id = 0:length(session_boundary_idx)
                % initial
                if session_id == 0
                    session_start_idx = 1;
                    session_end_idx = session_boundary_idx(1)-1;
                elseif session_id == length(session_boundary_idx)
                    session_start_idx = session_boundary_idx(session_id)+1;
                    session_end_idx = length(stim_on_int);
                else
                    session_start_idx = session_boundary_idx(session_id)+1;
                    session_end_idx = session_boundary_idx(session_id+1)-1;
                end
                session_frequency = [session_frequency,1/mean(stim_on_int(session_start_idx:session_end_idx))];
                session_duty = [session_duty,mean(stim_duty(session_start_idx:session_end_idx))];
            end
            air_puff_data = [session_start;session_end;session_duration;session_frequency;session_duty]';
            air_puff_table = array2table(air_puff_data,'VariableNames', {'StartTime', 'EndTime', 'Duration', 'FrequencyHz', 'DutyCycle'});
            obj.airtable = air_puff_table;
        end

        function get_ecogspectrum(obj,ecog_fieldname)
            arguments
                obj
                ecog_fieldname
            end
            % ECoG processing
            %% Rescale
            ecog_data = obj.rawdata.(ecog_fieldname);
            %%
            % converting parameters
            analog_resolution = 2^str2double(obj.info.analogresolution(1:end-4));
            scale2V = str2double(obj.info.ECoGinputrange(2:end-1));
            %%
            rescaledECoG = ecog_data*2/analog_resolution; % mScan recording scale
            rescaledECoG = rescaledECoG*scale2V; % mScan scale factor
            rescaledECoG = rescaledECoG/obj.ampsetup.ecog_dam80; % undo amplification
            rescaledECoG = rescaledECoG*10^6; % scale from V to uV
            %%
            ecog_spectrum = analog_ecogspectrum(obj.samplingfrequency,rescaledECoG);
            obj.ecog.ecogspectrum = ecog_spectrum;
            obj.rawdata.(ecog_fieldname) = rescaledECoG;
            %%
            plot(rescaledECoG)
            %%
            [rs_ecog, rs_t, rs_fs] = process_resample(rescaledECoG, obj.samplingfrequency, 60, obj.rawdata.taxis);
            obj.ecog.resampled_ecog = rs_ecog;
            obj.ecog.resampled_taxis = rs_t;
            obj.ecog.ds_fps = rs_fs;
        end

        function get_emgpower(obj,emg_fieldname)
            arguments
                obj
                emg_fieldname
            end

            %% Rescale
            % converting parameters
            analog_resolution = 2^str2double(obj.info.analogresolution(1:end-4));
            scale2V = str2double(obj.info.EMGinputrange(2:end-1));
            rescaledEMG = obj.rawdata.(emg_fieldname)*2/analog_resolution; % mScan recording scale
            rescaledEMG = rescaledEMG*scale2V; % mScan scale factor
            rescaledEMG = rescaledEMG/obj.ampsetup.emg_dam80; % undo amplification
            rescaledEMG = rescaledEMG*10e3; % scale from V to mV
            %%
            [obj.emg.power, obj.emg.signal] = process_emg(rescaledEMG,obj.samplingfrequency);
            [rs_power_data, rs_power_t, rs_power_fs] = process_resample(obj.emg.power, obj.samplingfrequency, 60, obj.rawdata.taxis);
            [rs_signal_data, ~, ~] = process_resample(obj.emg.signal, obj.samplingfrequency, 60, obj.rawdata.taxis);

            obj.emg.resampled_power = rs_power_data;
            obj.emg.resampled_signal = rs_signal_data;
            obj.emg.ds_fps = rs_power_fs;
            obj.emg.rs_taxis = rs_power_t;
            obj.rawdata.(emg_fieldname) = rescaledEMG;
            
        end

        function get_binaryforce(obj,force_fieldname)
            arguments
                obj
                force_fieldname
            end
            % converting parameters
            %% Rescale
            forcedata = obj.rawdata.(force_fieldname);
            %% converting parameters
            analog_resolution = 2^str2double(obj.info.analogresolution(1:end-4));
            scale2V = str2double(obj.info.Forceinputrange(2:end-1));
            rescaledForce = obj.rawdata.(force_fieldname)*2/analog_resolution; % mScan recording scale
            rescaledForce = rescaledForce*scale2V; % mScan scale factor
            rescaledForce = rescaledForce/obj.ampsetup.force_dagan; % undo amplification
            rescaledForce = rescaledForce/obj.tekscanForcesensor.Quickstartboard_outputVoltage; % stretch to maxrange of evaluation board
            rescaledForce = rescaledForce*obj.tekscanForcesensor.A210sensor_newton; % 

            [rs_force_data, rs_force_t, rs_force_fs] = process_resample(rescaledForce, obj.samplingfrequency, 60, obj.rawdata.taxis);
            [lp_force, bin, threshold] = process_force(rs_force_data, rs_force_fs);
            obj.force.lowpass_force = lp_force;
            obj.force.thr_bin = bin;
            obj.force.threshold = threshold;
            obj.force.resampled_force = rs_force_data;
            obj.force.ds_fps = rs_force_fs;
            obj.force.rs_taxis = rs_force_t;
            obj.rawdata.(force_fieldname) = rescaledForce;
        end

        function save_object(obj, save_folder)
            %SAVE_OBJECT Save the analysis_analog object to a folder
            arguments
                obj
                save_folder char
            end
            
            if ~isfolder(save_folder)
                mkdir(save_folder);
            end
            
            % Save as analysis_analog.mat
            save_path = fullfile(save_folder, 'analysis_analog.mat');
            % Assign to a variable name for clarity in the MAT file
            primary_analog = obj; 
            save(save_path, 'primary_analog');
            fprintf('analysis_analog object saved to: %s\n', save_path);
        end
    end

    methods (Static)
        function obj = load_object(load_folder)
            %LOAD_OBJECT Load the analysis_analog object from a folder
            try
                load_path = fullfile(load_folder, 'analysis_analog.mat');
                loaded_data = load(load_path, 'primary_analog');
                obj = loaded_data.primary_analog;
                fprintf('Loaded analysis_analog object from: %s\n', load_path);
            catch ME
                warning('Failed to load object: %s', ME.message);
                obj = [];
            end
        end
    end

end
