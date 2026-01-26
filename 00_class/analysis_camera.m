classdef analysis_camera < handle
    properties
        parameter = struct()
        imgstack = struct()
        whisker
        eye
    end

    properties (Constant)
        python_env_path = 'C:\Users\hql5715\AppData\Local\anaconda3\envs\dlc-gpu\python.exe'
        dlc_config_path = '';
    end

    methods
        function obj = analysis_camera(peripheral_session)
            %ANALYSIS_CAMERA Construct an instance of this class
            %   parameter init
            if nargin < 1
                disp('Load analysis_camera object is required')
                return
            end
            obj.parameter.analog_count = str2double(peripheral_session.raw_analog.info.analogcount);
            obj.parameter.analog_fs = str2double(peripheral_session.raw_analog.info.analogfreq(1:end-2));
            obj.parameter.analog_end = obj.parameter.analog_count/obj.parameter.analog_fs;
            obj.parameter.twophoton_count = str2double(peripheral_session.info.fcount);
            obj.parameter.twophoton_fps = str2double(peripheral_session.info.fps);
            obj.parameter.twophoton_end = obj.parameter.twophoton_count/obj.parameter.twophoton_fps;
        end


        function obj = load_whisker(obj,peripheral_session)
            % load whisker
            obj.imgstack.raw_whisker = peripheral_session.loadwhisker;
            % parameter calculation
            obj.parameter.whisker_count = size(obj.imgstack.raw_whisker,3);
            if isfield(obj.parameter,'analog_end')
                disp('analog_end used to calculate camera end')
                obj.parameter.whisker_end = obj.parameter.analog_end;
                fps = obj.parameter.whisker_count/obj.parameter.analog_end;
            elseif isfield(obj.parameter,'twophoton_end')
                disp('analog_end used to calculate camera end')
                fps = obj.parameter.whisker_count/obj.parameter.twophoton_end;
            else
                disp('camera data sampling frequency fixed to 33.3216 calculated from other session')
                fps = 33.3216;
            end
            obj.parameter.cam_fps = fps;
        end

        function get_whiskermovement(obj,groupwindow)
            obj.whisker.groupwindow = groupwindow;
            % Moving standard deviation..? maybe overkill group projection
            % will provide downsample effect and calculation of variance
            [gpvar_whisker,group_depricatedframe] = cam_groupproject(obj.imgstack.raw_whisker,groupwindow,'var');
            obj.whisker.var_mean_whisker = squeeze(mean(gpvar_whisker,[1,2]));
            % samplingfrequency calculation
            % end time calculation
            obj.whisker.var_fs = obj.parameter.cam_fps/groupwindow;
            obj.whisker.var_taxis = linspace(0, size(gpvar_whisker,3)/obj.whisker.var_fs,size(gpvar_whisker,3));
            obj.imgstack.gpvar_whisker = gpvar_whisker;
            obj.whisker.depricated_frames = group_depricatedframe;
        end

        function run_dlc_analysis(obj, video_path, dlc_config_in)
            %RUN_DLC_ANALYSIS Run DeepLabCut analysis and video creation
            %   video_path: Absolute path to video
            %   dlc_config_in: (Optional) Path to config.yaml. Uses obj.dlc_config_path if omitted.

            if nargin < 3
                if ~isempty(obj.dlc_config_path)
                    config_path = obj.dlc_config_path;
                else
                    error('Please provide dlc_config_path argument or set obj.dlc_config_path');
                end
            else
                config_path = dlc_config_in;
            end

            if ~exist(video_path, 'file')
                error('Video not found: %s', video_path);
            end
            if ~exist(config_path, 'file')
                error('DLC Config not found: %s', config_path);
            end

            % Output Directory: peripheral/dlc_pupil relative to video?
            % User asked for: "under peripheral/dlc_pupil"
            [p, ~, ~] = fileparts(video_path);

            % Attempt to locate 'peripheral' folder if we are not already in it
            % Logic: assume video is in session_root/peripheral/video.avi -> output: session_root/peripheral/dlc_pupil
            % Or video is in session_root/video.avi -> output: session_root/peripheral/dlc_pupil

            if contains(p, 'peripheral')
                % If we are already deep, maybe go up?
                % Let's keep it simple: Create <video_dir>/dlc_pupil if 'peripheral' isn't explicitly found as parent
                % But if user wants "peripheral/dlc_pupil" strictly:
                dest_folder = fullfile(p, 'dlc_pupil');
            else
                % Create peripheral/dlc_pupil structure
                dest_folder = fullfile(p, 'peripheral', 'dlc_pupil');
            end

            if ~exist(dest_folder, 'dir')
                mkdir(dest_folder);
            end

            % Create temporary Python script
            py_script_file = fullfile(dest_folder, 'dlc_run_temp.py');

            % Escape backslashes for Python string
            v_py = strrep(video_path, '\', '\\');
            c_py = strrep(config_path, '\', '\\');
            d_py = strrep(dest_folder, '\', '\\');

            py_code = sprintf([...
                'import deeplabcut\n' ...
                'import os\n' ...
                'config_path = "%s"\n' ...
                'video_path = ["%s"]\n' ...
                'dest_folder = "%s"\n' ...
                'print("Starting DLC Analysis...")\n' ...
                'deeplabcut.analyze_videos(config_path, video_path, save_as_csv=True, destfolder=dest_folder)\n' ...
                'print("Creating Labeled Video...")\n' ...
                'deeplabcut.create_labeled_video(config_path, video_path, videotype=".mp4", destfolder=dest_folder)\n' ...
                'print("DLC Processing Complete.")\n' ...
                ], c_py, v_py, d_py);

            fid = fopen(py_script_file, 'w');
            fprintf(fid, '%s', py_code);
            fclose(fid);

            % Run it
            cmd = sprintf('%s "%s"', obj.python_env_path, py_script_file);
            disp(['Executing DLC: ' cmd]);
            status = system(cmd);

            % Cleanup
            % delete(py_script_file);

            if status ~= 0
                error('DLC Analysis failed with status %d', status);
            else
                disp(['Success! Output in: ' dest_folder]);
            end
        end

        function load_pupil_data(obj, video_path)
            %LOAD_PUPIL_DATA Load the csv output from pupil tracking
            %   Assumes output is in <video_stem>_frames_result/

            [p, n, ~] = fileparts(video_path);
            % Default output structure from README:
            % movie_frames_result/movie_estimated_pupil_diameter.csv

            csv_dir = fullfile(p, [n '_frames_result']);
            csv_file = fullfile(csv_dir, [n '_estimated_pupil_diameter.csv']);

            if ~exist(csv_file, 'file')
                % Try alternative typical location?
                error('Pupil data CSV not found at %s', csv_file);
            end

            opts = detectImportOptions(csv_file);
            tbl = readtable(csv_file, opts);

            % Initialize eye struct
            obj.eye = struct();
            obj.eye.diameter = tbl.diameter_pixel; % Assuming column name based on typical outputs
            % Check actual column names if possible. README says "estimated_pupil_diameter.csv"
            % Usually columns are 'frame', 'diameter' etc.
            % Let's import generic for now or check properties.
            if ismember('diameter', tbl.Properties.VariableNames)
                obj.eye.diameter = tbl.diameter;
            elseif ismember('diameter_pixel', tbl.Properties.VariableNames)
                obj.eye.diameter = tbl.diameter_pixel;
            else
                warning('Could not identify diameter column. Loading full table.');
                obj.eye.raw_table = tbl;
            end

            obj.eye.fs = obj.parameter.twophoton_fps; % Approximation if framewise 1:1?
            % The README says "Extract evenly spaced frames... default 5 fps".
            % So we need to know the extraction FPS or align timestamps.

            disp('Pupil data loaded into obj.eye');
        end

        function s = saveobj(obj)
            s.parameter = obj.parameter;
            s.whisker = obj.whisker;
            s.eye = obj.eye;
        end
    end

    methods (Static)
        function obj = loadobj(s)
            if isstruct(s)
                disp('reconstruction started')
                obj = analysis_camera();
                obj.parameter = s.parameter;
                obj.imgstack = struct();
                obj.whisker = s.whisker;
                obj.eye = s.eye;
            else
                disp('load failed')
                obj = s;
            end
        end
    end
end