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
        selector_is_open = false;
        PollTimer         % Timer for polling globals
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
                'Color', 'w', 'Units', 'normalized', ...
                'Position', [0.1 0.1 0.6 0.8], ...
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
            obj.Axes.emg     = copyAndPos(figStruct.emg, 2);
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
            linkaxes([obj.Axes.force, obj.Axes.emg, obj.Axes.rawemg, ...
                obj.Axes.whisker, obj.Axes.pupil, obj.Axes.spectrogram], 'x');

            % Scoring axes references
            obj.Axes.scoring_emg = obj.Axes.emg;
            obj.Axes.scoring_spec = obj.Axes.spectrogram;
        end

        function setup_control_panel(obj)
            % Re-implement createControlPanel logic 1:1
            % 3 rows, 3 columns (justified)

            % Geometry
            pad   = 10;
            btnW  = 150;
            btnH  = 32;
            vpad  = 10;
            panelW = pad + 3*btnW + 2*pad + pad;
            panelH = pad + 3*btnH + 2*vpad + pad;

            % Calculate Position (Top-Right of Monitor)
            mf   = get(obj.figHandle,'OuterPosition');
            mons = get(groot,'MonitorPositions');
            mfCenter = [mf(1)+mf(3)/2, mf(2)+mf(4)/2];
            mIdx = 1;
            for i = 1:size(mons,1)
                m = mons(i,:);
                if mfCenter(1) >= m(1) && mfCenter(1) <= m(1)+m(3) && ...
                        mfCenter(2) >= m(2) && mfCenter(2) <= m(2)+m(4)
                    mIdx = i; break;
                end
            end
            m = mons(mIdx,:);
            margin = 10;
            topGap = 0.05;
            newX = m(1) + m(3) - panelW - margin;
            newY = m(2) + m(4)*(1 - topGap) - panelH;

            obj.GUI.cpFig = figure('Name','Scoring Controls',...
                'NumberTitle','off','MenuBar','none','ToolBar','none',...
                'HandleVisibility','off','Color',[0.97 0.97 0.97],...
                'Position',[newX newY panelW panelH],...
                'Resize','off','WindowStyle','normal','DockControls','off',...
                'CloseRequestFcn', @(~,~) obj.close_request_handler()); % closing this closes app

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

            % Grid Positions
            col1 = pad; col2 = pad + btnW + pad; col3 = pad + 2*(btnW + pad);
            row1 = panelH - pad - btnH;
            row2 = row1 - (btnH + vpad);
            row3 = row2 - (btnH + vpad);

            % --- Buttons ---
            % Row 1
            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Continue',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',blue,...
                'Position',[col1 row1 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('continue'));

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','End here',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',red,...
                'Position',[col2 row1 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('end'));

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Finish window',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',orange,...
                'Position',[col3 row1 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('finishwin'));

            % Row 2
            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','View remainder',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',black,...
                'Position',[col1 row2 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('view'));

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Bulk label (plot)',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',green,...
                'Position',[col2 row2 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('bulk_plot'));

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Bulk label (time)',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',cyan,...
                'Position',[col3 row2 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('bulk_time'));

            % Row 3
            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Jump in plot',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',purple,...
                'Position',[col1 row3 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('jump_plot'));

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Plot scores',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',[0.95 0.25 0.85],...
                'Position',[col2 row3 btnW btnH],...
                'Callback',@(~,~)obj.plot_scores_overview());

            uicontrol(obj.GUI.cpFig,'Style','pushbutton','String','Jump in time',...
                'FontWeight','bold','ForegroundColor',white,'BackgroundColor',purpleBlu,...
                'Position',[col3 row3 btnW btnH],...
                'Callback',@(~,~)obj.panel_action('jump_time'));
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

            % Launch External Selector (or ensure it's open)
            obj.setup_selector_gui();
            % Bring to front?
            hFig = findall(0, 'Type', 'figure', '-regexp', 'Name', 'Select.*Sleep|Sleep.*State');
            if ~isempty(hFig), try figure(hFig(1)); catch, end; end
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

        function setup_selector_gui(obj)
            % Launch external selector (Functional / Global Var based)

            % Check if already open (Robust check like CreateTrainingDataSet)
            hFig = findall(0, 'Type', 'figure', '-regexp', 'Name', 'Select.*Sleep|Sleep.*State');
            if isempty(hFig) || ~isvalid(hFig)
                % Reset globals
                global buttonState ButtonValue closeButtonState
                buttonState = 0;
                ButtonValue = 0;
                closeButtonState = 0;

                % Launch
                SelectSleepState_GUI();
            else
                try figure(hFig(1)); catch, end
            end

            obj.selector_is_open = true;
            obj.start_polling();
        end

        function start_polling(obj)
            if isempty(obj.PollTimer) || ~isvalid(obj.PollTimer)
                obj.PollTimer = timer('ExecutionMode', 'fixedRate', ...
                    'Period', 0.1, ...
                    'TimerFcn', @obj.poll_selector_callback);
            end
            if strcmp(obj.PollTimer.Running, 'off')
                start(obj.PollTimer);
            end
        end

        function stop_polling(obj)
            if ~isempty(obj.PollTimer) && isvalid(obj.PollTimer)
                stop(obj.PollTimer);
                delete(obj.PollTimer);
            end
            obj.PollTimer = [];
        end

        function poll_selector_callback(obj, ~, ~)
            global buttonState ButtonValue closeButtonState

            if closeButtonState == 1
                obj.close_selector_only();
                return;
            end

            if buttonState == 1
                switch ButtonValue
                    case 1, label = 'Not Sleep';
                    case 2, label = 'NREM Sleep';
                    case 3, label = 'REM Sleep';
                    otherwise, label = '';
                end

                if ~isempty(label)
                    obj.score_current_bin(label);
                end

                % Reset
                buttonState = 0;
                ButtonValue = 0;
            end
        end

        function close_selector_only(obj)
            % Close selector and stop polling
            obj.stop_polling();

            hFig = findall(0, 'Type', 'figure', '-regexp', 'Name', 'Select.*Sleep|Sleep.*State');
            if ~isempty(hFig)
                delete(hFig);
            end

            obj.selector_is_open = false;
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
                case 'n', obj.score_current_bin('Not Sleep');
                case 'r', obj.score_current_bin('NREM Sleep');
                case 'w', obj.score_current_bin('REM Sleep');
                case 'k', obj.advance_bin(1);
                case 'j', obj.advance_bin(-1);
            end
        end

        function close_request_handler(obj, ~, ~)
            % Clean up
            obj.close_selector_only();
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
