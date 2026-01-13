function channelData = io_loadtiff(tiff_directory)
% this function load tiff file from directory
% 1. load info to determine demension and class for preallocation of empty stack
% 2. Create tiff object
% 3. Read specific slice by changing state of tiffobject
            tic
            % 1.1 load info
            info = imfinfo(tiff_directory);
            numFrames = numel(info);
            switch info(1).BitDepth
                case 16, dataClass = 'uint16';
                case 8, dataClass = 'uint8';
                otherwise, error('Unsupported BitDepth: %d', info(1).BitDepth);
            end
            % 1.2. Preallocate data
            channelData = zeros(info(1).Height, info(1).Width, numFrames, dataClass);
            % 2. Create tiff object
            tiffObj = Tiff(tiff_directory, 'r');
            cleanup = onCleanup(@() tiffObj.close());
            % wait bar
            h = waitbar(0, sprintf('Loading %s...', namingpattern));
            for idx = 1:numFrames
                setDirectory(tiffObj, idx);
                channelData(:,:,idx) = read(tiffObj);
                if mod(idx, 50) == 0 || idx == numFrames
                    waitbar(idx/numFrames, h);
                end
            end
            close(h);
            toc
end
    