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
    end

    properties (Access = private)
        monitor_pos = [20 1 17 9];
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
    end

    properties (Constant)
        % Numeric State Codes
        StateCodes = struct('Unscored', 0, 'NotSleep', 1, 'NREM', 2, 'REM', 3);
        % Names for display/export (Indexed by Code+1)
        StateNames = {'Unscored', 'Not Sleep', 'NREM Sleep', 'REM Sleep'};
    end

    events
        ScoringComplete
    end

    methods
        function obj = sleepscoring_gui(session_duration, binWidth_s)
            %SLEEPSCORING_GUI Construct an instance of the class

            if nargin < 3 || isempty(binWidth_s)
                binWidth_s = 5;
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

            obj.Axes.force   = copyAndPos(figStruct.force, 1);
            obj.Axes.emg_power     = copyAndPos(figStruct.emg_power, 2);
            obj.Axes.rawemg  = copyAndPos(figStruct.rawemg, 3);
            obj.Axes.whisker = copyAndPos(figStruct.whisker, 4);

            if isfield(figStruct, 'pupil') && ~isempty(figStruct.pupil)
                obj.Axes.pupil = copyAndPos(figStruct.pupil, 5);
            else
                obj.Axes.pupil = subplot(8,1,5,'Parent',obj.figHandle);
                axis(obj.Axes.pupil, 'off');
                text(obj.Axes.pupil, 0.5, 0.5, 'Pupil not provided', 'HorizontalAlignment','center');
            end

            if isempty(figStruct.spectrogram) || isempty(figStruct.spectrogram.ax)
                obj.Axes.spectrogram = subplot(8, 1, 6:8, 'Parent', obj.figHandle);
                text(obj.Axes.spectrogram, 0.5, 0.5, 'Spectrogram unavailable', 'HorizontalAlignment','center');
            else
                dummy = subplot(8, 1, 6:8, 'Parent', obj.figHandle);
                pos = get(dummy, 'Position');
                delete(dummy);
                obj.Axes.spectrogram = copyobj(figStruct.spectrogram.ax, obj.figHandle);
                set(obj.Axes.spectrogram, 'Position', pos);
            end

            % Link axes
            linkaxes([obj.Axes.force, obj.Axes.emg_power, obj.Axes.rawemg, ...
                obj.Axes.whisker, obj.Axes.pupil, obj.Axes.spectrogram], 'x');

            % Scoring axes references
            obj.Axes.scoring_emg = obj.Axes.emg_power;
            obj.Axes.scoring_spec = obj.Axes.spectrogram;

            % Pre-allocate markers for performance
            obj.GUI.hMarker1 = xline(obj.Axes.scoring_emg, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker2 = xline(obj.Axes.scoring_emg, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker3 = xline(obj.Axes.scoring_spec, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            obj.GUI.hMarker4 = xline(obj.Axes.scoring_spec, -100,'-','Color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');

        end

        function setup_control_panel(obj)
            % Re-implement createControlPanel logic using uifigure/uigridlayout
            % Incorporates Sleep State buttons directly.

            % Window Size
            WindowSize = [500, 400]; % Increased height for better layout

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
            MainLayout.RowHeight = {100, '1x'};
            MainLayout.Padding = [10 10 10 10];
            MainLayout.RowSpacing = 10;

            % --- Panel 1: Sleep State Selection ---
            StatePanel = uipanel(MainLayout, 'Title', 'Sleep State');
            StatePanel.Layout.Row = 1;
            StateLayout = uigridlayout(StatePanel, [1,3]);
            StateLayout.ColumnWidth = {'1x', '1x', '1x'};
            StateLayout.Padding = [5 5 5 5];

            % State Buttons
            % Not Sleep (Black)
            uibutton(StateLayout, 'Text', 'Not Sleep (A)', ...
                'BackgroundColor', obj.black, 'FontColor', obj.white, ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) obj.handle_event('Button', 'Not Sleep'));

            % NREM Sleep (Blue)
            uibutton(StateLayout, 'Text', 'NREM Sleep (N)', ...
                'BackgroundColor', obj.blue, 'FontColor', obj.white, ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) obj.handle_event('Button', 'NREM Sleep'));

            % REM Sleep (Red)
            uibutton(StateLayout, 'Text', 'REM Sleep (R)', ...
                'BackgroundColor', obj.red, 'FontColor', obj.white, ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) obj.handle_event('Button', 'REM Sleep'));

            % --- Panel 2: Tools & Navigation ---
            ToolsPanel = uipanel(MainLayout, 'Title', 'Tools & Nav');
            ToolsPanel.Layout.Row = 2;
            ToolsLayout = uigridlayout(ToolsPanel, [3,3]); % 3x3 Grid
            ToolsLayout.RowHeight = {'1x', '1x', '1x'};
            ToolsLayout.ColumnWidth = {'1x', '1x', '1x'};
            ToolsLayout.Padding = [5 5 5 5];

            % Tools Configuration
            % {Action, Color, Tag}
            btnConfig = {
                'Continue', obj.blue, 'continue';
                'End here', obj.red, 'end';
                'Finish window', obj.orange, 'finishwin';
                'View remainder', obj.black, 'view';
                'Bulk label (plot)', obj.green, 'bulk_plot';
                'Bulk label (time)', obj.cyan, 'bulk_time';
                'Jump in plot', obj.purple, 'jump_plot';
                'Plot scores', obj.purpleBlu, 'plot_scores';
                'Jump in time', obj.purpleBlu, 'jump_time';
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
                rowIdx = ceil(i/3);
                colIdx = mod(i-1, 3) + 1;
                btn.Layout.Row = rowIdx;
                btn.Layout.Column = colIdx;
            end
        end

        function plot_scores_overview(obj)
            figure('Name', 'Sleep Score Overview');
            ax = axes();
            % Inline add_sleep_bands logic
            hold(ax, 'on');
            cNot=[0.8 0.8 0.8]; cNREM=[0.3 0.7 1]; cREM=[1 0.4 0.4];
            states = obj.State.behavioralState;
            edges = 0:obj.Data.binWidth_s:obj.Data.allDur_s;

            for i=1:numel(states)
                if states(i) == obj.StateCodes.Unscored, continue; end
                switch states(i)
                    case obj.StateCodes.NotSleep, c=cNot;
                    case obj.StateCodes.NREM, c=cNREM;
                    case obj.StateCodes.REM, c=cREM;
                    otherwise, c=[1 1 1];
                end
                t1 = edges(i); t2 = edges(i+1);
                patch(ax, [t1 t2 t2 t1], [0 0 1 1], c, 'EdgeColor','none');
            end
            title('Score Overview (Bands)');
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
            % xlim(obj.Axes.scoring_spec,[x1 x2]); % Linked

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
                % Maybe close?
            end
        end

        % --- Interaction Helpers ---
        function [jumpBi, betweenIdx] = pick_jump_plot(obj)
            figure(obj.figHandle);
            [t,~,~] = ginput(1);
            if isempty(t), jumpBi = []; betweenIdx=[]; return; end
            t = max(0, min(t, obj.Data.allDur_s));
            targetBin = max(1, ceil(t / obj.Data.binWidth_s));
            jumpBi = targetBin;
            betweenIdx = []; % Logic simplified
        end

        function [jumpBi, betweenIdx] = pick_jump_time(obj)
            defaultT = num2str(obj.State.currentBinIdx * obj.Data.binWidth_s);
            answer = inputdlg('Jump start time (seconds):','Jump',[1 35],{defaultT});
            if isempty(answer), jumpBi=[]; betweenIdx=[]; return; end
            t = str2double(answer{1});
            if isnan(t), jumpBi=[]; betweenIdx=[]; return; end
            targetBin = max(1, ceil(t / obj.Data.binWidth_s));
            jumpBi = targetBin;
            betweenIdx = [];
        end

        function [ok, selLabel, s, e] = bulk_label_plot_dialog(obj)
            ok = false; selLabel = ''; s = []; e = [];
            [indx, tf] = listdlg('PromptString','Choose label:', ...
                'SelectionMode','single', ...
                'ListString',{'Not Sleep','NREM Sleep','REM Sleep'}, ...
                'InitialValue',1,'ListSize',[180 90]);
            if ~tf, return; end
            % Map selection to numeric code
            possibleCodes = [obj.StateCodes.NotSleep, obj.StateCodes.NREM, obj.StateCodes.REM];
            selLabel = possibleCodes(indx);

            figure(obj.figHandle);
            [x1,~,~] = ginput(1); if isempty(x1), return; end
            [x2,~,~] = ginput(1); if isempty(x2), return; end
            s = min(x1,x2); e = max(x1,x2);
            ok = true;
        end

        function [ok, selLabel, s, e] = bulk_label_time_dialog(obj)
            % Impl similar to plot dialog but with inputdlg
            ok = false; selLabel = ''; s = []; e = [];
            [indx, tf] = listdlg('PromptString','Choose label:', ...
                'SelectionMode','single', ...
                'ListString',{'Not Sleep','NREM Sleep','REM Sleep'}, ...
                'InitialValue',1,'ListSize',[180 90]);
            if ~tf, return; end
            % Map selection to numeric code
            possibleCodes = [obj.StateCodes.NotSleep, obj.StateCodes.NREM, obj.StateCodes.REM];
            selLabel = possibleCodes(indx);

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


        function update_state_visualization(obj, xStart, xEnd)
            % Draw colored patches for sleep states on Force axis
            ax = obj.Axes.force;

            % Delete old patches? NO. We reuse them.
            % But we still need to hide patches that shouldn't be visible if they were previously?
            % Actually, we only iterate over visible bins here.
            % What about patches that move OUT of view?
            % Since patches are fixed in time (x-position), they just scroll out of view naturally.
            % We don't need to manually hide them unless we want to save rendering of off-screen objects?
            % MATLAB handles off-screen culling pretty well, but we can set Visible='off' if we really want.
            % For now, just updating visible ones is efficient.

            % Colors (matching add_sleep_bands)
            cNot=[0.8 0.8 0.8]; cNREM=[0.3 0.7 1]; cREM=[1 0.4 0.4];

            % Determine bin range
            bStart = max(1, floor(xStart / obj.Data.binWidth_s) + 1);
            bEnd   = min(obj.Data.NBins, ceil(xEnd / obj.Data.binWidth_s));

            yl = get(ax, 'YLim');
            yLow = yl(1); yHigh = yl(2);

            hold(ax, 'on');
            for b = bStart:bEnd
                state = obj.State.behavioralState(b);

                % Determine color
                if state == obj.StateCodes.Unscored
                    c = 'none'; % Don't draw or make invisible
                else
                    switch state
                        case obj.StateCodes.NotSleep, c=cNot;
                        case obj.StateCodes.NREM, c=cNREM;
                        case obj.StateCodes.REM, c=cREM;
                        otherwise, c='none';
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
                    end
                else
                    % Patch doesn't exist: create if visible
                    if ~strcmp(c, 'none')
                        t1 = (b-1) * obj.Data.binWidth_s;
                        t2 = b * obj.Data.binWidth_s;

                        % Create new patch
                        obj.GUI.BinPatches(b) = patch(ax, [t1 t2 t2 t1], [yLow yLow yHigh yHigh], c, ...
                            'FaceAlpha', 0.4, 'EdgeColor', 'none', 'Tag', 'StatePatch', 'HitTest', 'off');
                    end
                end
            end
        end



        function t = get_results(obj)
            % Create table with numeric state and string representation
            numericState = obj.State.behavioralState;

            % Map to strings
            strState = cell(size(numericState));
            for i = 1:length(numericState)
                idx = numericState(i) + 1; % 0-indexed code
                if idx >= 1 && idx <= length(obj.StateNames)
                    strState{i} = obj.StateNames{idx};
                else
                    strState{i} = 'Unknown';
                end
            end

            t = table(numericState, strState, 'VariableNames', {'behavState', 'behavStateStr'});
        end
    end

    % Methods for events
    methods (Access = private)

        function key_press_handler(obj, ~, event)
            obj.handle_event('Key', event.Key);
        end

        function close_request_handler(obj, ~, ~)
            % Clean up
            try delete(obj.GUI.cpFig); catch, end
            try delete(obj.figHandle); catch, end

            fprintf('Scoring session closed.\n');
            notify(obj, 'ScoringComplete');
        end

        function handle_event(obj, source, eventData)
            % Centralized event handler (Private)

            % Normalize actions
            action = '';

            if strcmp(source, 'Key')
                switch eventData
                    case {'a', '1'}, action = obj.StateCodes.NotSleep;
                    case {'n', '2'}, action = obj.StateCodes.NREM;
                    case {'r', '3'}, action = obj.StateCodes.REM;
                    case {'k', 'rightarrow'}, action = 'next_bin';
                    case {'j', 'leftarrow'}, action = 'prev_bin';
                end
            elseif strcmp(source, 'Button')
                switch eventData
                    case 'Not Sleep', action = obj.StateCodes.NotSleep;
                    case 'NREM Sleep', action = obj.StateCodes.NREM;
                    case 'REM Sleep', action = obj.StateCodes.REM;
                    otherwise, action = eventData;
                end
            end

            if isempty(action), return; end

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
                    case 'continue'
                        % Placeholder

                    case 'end'
                        obj.close_request_handler();

                        % Tools
                    case 'view'
                        % View remainder logic
                        % (Moved from panel_action)
                        try pan(obj.figHandle,'off'); zoom(obj.figHandle,'off'); catch, end
                        xStart = (obj.State.currentBinIdx)*obj.Data.binWidth_s;
                        xlim(obj.Axes.scoring_emg,[xStart obj.Data.allDur_s]);
                        obj.enable_click_zoom(true);

                        ch = questdlg('Viewing remainder. Next?','View','Continue','End here','Jump in plot','Continue');

                        obj.enable_click_zoom(false);

                        if strcmp(ch,'End here')
                            obj.close_request_handler();
                        elseif strcmp(ch,'Jump in plot')
                            obj.handle_event('Button', 'jump_plot');
                        end

                    case 'jump_plot'
                        [targetBi, betIdx] = obj.pick_jump_plot();
                        if ~isempty(targetBi)
                            if targetBi > obj.State.currentBinIdx
                                % obj.fill_empty_bins(betIdx);
                            end
                            obj.goto_bin(targetBi);
                        end
                    case 'jump_time'
                        [targetBi, betIdx] = obj.pick_jump_time();
                        if ~isempty(targetBi)
                            obj.goto_bin(targetBi);
                        end
                    case 'bulk_plot'
                        [ok, lab, s, e] = obj.bulk_label_plot_dialog();
                        if ok
                            [~, bEnd] = obj.apply_bulk_label(s, e, lab);
                            obj.mark_bulk_region(s, e);
                            obj.goto_bin(bEnd + 1);
                        end
                    case 'bulk_time'
                        [ok, lab, s, e] = obj.bulk_label_time_dialog();
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
                    case 'plot_scores'
                        obj.plot_scores_overview();
                end
            end
        end
    end
end