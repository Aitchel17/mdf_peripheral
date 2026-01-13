classdef peripheral_mdf < mdfExtractLoader
    %PERIPHERAL_MDF Class for loading peripheral data (analog, eye, whisker)
    %   Inherits from mdfExtractLoader to handle peripheral signals and videos.

    properties
        eye
        whisker
        raw_analog
    end

    methods
        function obj = peripheral_mdf(mdfExtract_folderpath)
            %PERIPHERAL_MDF Construct an instance of this class
            %   mdfExtract_folderpath: Path to the mdfExtracted folder

            % Call superclass constructor
            if nargin == 0
                args = {};
            else
                args = {mdfExtract_folderpath};
            end
            obj@mdfExtractLoader(args{:});

            % info is already available as obj.info from superclass
        end

        function obj = loadraw_analogdata(obj)
            % Load analog data using inherited loadanalog method
            % Stores result in raw_analog
            try
                obj.raw_analog = obj.loadanalog();
            catch ME
                warning(ME.identifier, 'Failed to load analog data: %s', ME.message);
            end
        end

        function obj = loadbehavior(obj)
            % Load eye and whisker videos using io_loadavi
            % Note: io_loadavi must be in the path

            % Eye Video
            if isfield(obj.dir_struct, 'eye') && ~isempty(obj.dir_struct.eye)
                try
                    fprintf('Loading Eye Video: %s\n', obj.dir_struct.eye);
                    obj.eye = io_loadavi(obj.dir_struct.eye);
                catch ME
                    warning(ME.identifier, 'Failed to load Eye video: %s', ME.message);
                end
            end

            % Whisker Video
            if isfield(obj.dir_struct, 'whisker') && ~isempty(obj.dir_struct.whisker)
                try
                    fprintf('Loading Whisker Video: %s\n', obj.dir_struct.whisker);
                    obj.whisker = io_loadavi(obj.dir_struct.whisker);
                catch ME
                    warning(ME.identifier, 'Failed to load Whisker video: %s', ME.message);
                end
            end
        end
    end
end
