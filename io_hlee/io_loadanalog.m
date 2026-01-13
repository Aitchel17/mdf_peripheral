function analog = io_loadanalog(analogtxt_directory)
    % Input: analog.txt file directory
        % header, each info struct field, and data field is seperated as a line
        % Hence at the 2025.08.19 point, the .txt file structure is
        % Header: 2 lines, Info struct: 9 lines, and n lines for each n channels of analog channel
    % Output: analog struct
    % This function read analog.txt file generated from mdfExtracter with two headers
    % 1. header start from --- Analog Info
    % 1.1 info struct reconstruct from ':' as deliminator and left side as field name right side as value
    % 2. data start from --- Analog Data
    % 2.1 data struct reconstruct from ':' as deliminator
    % Open the file
            fileid = fopen(analogtxt_directory, 'r');
            if fileid == -1
                error('Could not open the file.');
            end
        
            % Initialize output structs
            analog = struct();
            analog.info = struct();
            analog.data = struct();
            
            % Read header information
            section = 'header'; % Track which section we are in
            % wait bar
            while ~feof(fileid)
                line = strtrim(fgetl(fileid)); % Read line and trim whitespace
                
                % Check for section headers
                if contains(line, '--- Analog Info')
                    section = 'header';
                    continue;
                elseif contains(line, '--- Analog Data')
                    section = 'data';
                    continue;
                end
        
                % Process header info
                if strcmp(section, 'header') && contains(line, ':')
                    disp('Analog info loading')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1}); 
                    value = strtrim(tokens{2});
                    % Store in info struct
                    analog.info.(key) = value;
                end
        
                % Process data section
                if strcmp(section, 'data') && contains(line, ':')
                    disp('Analog data loading')
                    tokens = split(line, ':'); % Split by colon
                    key = strtrim(tokens{1}); 
                    value = strtrim(tokens{2});
                    % Convert to numeric array
                    value = str2num(value); %#ok<ST2NM> 
                    % Store in analog data struct
                    analog.data.(key) = value;
                end
            end

            % Close the file
            fclose(fileid);

        end