classdef analysis_camera < handle
    properties
        parameter = struct()
        imgstack = struct()
        whisker
        eye
    end

    properties (Constant)
        python_env_path = 'C:\Users\hql5715\AppData\Local\anaconda3\envs\dlc-gpu\python.exe'
        pupil_python_env_path = 'C:\Users\hql5715\AppData\Local\anaconda3\envs\pupil_yzhao\python.exe'
        dlc_config_path = 'G:\dlc\pupil_resonant-hql5715-2026-01-16\config.yaml';
        unet_script_path = 'G:\03_program\04_yueunet_pupiltrack\run_pupil_analysis.py';
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

        function run_unet_analysis(obj, video_path, export_mask)
            arguments
                obj
                video_path (1,:) char
                export_mask (1,1) logical = false
            end

            if ~exist(video_path, 'file')
                error('Video not found: %s', video_path);
            end
            if ~exist(obj.unet_script_path, 'file')
                error('UNet Script not found: %s', obj.unet_script_path);
            end

            [p, ~, ~] = fileparts(video_path);

            % output folder
            dest_folder = fullfile(p, 'peripheral', 'u19unet_pupil');
            if ~exist(dest_folder, 'dir')
                mkdir(dest_folder);
            end

            % Temp frames folder
            frames_dir = fullfile(dest_folder, 'temp_frames');
            if ~exist(frames_dir, 'dir')
                mkdir(frames_dir);
            end

            % Construct command
            % We invoke python.exe directly on the script
            cmd = sprintf('"%s" "%s" --video_path "%s" --result_dir "%s" --out_dir "%s" 2>&1', ...
                obj.pupil_python_env_path, obj.unet_script_path, video_path, dest_folder, frames_dir);

            if export_mask
                mask_dir = fullfile(dest_folder, 'masks');
                if ~exist(mask_dir, 'dir')
                    mkdir(mask_dir);
                end
                cmd = [cmd, sprintf(' --output_mask_dir "%s"', mask_dir)];
            end

            disp(['Executing UNet Analysis: ' cmd]);

            % Execute
            status = system(cmd);

            if status ~= 0
                % Check if basic help works to debug environment?
                % system(sprintf('"%s" --version', obj.pupil_python_env_path));
                error('UNet Analysis failed with status %d. Check console output for Python errors.', status);
            else
                disp('UNet Analysis Execution Successful.');

                % Clean up frames
                if exist(frames_dir, 'dir')
                    disp(['Removing temporary frames in: ' frames_dir]);
                    try
                        rmdir(frames_dir, 's');
                    catch ME
                        warning('Could not remove temporary frames: %s', ME.message);
                    end
                end

                % Optional: Auto-load the data if successful?
                % obj.load_dlc_pupil(video_path); % We might need to adapt load_dlc_pupil or create load_unet_pupil
            end
        end

        function load_unet_pupil(obj, video_path)
            %LOAD_UNET_PUPIL Load the csv output from UNet pupil tracking
            %   Assumes output is in peripheral/u19unet_pupil/
            %   video_path: Absolute path to video file used for analysis

            if ~exist(video_path, 'file')
                error('Video not found: %s', video_path);
            end

            [p, n, ~] = fileparts(video_path);
            csv_dir = fullfile(p, 'peripheral', 'u19unet_pupil');
            csv_file = fullfile(csv_dir, [n '_estimated_pupil_diameter.csv']);

            if ~exist(csv_file, 'file')
                error('Pupil data CSV not found at %s', csv_file);
            end

            disp(['Loading pupil data from: ' csv_file]);
            opts = detectImportOptions(csv_file);
            tbl = readtable(csv_file, opts);

            % Initialize eye struct
            obj.eye = struct();
            %%

            %%

            % CSV columns: image_name, estimated_pupil_diameter
            if ismember('estimated_pupil_diameter', tbl.Properties.VariableNames)
                obj.eye.diameter = tbl.estimated_pupil_diameter;
            else
                warning('Could not identify "estimated_pupil_diameter" column. Loading full table.');
                obj.eye.diameter = [];
                obj.eye.raw_table = tbl;
            end

            % Sampling frequency
            % Default extraction FPS in run_pupil_analysis.py is 5 Hz
            obj.eye.pupil_fps = obj.parameter.cam_fps;

            if ~isempty(obj.eye.diameter)
                % Create time axis stretching from 0 to the calculated end time
                obj.eye.t_axis = linspace(0, obj.parameter.twophoton_end, length(obj.eye.diameter));
            end
            disp('Pupil data loaded into obj.eye');
        end

        function run_dlc_analysis(obj, video_path)
            %RUN_DLC_ANALYSIS Run DeepLabCut analysis and video creation
            %   video_path: Absolute path to video
            %   dlc_config_in: (Optional) Path to config.yaml. Uses obj.dlc_config_path if omitted.


            if ~exist(video_path, 'file')
                error('Video not found: %s', video_path);
            end
            if ~exist(obj.dlc_config_path, 'file')
                error('DLC Config not found: %s', obj.dlc_config_path);
            end


            [parents, ~, ~] = fileparts(video_path);
            dest_folder = fullfile(parents, 'peripheral', 'dlc_pupil');

            if ~exist(dest_folder, 'dir')
                mkdir(dest_folder);
            end

            % Create temporary Python script
            py_script_file = fullfile(dest_folder, 'dlc_run_temp.py');

            % Escape backslashes for Python string
            v_py = strrep(video_path, '\', '\\');
            c_py = strrep(obj.dlc_config_path, '\', '\\');
            d_py = strrep(dest_folder, '\', '\\');

            py_code = sprintf([...
                'import deeplabcut\n' ...
                'import os\n' ...
                'config_path = "%s"\n' ... % This part will be changed
                'video_path = ["%s"]\n' ... % This part will be changed
                'dest_folder = "%s"\n' ... %  This part will be changed
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

        function load_dlc_pupil(obj, video_path)
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

        function clean_pupil_outliers(obj, threshold)
            %CLEAN_PUPIL_OUTLIERS Replace outliers with NaN based on median filter
            %   threshold: deviation threshold (default 5)

            if nargin < 2
                threshold = 5;
            end

            if ~isfield(obj.eye, 'diameter') || isempty(obj.eye.diameter)
                warning('No pupil diameter data to clean.');
                return;
            end

            % Backup raw data if not already done
            if ~isfield(obj.eye, 'diameter_raw')
                obj.eye.diameter_raw = obj.eye.diameter;
            end

            data = obj.eye.diameter;

            % Median filtering for reference (window size 9 matches clean_outlier.m)
            % Using 'truncate' to handle edges similar to clean_outlier
            ref_median = medfilt1(data, 21, 'zeropad');
     
            diff_data = abs(data - ref_median);
            outlier_idx = diff_data > threshold;

            if any(outlier_idx)
                fprintf('Cleaning pupil data: %d outliers removed (Threshold: %.2f)\n', sum(outlier_idx), threshold);
                data(outlier_idx) = NaN;
                obj.eye.diameter = data;
            else
                fprintf('Cleaning pupil data: No outliers found (Threshold: %.2f)\n', threshold);
            end
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