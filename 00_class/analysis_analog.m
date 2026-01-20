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
            ECoG = obj.rawdata.(ecog_fieldname);
            ecog_spectrum = analog_ecogspectrum(obj.samplingfrequency,ECoG);
            obj.ecog.ecogspectrum = ecog_spectrum;
            [rs_ecog, rs_t, rs_fs] = process_resample(obj.rawdata.(ecog_fieldname), obj.samplingfrequency, 60, obj.rawdata.taxis);
            obj.ecog.resampled_ecog = rs_ecog;
            obj.ecog.resampled_taxis = rs_t;
            obj.ecog.ds_fps = rs_fs;
        end

        function get_emgpower(obj,emg_fieldname,fps)
            arguments
                obj
                emg_fieldname
                fps = []
            end
            [obj.emg.power, obj.emg.signal] = process_emg(obj.rawdata.(emg_fieldname),obj.samplingfrequency);
            [rs_power_data, rs_power_t, rs_power_fs] = process_resample(obj.emg.power, obj.samplingfrequency, 60, obj.rawdata.taxis);
            [rs_signal_data, ~, ~] = process_resample(obj.emg.signal, obj.samplingfrequency, 60, obj.rawdata.taxis);

            obj.emg.resampled_power = rs_power_data;
            obj.emg.resampled_signal = rs_signal_data;
            obj.emg.ds_fps = rs_power_fs;
            obj.emg.rs_taxis = rs_power_t;
        end

        function get_binaryforce(obj,force_fieldname,fps)
            arguments
                obj
                force_fieldname
                fps = []
            end

            [rs_force_data, rs_force_t, rs_force_fs] = process_resample(obj.rawdata.(force_fieldname), obj.samplingfrequency, 60, obj.rawdata.taxis);
            [lp_force, bin, threshold] = process_force(rs_force_data, rs_force_fs);
            obj.force.lowpass_force = lp_force;
            obj.force.thr_bin = bin;
            obj.force.threshold = threshold;
            obj.force.resampled_force = rs_force_data;
            obj.force.ds_fps = rs_force_fs;
            obj.force.rs_taxis = rs_force_t;
        end

    end

end
