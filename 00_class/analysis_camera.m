classdef analysis_camera < handle
    properties
        parameter = struct()
        whisker
        eye
        samplingfrequency
    end

    methods
        function obj = analysis_camera(peripheral_session)
            %ANALYSIS_CAMERA Construct an instance of this class
            %   Detailed explanation goes here
            obj.whisker.raw_whisker = peripheral_session.loadwhisker;
            obj.parameter.analog_count = str2double(peripheral_session.raw_analog.info.analogcount);
            obj.parameter.analog_fs = str2double(peripheral_session.raw_analog.info.analogfreq(1:end-2));
            obj.parameter.analog_end = obj.parameter.analog_count/obj.parameter.analog_fs;

            obj.parameter.twophoton_count = str2double(peripheral_session.info.fcount);
            obj.parameter.twophoton_fps = str2double(peripheral_session.info.fps);
            obj.parameter.twophoton_end = obj.parameter.twophoton_count/obj.parameter.twophoton_fps;

            %sampling frequency calculation
            obj.parameter.whisker_count = size(obj.whisker.raw_whisker,3);
            if isfield(obj.parameter,'analog_end')
                disp('analog_end used to calculate camera end')
                obj.parameter.whisker_end = obj.parameter.analog_end;
                obj.samplingfrequency = obj.parameter.whisker_count/obj.parameter.analog_end;
            elseif isfield(obj.parameter,'twophoton_end')
                disp('analog_end used to calculate camera end')
                obj.samplingfrequency = obj.parameter.whisker_count/obj.parameter.twophoton_end;
            else
                disp('camera data sampling frequency fixed to 33.3216 calculated from other session')
                obj.samplingfrequency = 33.3216;
            end
        end

        function obj = get_whiskermovement(obj,groupwindow)
            obj.whisker.groupwindow = groupwindow;
            [gpvar_whisker,group_depricatedframe] = cam_groupproject(obj.whisker.raw_whisker,groupwindow,'var');
            obj.whisker.var_mean_whisker = squeeze(mean(gpvar_whisker,[1,2]));
            % samplingfrequency calculation
            % end time calculation
            obj.whisker.var_fs = obj.samplingfrequency/groupwindow;
            obj.whisker.var_taxis = linspace(0, size(gpvar_whisker,3)/obj.whisker.var_fs,size(gpvar_whisker,3));
            obj.whisker.gpvar_whisker = gpvar_whisker;
            obj.whisker.depricated_frames = group_depricatedframe;
        end
    end
end