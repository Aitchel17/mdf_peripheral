classdef sleepscoring_gui < handle
    %SLEEPSCORING_GUI Interactive manual sleep scoring for analog data
    %   Class-based implementation of the manual scoring GUI.
    %   Ports all logic from CreateTrainingDataSet_SleepAnalog.m.
    %   Polls globals buttonState, ButtonValue, closeButtonState to interact with SelectSleepState_GUI.

    properties (Access = public)
        Data
        State

    end

    properties (Hidden)
        Axes
        figHandle
        GUI
        stateMap % Map for fast lookup code -> index in StateDefs
        SpecData % Hidden property for heavy spectrogram data

    end

    properties (Access = private)
        monitor_pos = [3 1 17 9]; % change figure size and position in monitor (inch) [LeftRight UpDown Width Height]
        % Colors
        blue      = [0.00 0.45 0.90];
        red       = [0.85 0.10 0.10];
        black     = [0.10 0.10 0.10];
        orange    = [0.93 0.49 0.19];
        purple    = [0.50 0.10 0.70];
        purpleBlu = [0.35 0.45 0.95];
        green     = [0.20 0.65 0.20];
        cyan      = [0.00 0.70 0.85];
        white     = [1 1 1];
        StateDefs
    end

    properties (Constant)
        % Numeric State Codes (Kept for backward compat / fast access if needed, but discouraged)
        StateCodes = struct('Unscored', 0, 'NotSleep', 1, 'NREM', 2, 'REM', 3, 'Drowsy', 4 ,'uarousal',5);
    end

    events
        ScoringComplete
    end

    methods
        function obj = sleepscoring_gui(session_duration, binWidth_s)
            %SLEEPSCORING_GUI Construct an instance of the class
            if nargin < 3 || isempty(binWidth_s)
                binWidth_s = 5; % default
            end

            if session_duration == -1 || binWidth_s == -1
                disp('sleepscoring_gui loading...')
            end


            % Initialize Data
            NBins = floor(session_duration / binWidth_s);
            obj.Data.NBins = NBins;
            obj.Data.binWidth_s = binWidth_s;
            obj.Data.allDur_s = session_duration;

            % Initialize State
            obj.State.behavioralState = zeros(NBins, 1); % Numeric 0
            obj.State.currentBinIdx = 1;
            obj.State.binsToScore = 1:NBins;
            obj.State.windows = [];

            % Initialize Centralized State Definitions
            % Order matters for UI Button Grid (Row major: 1,2, 3,4...) if 2 columns
            % Name: Display Name
            % Code: Numeric Code
            % Color: RGB
            % Keys: Key shortcuts (cell of strings)
            % Field: Result struct field name
            obj.StateDefs = [
                struct('Name','Awake',  'Code',1, 'Color',obj.black, 'Keys',{{'a','1'}}, 'Field','AwakeTimes'), ...
                struct('Name','Drowsy',     'Code',4, 'Color',obj.green, 'Keys',{{'d','2'}}, 'Field','DrowsyTimes'), ...
                struct('Name','NREM Sleep', 'Code',2, 'Color',obj.blue,  'Keys',{{'n','3'}}, 'Field','NREMTimes'), ...
                struct('Name','REM Sleep',  'Code',3, 'Color',obj.red,   'Keys',{{'r','4'}}, 'Field','REMTimes'),...
                struct('Name','Micro Arousal',  'Code',5, 'Color',obj.orange,   'Keys',{{'m','5'}}, 'Field','uArousalTimes')
                ];

            % Map for lookup
            obj.stateMap = dictionary([obj.StateDefs.Code], 1:length(obj.StateDefs));
        end

        function setup_figure(obj, figStruct)
            % Create main figure and layout axes
            obj.figHandle = figure('Name', 'Sleep Scoring GUI', ...
                'Color', 'w', 'Units', 'inches', ...
                'Position', obj.monitor_pos, ...
                'KeyPressFcn', @obj.key_press_handler, ...
                'CloseRequestFcn', @obj.close_request_handler);

            pan(obj.figHandle,'off');
            z = zoom(obj.figHandle);
            z.Motion = 'horizontal';
            z.Enable = 'on';

            % Helper to copy axis
            function axNew = copyAndPos(figObj, subplotIdx)
                if isempty(figObj) || isempty(figObj.ax) || ~isvalid(figObj.ax)
                    axNew = subplot(8, 1, subplotIdx, 'Parent', obj.figHandle);
                    text(axNew, 0.5, 0.5, 'Data unavailable', 'HorizontalAlignment','center');
                    return;
                end
                dummy = subplot(8, 1, subplotIdx, 'Parent', obj.figHandle);
                pos = get(dummy, 'Position');
                delete(dummy);
                axNew = copyobj(figObj.ax, obj.figHandle);
                set(axNew, 'Position', pos);
            end

            obj.Axes.force           = copyAndPos(figStruct.force, 1);
            obj.Axes.emg_power     = copyAndPos(figStruct.emg_power, 2);
            obj.Axes.rawemg          = copyAndPos(figStruct.rawemg, 3);
            obj.Axes.whisker         = copyAndPos(figStruct.whisker, 4);
            obj.Axes.pupil           = copyAndPos(figStruct.pupil, 5);
            obj.Axes.spectrogram     = copyAndPos(figStruct.spectrogram, 6:8);

            % Link axes (Include Spectrogram again for virtual cropping)
            linkaxes([obj.Axes.force, obj.Axes.emg_power, obj.Axes.rawemg, ...
                obj.Axes.whisker, obj.Axes.pupil, obj.Axes.spectrogram], 'x');

            % --- Spectrogram Virtual Cropping (Performance) ---
            % Find the graphic object (Image or Surface)
            hSpec = findobj(obj.Axes.spectrogram, 'Type', 'image');
            if isempty(hSpec)
                hSpec = findobj(obj.Axes.spectrogram, 'Type', 'surface');
            end

            if ~isempty(hSpec)
                % Store Full Data Reference in Hidden Property
                obj.SpecData.CData = hSpec.CData;
                obj.SpecData.XData = hSpec.XData;
                obj.SpecData.YData = hSpec.YData;
                if isprop(hSpec, 'ZData')
                    obj.SpecData.ZData = hSpec.ZData;
                end
                obj.SpecData.Handle = hSpec;

                % Setup Listener on Master Axis (Force) XLim
                % Use 'PostSet' to update after limits change
                addlistener(obj.Axes.force, 'XLim', 'PostSet', @(~,~) obj.update_spectrogram_crop());

                % Initial Crop
                obj.update_spectrogram_crop();
            end

            % Scoring axes references
            obj.Axes.scoring_emg = obj.Axes.emg_power;
            obj.Axes.scoring_spec = obj.Axes.spectrogram;

            % Pre-allocate markers for performance
            obj.GUI.hMarker1 = xline(obj.Axes.scoring_emg, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker2 = xline(obj.Axes.scoring_emg, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker3 = xline(obj.Axes.scoring_spec, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker4 = xline(obj.Axes.scoring_spec, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');

            % Update full visualization on load
            obj.update_state_visualization(0, obj.Data.allDur_s);
        end

        function setup_control_panel(obj)
            % Re-implement createControlPanel logic using uifigure/uigridlayout
            % Incorporates Sleep State buttons directly.

            % Window Size
            WindowSize = [500, 400]; % Increased height for scalable layout

            % Determine Position (Top-Right of Main Figure)
            if ~isempty(obj.figHandle) && isvalid(obj.figHandle)
                % Get main figure position in pixels
                currUnits = obj.figHandle.Units;
                obj.figHandle.Units = 'pixels';
                mainPos = obj.figHandle.Position; % [x y w h]
                obj.figHandle.Units = currUnits;

                % Calculate position (aligned to top-right with padding)
                padding = 50;
                LeftEdge = mainPos(1) + mainPos(3) - WindowSize(1) - padding;
                BottomEdge = mainPos(2) + mainPos(4) - WindowSize(2) - padding;
            else
                % Fallback: Center on screen
                ScreenSize = get(0, 'ScreenSize');
                LeftEdge = (ScreenSize(3) - WindowSize(1)) / 2;
                BottomEdge = (ScreenSize(4) - WindowSize(2)) / 2;
            end

            % Create UI Figure
            obj.GUI.cpFig = uifigure('Name', 'Scoring Controls', ...
                'Position', [LeftEdge, BottomEdge, WindowSize], ...
                'Resize', 'on', ...
                'WindowKeyPressFcn', @obj.key_press_handler, ...
                'CloseRequestFcn', @(~,~) obj.close_request_handler());

            % Main Layout: 2 Rows (State Selection, Tools)
            MainLayout = uigridlayout(obj.GUI.cpFig, [2,1]);
            MainLayout.RowHeight = {'3x', '2x'};
            MainLayout.Padding = [10 10 10 10];
            MainLayout.RowSpacing = 10;

            % --- Panel 1: Sleep State Selection ---
            StatePanel = uipanel(MainLayout, 'Title', 'Sleep State');
            StatePanel.Layout.Row = 1;

            % Dynamic Grid Layout
            numStates = length(obj.StateDefs);
            nCols = 2;
            nRows = ceil(numStates / nCols);

            StateLayout = uigridlayout(StatePanel, [nRows, nCols]);
            StateLayout.ColumnWidth = repmat({'1x'}, 1, nCols);
            StateLayout.RowHeight = repmat({'1x'}, 1, nRows);
            StateLayout.Padding = [5 5 5 5];

            % Generate Buttons from StateDefs
            for i = 1:numStates
                def = obj.StateDefs(i);

                % Create Button Text (e.g., "Not Sleep (A)")
                % Use first key as shortcut hint if available
                if ~isempty(def.Keys)
                    shortcut = upper(def.Keys{1}); % Access the first key in the cell array
                    btnText = sprintf('%s (%s)', def.Name, shortcut);
                else
                    btnText = def.Name;
                end

                % Callback: trigger by Name
                cmd = def.Name;

                btn = uibutton(StateLayout, 'Text', btnText, ...
                    'BackgroundColor', def.Color, 'FontColor', obj.white, ...
                    'FontWeight', 'bold', 'FontSize', 14, ...
                    'ButtonPushedFcn', @(~,~) obj.handle_event('Button', cmd));

                % Position (Row-Major)
                rowIdx = ceil(i / nCols);
                colIdx = mod(i-1, nCols) + 1;
                btn.Layout.Row = rowIdx;
                btn.Layout.Column = colIdx;
            end

            % --- Panel 2: Tools & Navigation ---
            ToolsPanel = uipanel(MainLayout, 'Title', 'Tools & Nav');
            ToolsPanel.Layout.Row = 2;
            ToolsLayout = uigridlayout(ToolsPanel, [2,2]); % 3x3 Grid
            ToolsLayout.RowHeight = {'1x', '1x'};
            ToolsLayout.ColumnWidth = {'1x', '1x'};
            ToolsLayout.Padding = [5 5 5 5];

            % Tools Configuration
            % {Action, Color, Tag}
            btnConfig = {
                'Finish window', obj.orange, 'finishwin';
                'View remainder', obj.black, 'view';
                'Bulk label (plot)', obj.green, 'bulk_plot';
                'Jump in plot', obj.purple, 'jump_plot';
                };

            for i = 1:size(btnConfig,1)
                actionStr = btnConfig{i,3};
                callback = @(src,event)obj.handle_event('Button', actionStr);
                % Create Button
                btn = uibutton(ToolsLayout, ...
                    'Text', btnConfig{i,1}, ...
                    'FontWeight', 'bold', ...
                    'FontColor', obj.white, ...
                    'BackgroundColor', btnConfig{i,2}, ...
                    'ButtonPushedFcn', callback);

                % Position logic matches simple grid fill
                rowIdx = ceil(i/2);
                colIdx = mod(i-1, 2) + 1;
                btn.Layout.Row = rowIdx;
                btn.Layout.Column = colIdx;
            end
        end
    end

    % --- Helper Methods ---
    methods
        function goto_bin(obj, binIdx)
            if binIdx < 1 || binIdx > obj.Data.NBins
                return;
            end

            obj.State.currentBinIdx = binIdx;

            % Time range
            xStart = (binIdx-1)*obj.Data.binWidth_s;
            xEnd   = binIdx*obj.Data.binWidth_s;

            % Markers (Purple)
            obj.draw_bin_markers(xStart, xEnd);

            % View Window (simple generic window logic from original)
            winLen = (obj.Data.binWidth_s==5)*500 + (obj.Data.binWidth_s~=5)*300;
            winIdx = ceil(binIdx / max(1, round(winLen/obj.Data.binWidth_s)));
            x1 = (winIdx-1)*winLen;
            x2 = min(obj.Data.allDur_s, x1+winLen);

            xlim(obj.Axes.scoring_emg,[x1 x2]);
            xlim(obj.Axes.scoring_spec,[x1 x2]); % Manually update unlinked axis

            % Update state visualization on Force axis
            obj.update_state_visualization(x1, x2);

        end

        function draw_bin_markers(obj, xStart, xEnd)
            % Fast update using stored handles
            if isfield(obj.GUI, 'hMarker1') && isvalid(obj.GUI.hMarker1)
                obj.GUI.hMarker1.Value = xStart;
                obj.GUI.hMarker2.Value = xEnd;
                obj.GUI.hMarker3.Value = xStart;
                obj.GUI.hMarker4.Value = xEnd;
            else
                % Fallback: Re-create if deleted
                obj.GUI.hMarker1 = xline(obj.Axes.scoring_emg, xStart,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
                obj.GUI.hMarker2 = xline(obj.Axes.scoring_emg, xEnd,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
                obj.GUI.hMarker3 = xline(obj.Axes.scoring_spec, xStart,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
                obj.GUI.hMarker4 = xline(obj.Axes.scoring_spec, xEnd,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            end
        end

        function panel_action(obj, action)
            % Legacy wrapper to maintain compatibility if called externally, routes to handle_event
            obj.handle_event('Button', action);
        end



        function score_current_bin(obj, labelCode)
            obj.State.behavioralState(obj.State.currentBinIdx) = labelCode;
            obj.advance_bin(1);
        end

        function advance_bin(obj, step)
            newIdx = obj.State.currentBinIdx + step;
            if newIdx >= 1 && newIdx <= obj.Data.NBins
                obj.goto_bin(newIdx);
            else
                disp('End of file reached.');
            end
        end

        % --- Interaction Helpers ---
        function [jumpBi, betweenIdx] = pick_jump_plot(obj)
            figure(obj.figHandle);
            [t,~,~] = ginput(1);
            if isempty(t)
                jumpBi = [];
                betweenIdx=[];
                return;
            end
            t = max(0, min(t, obj.Data.allDur_s));
            targetBin = max(1, ceil(t / obj.Data.binWidth_s));
            jumpBi = targetBin;
            betweenIdx = []; % Logic simplified
        end



        function [ok, selLabel, s, e] = bulk_label_plot_dialog(obj)
            ok = false; selLabel = ''; s = []; e = [];

            % Generate List
            names = {obj.StateDefs.Name};
            codes = [obj.StateDefs.Code];

            [indx, tf] = listdlg('PromptString','Choose label:', ...
                'SelectionMode','single', ...
                'ListString', names, ...
                'InitialValue',1,'ListSize',[180 90]);
            if ~tf
                return;
            end

            selLabel = codes(indx);

            figure(obj.figHandle);
            [x1,~,~] = ginput(1); if isempty(x1), return; end
            [x2,~,~] = ginput(1); if isempty(x2), return; end
            s = min(x1,x2); e = max(x1,x2);
            ok = true;
        end

        function [ok, selLabel, s, e] = bulk_label_time_dialog(obj)
            % Impl similar to plot dialog but with inputdlg
            ok = false;
            selLabel = '';
            s = [];
            e = [];

            % Generate List
            names = {obj.StateDefs.Name};
            codes = [obj.StateDefs.Code];

            [indx, tf] = listdlg('PromptString','Choose label:', ...
                'SelectionMode','single', ...
                'ListString', names, ...
                'InitialValue',1,'ListSize',[180 90]);
            if ~tf
                return;
            end

            selLabel = codes(indx);

            answ = inputdlg({'Start time (s):','End time (s):'}, ...
                'Bulk label (time)',[1 28], {'0', num2str(obj.Data.allDur_s)});
            if isempty(answ), return; end
            s = str2double(answ{1}); e = str2double(answ{2});
            ok = true;
        end

        function [bStart, bEnd] = apply_bulk_label(obj, s, e, label, onlyIfEmpty)
            if nargin < 5, onlyIfEmpty = false; end

            bStart = max(1, floor(s / obj.Data.binWidth_s)+1);
            bEnd   = min(obj.Data.NBins, ceil(e / obj.Data.binWidth_s));

            for b = bStart:bEnd
                % Check if empty (0)
                if ~onlyIfEmpty || obj.State.behavioralState(b) == 0
                    obj.State.behavioralState(b) = label;
                end
            end
            disp(['Bulk labeled ' num2str(bStart) ':' num2str(bEnd) ' as ' label]);
        end

        function mark_bulk_region(obj, s, e)
            % Draw semi-transparent patch
            % (Simplified port: just draw on EMG and Spec)
            c4 = [0.1 0.7 0.9];

            ax = obj.Axes.scoring_emg;
            yl = get(ax,'YLim');
            patch(ax, [s e e s], [yl(1) yl(1) yl(2) yl(2)], c4, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'Tag', 'BulkLabelRegion');

            ax = obj.Axes.scoring_spec;
            yl = get(ax,'YLim');
            patch(ax, [s e e s], [yl(1) yl(1) yl(2) yl(2)], c4, 'FaceAlpha', 0.12, 'EdgeColor', 'none', 'Tag', 'BulkLabelRegion');
        end

        function enable_click_zoom(obj, turnOn)
            if turnOn
                set(obj.figHandle, 'WindowButtonDownFcn', @obj.click_zoom_handler_cb);
            else
                set(obj.figHandle, 'WindowButtonDownFcn', '');
                zoom(obj.figHandle, 'on');
            end
        end

        function click_zoom_handler_cb(obj, ~, ~)
            % Logic to zoom into point
            cp = get(gca, 'CurrentPoint'); cx = cp(1,1);
            % Zoom logic (simple center)
            w = 500;
            x1 = max(0, cx-w/2); x2 = min(obj.Data.allDur_s, cx+w/2);
            xlim(obj.Axes.scoring_emg, [x1 x2]);
        end


        function update_spectrogram_crop(obj)
            % Virtual Cropping Callback
            try
                if isempty(obj.SpecData) || isempty(obj.SpecData.Handle) || ~isvalid(obj.SpecData.Handle)
                    return;
                end

                % Get current view limits
                xl = xlim(obj.Axes.force);
                xStart = xl(1); xEnd = xl(2);

                % Filter Data
                % Assuming XData is a vector (imagesc/pcolor usually)
                fullX = obj.SpecData.XData;

                % Optimization: buffer to prevent jitter
                buffer = (xEnd - xStart) * 0.1;
                xStartB = xStart - buffer;
                xEndB   = xEnd + buffer;

                % Find indices
                if isvector(fullX)
                    mask = fullX >= xStartB & fullX <= xEndB;
                    if ~any(mask)
                        % fallback if zoomed way out or empty
                        return;
                    end
                    % Extract Slice
                    newX = fullX(mask);
                    fullC = obj.SpecData.CData;
                    if size(fullC, 2) == length(fullX)
                        newC = fullC(:, mask);
                        if isfield(obj.SpecData, 'ZData') && ~isempty(obj.SpecData.ZData)
                            newZ = obj.SpecData.ZData(:, mask);
                            set(obj.SpecData.Handle, 'XData', newX, 'CData', newC, 'ZData', newZ);
                        else
                            set(obj.SpecData.Handle, 'XData', newX, 'CData', newC);
                        end
                    elseif size(fullC, 1) == length(fullX)
                        newC = fullC(mask, :);
                        if isfield(obj.SpecData, 'ZData') && ~isempty(obj.SpecData.ZData)
                            newZ = obj.SpecData.ZData(mask, :);
                            set(obj.SpecData.Handle, 'XData', newX, 'CData', newC, 'ZData', newZ);
                        else
                            set(obj.SpecData.Handle, 'XData', newX, 'CData', newC);
                        end
                    else
                        % Dimension mismatch or different structure
                        return;
                    end
                end
            catch
                % suppress errors during close
            end
        end

        function update_state_visualization(obj, xStart, xEnd)
            % Draw colored patches for sleep states on Force axis
            ax = obj.Axes.force;
            % Determine bin range
            bStart = max(1, floor(xStart / obj.Data.binWidth_s) + 1);
            bEnd   = min(obj.Data.NBins, ceil(xEnd / obj.Data.binWidth_s));
            yl = get(ax, 'YLim');
            yLow = yl(1); yHigh = yl(2);
            countUpdated = 0;
            countCreated = 0;

            hold(ax, 'on');
            for b = bStart:bEnd
                state = obj.State.behavioralState(b);
                % Determine color (Dynamic Lookup)
                c = 'none';
                if state ~= 0 % 0 is Unscored/None
                    % Find matching def
                    % Optimization: Use stateMap if available, else Linear Search
                    if isfield(obj.stateMap, 'entries') % if it's a dictionary (R2022b+)
                        if isKey(obj.stateMap, state)
                            idx = obj.stateMap(state);
                            c = obj.StateDefs(idx).Color;
                        end
                    else
                        % Fallback / Linear Search
                        for i = 1:length(obj.StateDefs)
                            if obj.StateDefs(i).Code == state
                                c = obj.StateDefs(i).Color;
                                break;
                            end
                        end
                    end
                end

                % Retrieve persistent handle
                % Check if GUI struct has BinPatches (safeguard for hot-reload)
                if ~isfield(obj.GUI, 'BinPatches') || length(obj.GUI.BinPatches) < obj.Data.NBins
                    obj.GUI.BinPatches = gobjects(obj.Data.NBins, 1);
                end

                hPatch = obj.GUI.BinPatches(b);

                if isgraphics(hPatch) && isvalid(hPatch)
                    % Patch exists: update if needed
                    if strcmp(c, 'none')
                        set(hPatch, 'Visible', 'off');
                    else
                        set(hPatch, 'Visible', 'on', 'FaceColor', c, 'YData', [yLow yLow yHigh yHigh]);
                        countUpdated = countUpdated + 1;
                    end
                else
                    % Patch doesn't exist: create if visible
                    if ~strcmp(c, 'none')
                        t1 = (b-1) * obj.Data.binWidth_s;
                        t2 = b * obj.Data.binWidth_s;

                        % Create new patch
                        obj.GUI.BinPatches(b) = patch(ax, [t1 t2 t2 t1], [yLow yLow yHigh yHigh], c, ...
                            'FaceAlpha', 0.4, 'EdgeColor', 'none', 'Tag', 'StatePatch', 'HitTest', 'off');
                        countCreated = countCreated + 1;
                    end
                end
            end
            if countUpdated > 0 || countCreated > 0
                fprintf('Viz: Updated %d, Created %d patches.\n', countUpdated, countCreated);
            end
        end

        function save_figure(obj, filename, save_dir)
            % SAVE_FIGURE Export the full scored session as a high-res PNG and FIG
            arguments
                obj
                filename (1,:) char
                save_dir (1,:) char
            end

            % Ensure directory exists
            if ~exist(save_dir, 'dir')
                mkdir(save_dir);
            end

            % Store current view
            ax = obj.Axes.force;
            currentXLim = xlim(ax);

            try
                % Zoom out to full duration
                obj.enable_click_zoom(false); % Disable click zoom temporarily to avoid errors?
                xlim(ax, [0, obj.Data.allDur_s]);

                % Force update of state patches for the whole duration
                obj.update_state_visualization(0, obj.Data.allDur_s);

                % Ensure everything is rendered
                drawnow;

                % Export PNG
                pngPath = fullfile(save_dir, [filename '.png']);
                figPath = fullfile(save_dir, [filename '.fig']);

                fprintf('Exporting high-res figure to %s ...\n', pngPath);
                exportgraphics(obj.figHandle, pngPath, 'Resolution', 600);

                % Export FIG
                fprintf('Saving MATLAB figure to %s ...\n', figPath);
                savefig(obj.figHandle, figPath);
                fprintf('Export complete.\n');

            catch ME
                warning('Export failed: %s', ME.message);
            end

            % Restore previous view
            xlim(ax, currentXLim);
            obj.enable_click_zoom(true); % Re-enable if it was on
        end

        function results = get_results(obj, filename,savePath)
            % Create table with numeric state and string representation
            numericState = obj.State.behavioralState;

            % Create result struct
            results.behavState = numericState;
            % Calculate start/end times for each state
            binWidth = obj.Data.binWidth_s;
            % Generate time bounds
            % Helper to get [Start, End] for a given code
            function times = get_state_times(code)
                binIndices = find(numericState == code);
                if isempty(binIndices)
                    times = double.empty(0, 2);
                else
                    s = (binIndices - 1) * binWidth;
                    e = binIndices * binWidth;
                    times = [s, e];
                end
            end

            % Dynamic Results Generation
            for i = 1:length(obj.StateDefs)
                def = obj.StateDefs(i);
                if ~isempty(def.Field)
                    results.(def.Field) = get_state_times(def.Code);
                end
            end
            % Keep Unscored manually if not in StateDefs (often not needed in output, but good for completeness)
            results.UnscoredTimes = get_state_times(0);
            results.total_duration = obj.Data.allDur_s;
            results.binwidth_sec = obj.Data.binWidth_s;
            results.statecodes = obj.StateCodes;
            % Save if path provided
            save(fullfile(savePath, strcat(filename,'.mat')), '-struct', 'results');
            fprintf('Results saved to %s\n', savePath);
        end

        function gui = saveobj(obj)
            % Saves the lightweight session state (Data, State, Defs)
            % Excludes heavy Spectrogram data (handled via SpecData property)
            gui.Data = obj.Data;
            gui.State = obj.State;
        end
    end
    % Methods for events
    methods (Access = private)

        function key_press_handler(obj, ~, event)
            obj.handle_event('Key', event.Key);
        end

        function close_request_handler(obj, ~, ~)
            % Clean up
            try delete(obj.GUI.cpFig);
            catch
                set(gcf, 'CloseRequestFcn', 'closereq'); close(gcf)
            end
            try delete(obj.figHandle);
            catch
                set(gcf, 'CloseRequestFcn', 'closereq'); close(gcf)
            end

            fprintf('Scoring session closed.\n');
            notify(obj, 'ScoringComplete');
        end

        function handle_event(obj, source, eventData)
            % Centralized event handler (Private)

            % Normalize actions
            action = '';

            % Dynamic Lookup in StateDefs
            if strcmp(source, 'Key')
                % check navigation keys first
                switch eventData
                    case {'k', 'rightarrow'}, action = 'next_bin';
                    case {'j', 'leftarrow'}, action = 'prev_bin';
                    otherwise
                        % Check State Keys
                        for i = 1:length(obj.StateDefs)
                            if ismember(eventData, obj.StateDefs(i).Keys)
                                action = obj.StateDefs(i).Code;
                                break;
                            end
                        end
                end
            elseif strcmp(source, 'Button')
                % Check if eventData (Command) matches a State Name
                found = false;
                for i = 1:length(obj.StateDefs)
                    if strcmp(eventData, obj.StateDefs(i).Name)
                        action = obj.StateDefs(i).Code;
                        found = true;
                        break;
                    end
                end

                if ~found
                    % Pass through other commands (next_bin, etc.)
                    action = eventData;
                end
            end

            if isempty(action)
                return;
            end

            % Dispatch
            if isnumeric(action)
                obj.score_current_bin(action);
            else
                switch action
                    % Navigation
                    case 'next_bin'
                        obj.advance_bin(1);
                    case 'prev_bin'
                        obj.advance_bin(-1);
                    case 'view'
                        disp('show overview')
                        % View remainder logic
                        pan(obj.figHandle,'off');
                        zoom(obj.figHandle,'off');

                        xlim(obj.Axes.force,[0 obj.Data.allDur_s]);
                        drawnow; % Ensure limits are updated
                        % Show patches
                        obj.enable_click_zoom(true);

                    case 'jump_plot'
                        [targetBi, betIdx] = obj.pick_jump_plot();
                        if ~isempty(targetBi)
                            if targetBi > obj.State.currentBinIdx
                                % obj.fill_empty_bins(betIdx);
                            end
                            obj.goto_bin(targetBi);
                        end
                    case 'bulk_plot'
                        [ok, lab, s, e] = obj.bulk_label_plot_dialog();
                        if ok
                            [~, bEnd] = obj.apply_bulk_label(s, e, lab);
                            obj.mark_bulk_region(s, e);
                            obj.goto_bin(bEnd + 1);
                        end
                    case 'finishwin'
                        xl = get(obj.Axes.scoring_emg, 'XLim');
                        sW = max(0,xl(1)); eW=min(obj.Data.allDur_s, xl(2));
                        [~, bEnd] = obj.apply_bulk_label(sW, eW, obj.StateCodes.NotSleep, true);

                        obj.goto_bin(bEnd + 1);
                end
            end
        end
    end

    methods (Static)
        function obj = loadobj(s)
            obj = sleepscoring_gui(-1, -1);
            obj.Data = s.Data;
            obj.State = s.State;

        end
    end
end