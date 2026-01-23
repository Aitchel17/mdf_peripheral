classdef sleepscoring_gui < handle
    %SLEEPSCORING_GUI Interactive manual sleep scoring for analog data
    %   Class-based implementation of the manual scoring GUI.
    %   Ports all logic from CreateTrainingDataSet_SleepAnalog.m.
    %   Polls globals buttonState, ButtonValue, closeButtonState to interact with SelectSleepState_GUI.

    properties (Access = public)
        Data
        State
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
            obj.State.behavioralState = cell(NBins, 1);
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
                'ButtonPushedFcn', @(~,~) obj.score_current_bin('Not Sleep'));

            % NREM Sleep (Blue)
            uibutton(StateLayout, 'Text', 'NREM Sleep (N)', ...
                'BackgroundColor', obj.blue, 'FontColor', obj.white, ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) obj.score_current_bin('NREM Sleep'));

            % REM Sleep (Red)
            uibutton(StateLayout, 'Text', 'REM Sleep (R)', ...
                'BackgroundColor', obj.red, 'FontColor', obj.white, ...
                'FontWeight', 'bold', 'FontSize', 14, ...
                'ButtonPushedFcn', @(~,~) obj.score_current_bin('REM Sleep'));

            % --- Panel 2: Tools & Navigation ---
            ToolsPanel = uipanel(MainLayout, 'Title', 'Tools & Nav');
            ToolsPanel.Layout.Row = 2;
            ToolsLayout = uigridlayout(ToolsPanel, [3,3]); % 3x3 Grid
            ToolsLayout.RowHeight = {'1x', '1x', '1x'};
            ToolsLayout.ColumnWidth = {'1x', '1x', '1x'};
            ToolsLayout.Padding = [5 5 5 5];

            % Tools Configuration
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
                if strcmp(actionStr, 'plot_scores')
                    cb = @(src,event)obj.plot_scores_overview();
                else
                    cb = @(src,event)obj.panel_action(actionStr);
                end

                % Create Button
                btn = uibutton(ToolsLayout, ...
                    'Text', btnConfig{i,1}, ...
                    'FontWeight', 'bold', ...
                    'FontColor', obj.white, ...
                    'BackgroundColor', btnConfig{i,2}, ...
                    'ButtonPushedFcn', cb);

                % Position logic matches simple grid fill
                rowIdx = ceil(i/3);
                colIdx = mod(i-1, 3) + 1;
                btn.Layout.Row = rowIdx;
                btn.Layout.Column = colIdx;
            end
        end





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

        end

        function draw_bin_markers(obj, xStart, xEnd)
            % Delete old
            h = findobj(obj.figHandle, 'Tag', 'BinMarker');
            delete(h);

            % Draw new (Color [0.75 0 1] = Purple)
            subplot(obj.Axes.scoring_emg); hold on;
            xline(xStart,'color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            xline(xEnd,  'color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');

            subplot(obj.Axes.scoring_spec); hold on;
            xline(xStart,'color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
            xline(xEnd,  'color',[0.75 0 1],'LineWidth',2, 'Tag', 'BinMarker');
        end

        function panel_action(obj, action)
            % Handles actions from the Control Panel (e.g. 'continue', 'jump', etc.)

            switch action
                case 'continue'
                    % Just move next? Or do nothing (it's mainly for resuming from pause)
                    % In loop version, it breaks the wait. Here we are event driven.
                    % Maybe advance if unscored, or just stay.

                case 'end'
                    obj.close_request_handler();

                case 'view'
                    % View remainder
                    try pan(obj.figHandle,'off'); zoom(obj.figHandle,'off'); catch, end
                    xStart = (obj.State.currentBinIdx)*obj.Data.binWidth_s;
                    xlim(obj.Axes.scoring_emg,[xStart obj.Data.allDur_s]);
                    % Enable click zoom
                    obj.enable_click_zoom(true);

                    % Ask user how to proceed
                    ch = questdlg('Viewing remainder. Next?','View','Continue','End here','Jump in plot','Continue');

                    obj.enable_click_zoom(false);

                    if strcmp(ch,'End here')
                        obj.close_request_handler();
                    elseif strcmp(ch,'Jump in plot')
                        obj.panel_action('jump_plot');
                    end

                case 'jump_plot'
                    [targetBi, betIdx] = obj.pick_jump_plot();
                    if ~isempty(targetBi)
                        if targetBi > obj.State.currentBinIdx
                            % Mark in between as empty?
                            % obj.fill_empty_bins(betIdx); % Optional
                        end
                        obj.goto_bin(targetBi);
                    end

                case 'jump_time'
                    % Similar to jump_plot but with inputdlg
                    [targetBi, betIdx] = obj.pick_jump_time();
                    if ~isempty(targetBi)
                        obj.goto_bin(targetBi);
                    end

                case 'bulk_plot'
                    [ok, lab, s, e] = obj.bulk_label_plot_dialog();
                    if ok
                        obj.apply_bulk_label(s, e, lab);
                        obj.mark_bulk_region(s, e);
                    end

                case 'bulk_time'
                    [ok, lab, s, e] = obj.bulk_label_time_dialog();
                    if ok
                        obj.apply_bulk_label(s, e, lab);
                        obj.mark_bulk_region(s, e);
                    end

                case 'finishwin'
                    % Label all visible bins in current window as Not Sleep (if empty)
                    % Then jump to next
                    xl = get(obj.Axes.scoring_emg, 'XLim');
                    sW = max(0,xl(1)); eW=min(obj.Data.allDur_s, xl(2));
                    obj.apply_bulk_label(sW, eW, 'Not Sleep', true); % true = only if empty

                    bEn = min(obj.Data.NBins, ceil(eW/obj.Data.binWidth_s));
                    obj.goto_bin(bEn + 1);
            end
        end

        function score_current_bin(obj, label)
            obj.State.behavioralState{obj.State.currentBinIdx} = label;
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
            labels = {'Not Sleep','NREM Sleep','REM Sleep'};
            selLabel = labels{indx};

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
            labels = {'Not Sleep','NREM Sleep','REM Sleep'};
            selLabel = labels{indx};

            answ = inputdlg({'Start time (s):','End time (s):'}, ...
                'Bulk label (time)',[1 28], {'0', num2str(obj.Data.allDur_s)});
            if isempty(answ), return; end
            s = str2double(answ{1}); e = str2double(answ{2});
            ok = true;
        end

        function apply_bulk_label(obj, s, e, label, onlyIfEmpty)
            if nargin < 5, onlyIfEmpty = false; end

            bStart = max(1, floor(s / obj.Data.binWidth_s)+1);
            bEnd   = min(obj.Data.NBins, ceil(e / obj.Data.binWidth_s));

            for b = bStart:bEnd
                if ~onlyIfEmpty || isempty(obj.State.behavioralState{b})
                    obj.State.behavioralState{b} = label;
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

        function click_zoom_handler_cb(obj, src, evt)
            % Logic to zoom into point
            cp = get(gca, 'CurrentPoint'); cx = cp(1,1);
            % Zoom logic (simple center)
            w = 500;
            x1 = max(0, cx-w/2); x2 = min(obj.Data.allDur_s, cx+w/2);
            xlim(obj.Axes.scoring_emg, [x1 x2]);
        end

        function plot_scores_overview(obj)
            % Port showSleepScoreOverview Logic
            % This creates a new figure with summary
            figure('Name', 'Sleep Score Overview');
            % For now, just a placeholder plot as we don't have full data reconstruction logic inside class yet
            % Ideally we pass 'ProcData' path or similar.
            % For this edit, I will just visualize the STATES bar.

            ax = axes();
            obj.add_sleep_bands(ax, obj.State.behavioralState, 0:obj.Data.binWidth_s:obj.Data.allDur_s, obj.Data.allDur_s);
            title('Score Overview (Bands)');
        end

        function add_sleep_bands(obj, ax, states, edges, dur)
            % (Port of addSleepBandsOutsideAxis logic)
            % Just draws the colored ribbon
            hold(ax, 'on');
            cNot=[0.8 0.8 0.8]; cNREM=[0.3 0.7 1]; cREM=[1 0.4 0.4];

            for i=1:numel(states)
                if isempty(states{i}), continue; end
                switch states{i}
                    case 'Not Sleep', c=cNot;
                    case 'NREM Sleep', c=cNREM;
                    case 'REM Sleep', c=cREM;
                    otherwise, c=[1 1 1];
                end
                t1 = edges(i); t2 = edges(i+1);
                patch(ax, [t1 t2 t2 t1], [0 0 1 1], c, 'EdgeColor','none');
            end
        end

        function key_press_handler(obj, ~, event)
            switch event.Key
                % Not Sleep
                case {'a', '1'}, obj.score_current_bin('Not Sleep');
                    % NREM Sleep
                case {'n', '2'}, obj.score_current_bin('NREM Sleep');
                    % REM Sleep
                case {'r', '3'}, obj.score_current_bin('REM Sleep');

                    % Navigation
                case {'k', 'rightarrow'}, obj.advance_bin(1);
                case {'j', 'leftarrow'}, obj.advance_bin(-1);
            end
        end

        function close_request_handler(obj, ~, ~)
            % Clean up
            try delete(obj.GUI.cpFig); catch, end
            try delete(obj.figHandle); catch, end

            fprintf('Scoring session closed.\n');
            notify(obj, 'ScoringComplete');
        end

        function t = get_results(obj)
            t = table(obj.State.behavioralState, 'VariableNames', {'behavState'});
        end
    end

end
