function trainingTable = CreateTrainingDataSet_SleepAnalog(figStruct, NBins, binWidth_s)
%CREATETRAININGDATASET_SLEEPANALOG  Interactive manual sleep scoring for analog data (Pure GUI).
%   TRAININGTABLE = CreateTrainingDataSet_SleepAnalog(FIGSTRUCT, NBINS, BINWIDTH_S)
%   run interactive scoring on a new figure built from component figures.
%
%   INPUTS
%       figStruct    Struct containing peripheral_fig objects:
%                      .force, .emg, .rawemg, .whisker, .spectrogram, [.pupil]
%       NBins        Number of bins.
%       binWidth_s   Bin width in seconds (default 5).

clc;

if nargin < 3 || isempty(binWidth_s)
    binWidth_s = 5;
end
if nargin < 2
    error('Usage: trainingTable = CreateTrainingDataSet_SleepAnalog(figStruct, NBins, [binWidth_s])');
end

% 1. Create main figure
figHandle = figure('Name', 'Sleep Scoring Composite', 'Color', 'w', 'Units', 'normalized', 'Position', [0.1 0.1 0.6 0.8]);
pan(figHandle,'off');
z = zoom(figHandle);
z.Motion = 'horizontal';
z.Enable = 'on';

% 2. Copy axes from peripheral_fig objects
% Define subplot geometry (8 rows)
% Row 1: Force
% Row 2: EMG Power
% Row 3: Raw EMG
% Row 4: Whisker
% Row 5: Pupil (or placeholder)
% Rows 6-8: Spectrogram

% Helper to copy and position axis
    function axNew = copyAndPos(figObj, subplotIdx)
        if isempty(figObj) || isempty(figObj.ax) || ~isvalid(figObj.ax) % Check if figure object or axis is invalid
            axNew = subplot(8, 1, subplotIdx, 'Parent', figHandle); % Create placeholder subplot
            text(axNew, 0.5, 0.5, 'Data unavailable', 'HorizontalAlignment','center'); % Display unavailable message
            return; % Exit function
        end
        % Create a dummy subplot to get the standard position
        dummy = subplot(8, 1, subplotIdx, 'Parent', figHandle); % Create temporary subplot to get correct position
        pos = get(dummy, 'Position'); % Get position of dummy subplot
        delete(dummy); % Delete dummy subplot

        axNew = copyobj(figObj.ax, figHandle); % Copy the axis from peripheral_fig to main figure
        set(axNew, 'Position', pos); % Apply the standard position to the copied axis
    end

ax_force   = copyAndPos(figStruct.force, 1); % Copy Force axis to row 1
ax_emg     = copyAndPos(figStruct.emg, 2); % Copy EMG Power axis to row 2
ax_rawemg  = copyAndPos(figStruct.rawemg, 3); % Copy Raw EMG axis to row 3
ax_whisker = copyAndPos(figStruct.whisker, 4); % Copy Whisker axis to row 4

if isfield(figStruct, 'pupil') && ~isempty(figStruct.pupil) % Check if pupil data exists
    ax_pupil = copyAndPos(figStruct.pupil, 5); % Copy Pupil axis to row 5 if available
else
    ax_pupil = subplot(8,1,5,'Parent',figHandle); % Create empty subplot for Pupil if missing
    axis(ax_pupil, 'off');
    text(ax_pupil, 0.5, 0.5, 'Pupil not provided', 'HorizontalAlignment','center');
end

% Spectrogram (Rows 6-8)
if isempty(figStruct.spectrogram) || isempty(figStruct.spectrogram.ax)
    ax6 = subplot(8, 1, 6:8, 'Parent', figHandle);
    text(ax6, 0.5, 0.5, 'Spectrogram unavailable', 'HorizontalAlignment','center');
else
    dummy = subplot(8, 1, 6:8, 'Parent', figHandle);
    pos = get(dummy, 'Position');
    delete(dummy);
    ax6 = copyobj(figStruct.spectrogram.ax, figHandle);
    set(ax6, 'Position', pos);
end

% Assign Key Scoring Axes (Explicitly known now!)
ax4 = ax_emg;  % Main scoring line axis
% ax6 is already the spectrogram axis

% Link x-axes
linkaxes([ax_force, ax_emg, ax_rawemg, ax_whisker, ax_pupil, ax6], 'x');

%------ Control panel ------
cpFig = createControlPanel(figHandle);
setappdata(figHandle,'cpFig',cpFig);
setappdata(figHandle,'cpAction','');

disp('Explore plots (zoom/pan). Press ENTER in the command window when ready to start scoring...');
% ~input('','s');

% ----- BIN SETTINGS -----
numBins         = NBins;
behavioralState = cell(numBins,1);
allDur_s        = numBins * binWidth_s;

% Store scoring state on main figure
setappdata(figHandle,'behavioralState',behavioralState);
setappdata(figHandle,'numBins',numBins);
setappdata(figHandle,'binWidth_s',binWidth_s);
setappdata(figHandle,'allDur_s',allDur_s);

%------ Manual scope ------
disp('Manual scoring scope:');
disp('  1) Full file (default)');
disp('  2) Specific time windows only');
scopeChoice = input('Enter 1 or 2: ');

binsToScore = 1:numBins;
windows = [];

if scopeChoice == 2
    disp('Provide time windows:');
    disp('  A) Type start/end in seconds');
    disp('  B) Click start/end on plot');
    how = lower(input('Choose A or B: ','s'));

    if strcmpi(how,'a')
        windows = input('Enter Nx2 numeric array [start end]: ');
        if isempty(windows) || size(windows,2)~=2, error('Invalid windows.'); end
    else
        disp('Click START then END. Press ENTER when finished.');
        figure(figHandle);
        windows = [];
        while true
            [x,~,btn] = ginput(1);
            if isempty(x) || (~isempty(btn) && btn==13), break, end
            s = x;
            [x2,~,btn2] = ginput(1);
            if isempty(x2) || (~isempty(btn2) && btn2==13), break, end
            e = x2;
            windows = [windows; [min(s,e) max(s,e)]]; %#ok<AGROW>
            xline(ax4,s,'--','Color','k'); xline(ax4,e,'--','Color','k');
        end
        if isempty(windows), error('No windows selected.'); end
    end

    windows = max(windows,0);
    windows(:,2) = min(windows(:,2), allDur_s);
    windows = sortrows(windows,1);
    windows = mergeTouchingWindows(windows);

    binsToScore = [];
    for k = 1:size(windows,1)
        s = windows(k,1); e = windows(k,2);
        bStart = max(1, floor(s/binWidth_s)+1);
        bEnd   = min(numBins, ceil(e/binWidth_s));
        binsToScore = [binsToScore, bStart:bEnd]; %#ok<AGROW>
    end
    binsToScore = unique(binsToScore);

    % Mark others as empty (will become Not Sleep)
    for b = 1:numBins
        if ~ismember(b, binsToScore), behavioralState{b,1} = []; end
    end
end

% Map bins to windows
binWindowIdx = zeros(1,numBins);
if ~isempty(windows)
    for k = 1:size(windows,1)
        s = windows(k,1); e = windows(k,2);
        bStart = max(1, floor(s/binWidth_s)+1);
        bEnd   = min(numBins, ceil(e/binWidth_s));
        binWindowIdx(bStart:bEnd) = k;
    end
end

%------ Scoring Loop ------
bi = 1;
breakOutAll = false;
checkpointBins = max(1, round(500/binWidth_s));

% Globals used by openSleepSelectorAndCapture
global buttonState ButtonValue closeButtonState
buttonState = 0; ButtonValue = 0; closeButtonState = 0;

while bi <= numel(binsToScore)
    b = binsToScore(bi);

    % Reset globals
    buttonState = 0; ButtonValue = 0; closeButtonState = 0;

    xStartVal = (b-1)*binWidth_s;
    xEndVal   = b*binWidth_s;

    % Markers
    subplot(ax4); hold on;
    le3 = xline(xStartVal,'color',[0.75 0 1],'LineWidth',2);
    re3 = xline(xEndVal,  'color',[0.75 0 1],'LineWidth',2);
    subplot(ax6); hold on;
    le6 = xline(xStartVal,'color',[0.75 0 1],'LineWidth',2);
    re6 = xline(xEndVal,  'color',[0.75 0 1],'LineWidth',2);

    % View window
    if binWindowIdx(b) ~= 0
        k = binWindowIdx(b);
        wStart = windows(k,1); wEnd = windows(k,2);
        desiredLen = max(500, wEnd-wStart);
        x1 = wStart; x2 = min(wStart+desiredLen, allDur_s);
        if xEndVal > x2, shift = xEndVal-x2+1; x1=max(0,x1-shift); x2=min(allDur_s,x2+shift); end
    else
        % Generic
        winLen = (binWidth_s==5)*500 + (binWidth_s~=5)*300;
        winIdx = ceil(b / max(1, round(winLen/binWidth_s)));
        x1 = (winIdx-1)*winLen; x2 = min(allDur_s, x1+winLen);
    end
    xlim(ax4,[x1 x2]); xlim(ax6,[x1 x2]);

    if mod(b,checkpointBins)==0 || bi==numel(binsToScore)
        closeButtonState = 1;
    end

    % === Enable External GUI ===
    openSleepSelectorAndCapture(figHandle);

    % === Poll Control Panel & External GUI ===
    earlyAction = '';
    while buttonState == 0
        drawnow limitrate;
        if ishghandle(figHandle) && isappdata(figHandle,'cpAction')
            act = getappdata(figHandle,'cpAction');
            if ~isempty(act) && ~strcmp(act,'continue')
                closeButtonState = 1;
                earlyAction = act;
                setappdata(figHandle,'cpAction','');
                break;
            end
        end
        if ~ishghandle(figHandle), breakOutAll=true; break; end
    end

    if buttonState == 1 && isempty(earlyAction)
        if     ButtonValue == 1, behavioralState{b,1} = 'Not Sleep';
        elseif ButtonValue == 2, behavioralState{b,1} = 'NREM Sleep';
        elseif ButtonValue == 3, behavioralState{b,1} = 'REM Sleep';
        elseif ButtonValue == 0
            warndlg('Select a state button or type letter.');
            openSleepSelectorAndCapture(figHandle);
        end
    end

    doJumpNow = false; targetBi = [];

    if ~isempty(earlyAction)
        switch earlyAction
            case 'end'
                closeButtonState = 1; drawnow; forceCloseSelector(figHandle);
                behavioralState = markBinsAsEmpty(bi+1, binsToScore, behavioralState);
                breakOutAll = true;
            case 'view'
                try pan(figHandle,'off'); zoom(figHandle,'off'); catch, end
                xlim(ax4,[xEndVal allDur_s]); xlim(ax6,[xEndVal allDur_s]); drawnow;
                enableClickZoom(figHandle, ax4, ax6, allDur_s, true);

                ch = questdlg('Viewing remainder. Next?','View','Continue','End here','Jump in plot','Continue');
                if strcmp(ch,'End here')
                    behavioralState = markBinsAsEmpty(bi+1, binsToScore, behavioralState);
                    breakOutAll = true;
                elseif strcmp(ch,'Jump in plot')
                    [targetBi, betIdx] = pickJumpOnPlot(figHandle, allDur_s, binsToScore, bi, binWidth_s);
                    if ~isempty(targetBi)&&targetBi>bi, behavioralState=setBetweenAsEmpty(betIdx,binsToScore,behavioralState); end
                    doJumpNow=true;
                end
                enableClickZoom(figHandle, ax4, ax6, allDur_s, false);

            case {'jump_plot','jump_time'}
                if strcmp(earlyAction,'jump_plot')
                    [targetBi, betIdx] = pickJumpOnPlot(figHandle,allDur_s,binsToScore,bi,binWidth_s);
                else
                    [targetBi, betIdx] = pickJumpByTime(figHandle,allDur_s,binsToScore,bi,binWidth_s);
                end
                if ~isempty(targetBi)&&targetBi>bi, behavioralState=setBetweenAsEmpty(betIdx,binsToScore,behavioralState); end
                doJumpNow=true;

            case 'finishwin'
                xl = get(ax4,'XLim');
                sW = max(0,xl(1)); eW=min(allDur_s,xl(2));
                bSt=max(1,floor(sW/binWidth_s)+1); bEn=min(numBins,ceil(eW/binWidth_s));
                tgt = bSt:bEn; tgt=tgt(ismember(tgt,binsToScore));
                for bb=tgt, if isempty(behavioralState{bb,1}), behavioralState{bb,1}='Not Sleep'; end; end

                nextStart = min(numBins, bEn+1);
                tBi = find(binsToScore>=nextStart,1,'first');
                if ~isempty(tBi), targetBi=tBi; doJumpNow=true; else, breakOutAll=true; end

            case {'bulk_plot','bulk_time'}
                if strcmp(earlyAction,'bulk_plot')
                    [ok, lab, sB, eB] = bulkLabelPlotDialog(figHandle, ax4, ax6, allDur_s);
                else
                    [ok, lab, sB, eB] = bulkLabelTimeDialog(figHandle, allDur_s);
                end
                if ok
                    behavioralState = applyBulkLabel(behavioralState, sB, eB, binsToScore, numBins, lab, binWidth_s);
                    markBulkRegion(figHandle, ax4, ax6, sB, eB, allDur_s);
                    bSB = max(1, floor(sB/binWidth_s)+1); bEB=min(numBins, ceil(eB/binWidth_s));
                    idxSet = find(ismember(binsToScore, bSB:bEB));
                    if ~isempty(idxSet)
                        firstI = idxSet(1); lastI = idxSet(end);
                        if firstI > bi
                            for ig = (bi+1):(firstI-1), bg=binsToScore(ig); if isempty(behavioralState{bg,1}), behavioralState{bg,1}='Not Sleep'; end; end
                        end
                        targetBi = lastI+1;
                        if targetBi<=numel(binsToScore), doJumpNow=true; else, breakOutAll=true; end
                    end
                end
        end
    end

    delete(le3); delete(re3); delete(le6); delete(re6);
    closeButtonState = 0;
    setappdata(figHandle,'behavioralState',behavioralState);

    if doJumpNow
        if ~isempty(targetBi) && targetBi>=1 && targetBi<=numel(binsToScore)
            bi=targetBi; pause(0.05); continue;
        else
            break;
        end
    end
    if breakOutAll, break; end

    bi = bi + 1;
    pause(0.1);
end

if ishghandle(cpFig), try close(cpFig); catch, end; end

% Fill remaining empty with Not Sleep
for b = 1:numBins
    if isempty(behavioralState{b,1}), behavioralState{b,1} = 'Not Sleep'; end
end

% Result Table
if exist('paramsTable','var')~=1, paramsTable=table; end
paramsTable.behavState = behavioralState;
trainingTable = paramsTable;

end

%% ========================================================================
%%                     Control panel factory & helpers
%% ========================================================================
function cpFig = createControlPanel(mainFig)
% 3 rows, 3 columns (justified)
% Top: Continue | End here | Finish window
% Mid: View remainder | Bulk label (plot) | Bulk label (time)
% Bot: Jump in plot | Plot scores | Jump in time

cpFig = figure('Name','Scoring Controls',...
    'NumberTitle','off','MenuBar','none','ToolBar','none',...
    'HandleVisibility','off','Color',[0.97 0.97 0.97],...
    'Position',localPanelPos(mainFig),...
    'Resize','off','WindowStyle','normal','DockControls','off');

% Colors
blue      = [0.00 0.45 0.90];
red       = [0.85 0.10 0.10];
black     = [0.10 0.10 0.10];
orange    = [0.93 0.49 0.19];
purple    = [0.50 0.10 0.70];
purpleBlu = [0.35 0.45 0.95];       % purple-blue for "Jump in time"
green     = [0.20 0.65 0.20];
cyan      = [0.00 0.70 0.85];       % cyan-ish for Bulk label (time)
white     = [1 1 1];

% Geometry (3 columns) — no label text columns now
pad   = 10;         % outer + inner padding
btnW  = 150;        % a bit wider to fit new labels
btnH  = 32;
vpad  = 10;         % vertical space between rows

panelW = pad + 3*btnW + 2*pad + pad;    % left pad + 3*btnW + 2 gaps + right pad
panelH = pad + 3*btnH + 2*vpad + pad;   % top pad + 3 rows + 2 gaps + bottom pad

% Place control panel at the top-right of the monitor containing mainFig
set(cpFig,'Units','pixels');  % ensure pixel math
mf   = get(mainFig,'OuterPosition');       % [x y w h]
mons = get(groot,'MonitorPositions');      % one row per monitor: [x y w h]

% find which monitor contains the center of mainFig
mfCenter = [mf(1)+mf(3)/2, mf(2)+mf(4)/2];
mIdx = 1;
for i = 1:size(mons,1)
    m = mons(i,:);
    if mfCenter(1) >= m(1) && mfCenter(1) <= m(1)+m(3) && ...
            mfCenter(2) >= m(2) && mfCenter(2) <= m(2)+m(4)
        mIdx = i; break
    end
end
m = mons(mIdx,:);

margin = 10;  % pixels from the edges
newX = m(1) + m(3) - panelW - margin;
% 5% gap from the top of the monitor
topGap = 0.05;
newY = m(2) + m(4)*(1 - topGap) - panelH;
set(cpFig,'Position',[newX newY panelW panelH]);

% Column x positions
col1 = pad;
col2 = pad + btnW + pad;
col3 = pad + 2*(btnW + pad);

% Row y positions (top-down)
row1 = panelH - pad - btnH;                       % top row
row2 = row1 - (btnH + vpad);                      % middle row
row3 = row2 - (btnH + vpad);                      % bottom row

% ---------- Row 1 (Continue | End here | Finish window) ----------
uicontrol(cpFig,'Style','pushbutton','String','Continue',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',blue,...
    'Position',[col1 row1 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'continue'));

uicontrol(cpFig,'Style','pushbutton','String','End here',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',red,...
    'Position',[col2 row1 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'end'));

uicontrol(cpFig,'Style','pushbutton','String','Finish window',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',orange,...
    'Position',[col3 row1 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'finishwin'));

% ---------- Row 2 (View remainder | Bulk label (plot) | Bulk label (time)) ----------
uicontrol(cpFig,'Style','pushbutton','String','View remainder',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',black,...
    'Position',[col1 row2 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'view'));

uicontrol(cpFig,'Style','pushbutton','String','Bulk label (plot)',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',green,...
    'Position',[col2 row2 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'bulk_plot'));

uicontrol(cpFig,'Style','pushbutton','String','Bulk label (time)',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',cyan,...
    'Position',[col3 row2 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'bulk_time'));

% ---------- Row 3 (Jump in plot | Plot scores | Jump in time) ----------
uicontrol(cpFig,'Style','pushbutton','String','Jump in plot',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',purple,...
    'Position',[col1 row3 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'jump_plot'));

uicontrol(cpFig,'Style','pushbutton','String','Plot scores',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',[0.95 0.25 0.85],...
    'Position',[col2 row3 btnW btnH],...
    'Callback',@(h,~)plotScoresFromPanel(h));

uicontrol(cpFig,'Style','pushbutton','String','Jump in time',...
    'FontWeight','bold','ForegroundColor',white,'BackgroundColor',purpleBlu,...
    'Position',[col3 row3 btnW btnH],...
    'Callback',@(h,~)panelSetAction(h,'jump_time'));

setappdata(cpFig,'mainFig',mainFig);
end

function panelSetAction(btn,action)
cpFig = ancestor(btn,'figure');
mainFig = getappdata(cpFig,'mainFig');
if ishghandle(mainFig)
    setappdata(mainFig,'cpAction',action);
end
end

function pos = localPanelPos(mainFig)
try
    mfpos = get(mainFig,'Position'); % [left bottom width height]
    pos = [mfpos(1)+mfpos(3)+10, mfpos(2)+mfpos(4)-180, 360, 160];
catch
    pos = [100 100 360 160];
end
end

function plotScoresFromPanel(btn)
% Callback for the "Plot scores" button on the control panel.
% It pulls behavioralState and metadata from the main figure and
% opens/updates a separate summary figure with pupil + spectrogram.

cpFig   = ancestor(btn,'figure');
mainFig = getappdata(cpFig,'mainFig');

if ~ishghandle(mainFig)
    warndlg('Main figure not found.','Plot scores');
    return;
end

if ~isappdata(mainFig,'behavioralState')
    warndlg('No sleep scores available yet for this file.','Plot scores');
    return;
end

behavioralState = getappdata(mainFig,'behavioralState');
numBins         = getappdata(mainFig,'numBins');
binWidth_s      = getappdata(mainFig,'binWidth_s');
procDataFileID  = '';
if isappdata(mainFig,'procDataFileID')
    procDataFileID = getappdata(mainFig,'procDataFileID');
end

showSleepScoreOverview(behavioralState, numBins, binWidth_s, procDataFileID);
end

function showSleepScoreOverview(behavioralState, numBins, binWidth_s, procDataFileID)
% Create/update a 2x1 overview:
%   Top: EMG Power
%   Bottom: EEG spectrogram
% Sleep-state color bars are shown in thin axes just above each subplot.

if nargin < 2 || isempty(numBins)
    numBins = numel(behavioralState);
end
if nargin < 3 || isempty(binWidth_s)
    binWidth_s = 5;
end

% Convert labels -> numeric codes
% 0 = Not Sleep, 1 = NREM, 2 = REM, NaN = unlabeled
stateNum = nan(1,numBins);
for b = 1:min(numBins, numel(behavioralState))
    lab = behavioralState{b,1};
    if isempty(lab)
        continue;
    end
    switch lab
        case 'Not Sleep'
            stateNum(b) = 0;
        case 'NREM Sleep'
            stateNum(b) = 1;
        case 'REM Sleep'
            stateNum(b) = 2;
        otherwise
            % unknown label, leave as NaN
    end
end

tEdges        = (0:numBins)*binWidth_s;   % bin edges for bands
trialDuration = numBins*binWidth_s;       % default if file not loaded

% -------------------------------------------------------------------------
% Load ProcData and SpecData to reconstruct EMG + spectrogram
% -------------------------------------------------------------------------
emg_t = [];
emg_y = [];
T = []; F = []; Sspec = [];
isNormSpec = false;   % NEW: track whether we loaded normS vs S

fullProcPath = '';
if nargin >= 4 && ~isempty(procDataFileID)
    % Resolve to a full path if possible
    if exist(procDataFileID,'file') == 2
        % If it's on the path or already a full path
        w = which(procDataFileID);
        if ~isempty(w)
            fullProcPath = w;
        else
            fullProcPath = procDataFileID;
        end
    else
        % Try to interpret as "name.mat" in the current folder
        [pName, pBase, pExt] = fileparts(procDataFileID);
        if isempty(pExt)
            pExt = '.mat';
        end
        if isempty(pName)
            cand = fullfile(pwd, [pBase pExt]);
        else
            cand = procDataFileID;
        end
        if exist(cand,'file') == 2
            fullProcPath = cand;
        end
    end
end

if ~isempty(fullProcPath) && exist(fullProcPath,'file') == 2
    try
        S = load(fullProcPath,'ProcData');
        ProcData = S.ProcData;

        % Update trial duration / fs from file if available
        if isfield(ProcData,'notes')
            if isfield(ProcData.notes,'trialDuration_sec')
                trialDuration = ProcData.notes.trialDuration_sec;
            end
            if isfield(ProcData.notes,'dsFs')
                fs = ProcData.notes.dsFs;
            else
                error('ProcData.notes.dsFs field is missing.');
            end
        else
            error('ProcData.notes struct is missing.');
        end

        % --- EMG power (normalized) ---
        if isfield(ProcData,'EMG') && isfield(ProcData.EMG,'emgPower_norm')
            pd = ProcData.EMG.emgPower_norm(:);

            if all(isnan(pd))
                warning('showSleepScoreOverview: EMG emgPower_norm is all NaN in %s.', fullProcPath);
            else
                % Basic cleaning / de-spiking (same logic as before)
                pd = fillmissing(pd,'linear','MaxGap',round(2*fs));
                absZ   = abs(pd);
                d1     = [0; diff(pd,1,1)];
                wMed   = max(5, round(1*fs));
                locMed = movmedian(pd, wMed, 'omitnan');
                locDev = abs(pd - locMed);
                isGross  = absZ > 10;
                isJump   = abs(d1) > 5;
                isOut    = locDev > 4;
                spikeIdx = isGross | isJump | isOut;
                pd(spikeIdx) = NaN;
                pd = fillmissing(pd,'linear','MaxGap',round(2*fs));
                pd = fillmissing(pd,'nearest');
                pd = medfilt1(pd, max(3, round(0.20*fs)), 'omitnan', 'truncate');

                % Low-pass filter
                [zp,pp,kp] = butter(4, 2/(fs/2), 'low');
                [sosP,gP]  = zp2sos(zp,pp,kp);
                pd = filtfilt(sosP,gP, pd);

                % Clamp for display
                pd = max(min(pd, 6), -6);

                emg_y = pd;
                emg_t = (0:length(pd)-1)/fs;
            end
        else
            warning('showSleepScoreOverview: ProcData.EMG.emgPower_norm not found in %s.', fullProcPath);
        end

        % --- Spectrogram file (mirror Generate_SleepScoringFigure_Analog style) ---
        [folder, base, ~] = fileparts(fullProcPath);
        prefix       = regexprep(base, '_ProcData$', '');
        specDataFile = fullfile(folder, [prefix '_SpecData.mat']);

        if exist(specDataFile, 'file') == 2
            L = load(specDataFile, 'SpecData');
            if isfield(L,'SpecData') && isfield(L.SpecData,'ECoG')
                E = L.SpecData.ECoG;
                if isfield(E,'normS')
                    Sspec      = E.normS;
                    isNormSpec = true;
                elseif isfield(E,'S')
                    Sspec      = E.S;
                    isNormSpec = false;
                else
                    warning('showSleepScoreOverview: SpecData.ECoG lacks normS and S fields in %s.', specDataFile);
                end

                if isfield(E,'T'); T = E.T; else, warning('SpecData.ECoG.T missing.'); end
                if isfield(E,'F'); F = E.F; else, warning('SpecData.ECoG.F missing.'); end
            else
                warning('showSleepScoreOverview: SpecData.ECoG not found in %s.', specDataFile);
            end
        else
            warning('showSleepScoreOverview: SpecData file not found: %s', specDataFile);
        end

    catch ME
        warning('showSleepScoreOverview: failed to load/process "%s": %s', fullProcPath, ME.message);
        emg_t = [];
        emg_y = [];
        T = []; F = []; Sspec = [];
        isNormSpec = false;
    end
else
    if nargin >= 4 && ~isempty(procDataFileID)
        warning('showSleepScoreOverview: procData file not found: "%s"', procDataFileID);
    end
end

% -------------------------------------------------------------------------
% Create/reuse overview figure
% -------------------------------------------------------------------------
overviewFig = findall(0,'Type','figure','Tag','SleepScoreOverviewFig');
if isempty(overviewFig)
    overviewFig = figure('Name','Sleep score overview', ...
        'NumberTitle','off',          ...
        'Color','w',                  ...
        'Tag','SleepScoreOverviewFig');
else
    figure(overviewFig); clf(overviewFig);
end

ax1 = subplot(2,1,1,'Parent',overviewFig);
ax2 = subplot(2,1,2,'Parent',overviewFig);

% -------------------------------------------------------------------------
% Top panel: EMG power + sleep-state band
% -------------------------------------------------------------------------
axes(ax1); hold(ax1,'on');
if ~isempty(emg_t) && ~isempty(emg_y) && any(~isnan(emg_y))
    plot(ax1, emg_t, emg_y, 'Color',[0.2 0.2 0.2], 'LineWidth',1);
    xlim(ax1,[0, trialDuration]);
    ylabel(ax1,'EMG power');
else
    xlim(ax1,[0, trialDuration]);
    ylabel(ax1,'EMG power');
    text(ax1, trialDuration*0.5, 0, 'EMG data not available', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.5 0.5 0.5],'FontAngle','italic');
end
set(ax1,'XTickLabel',[]);
box(ax1,'on');
addSleepBandsOutsideAxis(ax1, stateNum, tEdges, trialDuration);

% -------------------------------------------------------------------------
% Bottom panel: spectrogram + sleep-state band
%   Style matched to Generate_SleepScoringFigure_Analog
% -------------------------------------------------------------------------
axes(ax2); hold(ax2,'on');
if ~isempty(Sspec) && ~isempty(T) && ~isempty(F)
    if isNormSpec
        % normS style: Δpower (% baseline), CLim [-100 100]
        Splot = 100 * Sspec;
        imagesc(ax2, T, F, Splot);
        axis(ax2,'xy');
        set(ax2,'CLim',[-100 100]);

        cb = colorbar(ax2);
        ylabel(cb,'\Delta power (% of baseline)');
    else
        % Raw S: convert to dB and use robust CLim
        Sdb = 10*log10(Sspec + eps);
        imagesc(ax2, T, F, Sdb);
        axis(ax2,'xy');

        p = prctile(Sdb(:),[5 95]);
        if all(isfinite(p))
            set(ax2,'CLim',p);
        end

        cb = colorbar(ax2);
        ylabel(cb,'Power (dB)');
    end

    % Log-frequency axis and ticks (as in Generate_SleepScoringFigure_Analog)
    set(ax2,'YScale','log');

    candTicks = [1 2 4 8 15 30 60 80];
    candTicks = candTicks(candTicks >= min(F) & candTicks <= max(F));
    if isempty(candTicks)
        candTicks = [min(F) max(F)];
    end
    set(ax2,'YTick',candTicks, ...
        'YTickLabel',arrayfun(@num2str,candTicks,'UniformOutput',false));

    ylabel(ax2,'Freq (Hz)');
    xlim(ax2,[0, trialDuration]);
    xlabel(ax2,'Time (s)');

else
    xlim(ax2,[0, trialDuration]);
    xlabel(ax2,'Time (s)');
    ylabel(ax2,'Freq (Hz)');
    text(ax2, trialDuration*0.5, 0.5, 'Spectrogram not available', ...
        'HorizontalAlignment','center','VerticalAlignment','middle', ...
        'Color',[0.5 0.5 0.5],'FontAngle','italic');
end
box(ax2,'on');
addSleepBandsOutsideAxis(ax2, stateNum, tEdges, trialDuration);

% Link x-axes and enforce same width
linkaxes([ax1,ax2],'x');
xlim(ax1,[0 trialDuration]);
ax1Pos = get(ax1,'Position');
ax2Pos = get(ax2,'Position');
ax2Pos(1) = ax1Pos(1);
ax2Pos(3) = ax1Pos(3);
set(ax2,'Position',ax2Pos);

% -------------------------------------------------------------------------
% Summary stats in title
% -------------------------------------------------------------------------
validMask = ~isnan(stateNum);
nValid    = sum(validMask);
pctNot = NaN; pctNREM = NaN; pctREM = NaN;
if nValid > 0
    pctNot  = 100*sum(stateNum(validMask) == 0)/nValid;
    pctNREM = 100*sum(stateNum(validMask) == 1)/nValid;
    pctREM  = 100*sum(stateNum(validMask) == 2)/nValid;
end

if nargin >= 4 && ~isempty(procDataFileID)
    [~,baseName,~] = fileparts(strtrim(procDataFileID));
else
    baseName = 'Current file';
end

if nValid > 0
    sgtitle(overviewFig, sprintf('%s  |  Not Sleep: %.1f%%%%   NREM: %.1f%%%%   REM: %.1f%%%%', ...
        baseName, pctNot, pctNREM, pctREM));
else
    sgtitle(overviewFig, sprintf('%s  |  No bins labeled yet.', baseName));
end
end


function addSleepBandsOutsideAxis(ax, stateNum, tEdges, trialDuration)
% Create a thin axis above 'ax' and draw colored rectangles
% representing sleep states across time.

if isempty(stateNum) || isempty(tEdges)
    return;
end

fig = ancestor(ax,'figure');
axPos = get(ax,'Position');  % normalized [x y w h]

bandFrac = 0.08;
bandH    = bandFrac*axPos(4);
bandY = axPos(2) + axPos(4) + 0.01;
if bandY + bandH > 0.98
    bandY = min(bandY, 0.98 - bandH);
end
bandPos = [axPos(1), bandY, axPos(3), bandH];

bandAx = axes('Parent',fig, 'Position',bandPos);
hold(bandAx,'on');
xlim(bandAx,[0 trialDuration]);
ylim(bandAx,[0 1]);
axis(bandAx,'off');

cNot  = [0.80 0.80 0.80];
cNREM = [0.30 0.70 1.00];
cREM  = [1.00 0.40 0.40];

currState = NaN;
segStart  = 1;

for i = 1:numel(stateNum)+1
    if i <= numel(stateNum)
        sVal = stateNum(i);
    else
        sVal = NaN;
    end

    if i == 1
        currState = sVal;
        segStart  = 1;
    else
        if sVal ~= currState
            if ~isnan(currState)
                t1 = tEdges(segStart);
                t2 = tEdges(i);
                switch currState
                    case 0, c = cNot;
                    case 1, c = cNREM;
                    case 2, c = cREM;
                    otherwise, c = [];
                end
                if ~isempty(c)
                    patch(bandAx, [t1 t2 t2 t1], [0 0 1 1], c, ...
                        'FaceAlpha',0.7, 'EdgeColor','none', ...
                        'HitTest','off','PickableParts','none');
                end
            end
            currState = sVal;
            segStart  = i;
        end
    end
end

linkaxes([ax bandAx],'x');
end

%% ========================================================================
%%                    NEW: persistent highlight for bulk regions
%% ========================================================================
function markBulkRegion(figHandle, ax4, ax6, s, e, allDur_s)
% Mark [s,e] seconds on ax4 and ax6 with a semi-transparent patch.
% Only the last region is kept (previous ones are deleted).

if e < s
    tmp = s; s = e; e = tmp;
end
s = max(0, s);
e = min(allDur_s, e);
if e <= s, return; end

% delete any previous bulk region patches
oldPatches = findall(figHandle,'Tag','BulkLabelRegion');
if ~isempty(oldPatches)
    delete(oldPatches);
end

% colors
c4 = [0.1 0.7 0.9];   % light cyan
c6 = [0.9 0.6 0.1];   % light orange

if ishghandle(ax4)
    axes(ax4); hold(ax4,'on');
    yl4 = get(ax4,'YLim');
    patch('Parent',ax4, ...
        'XData',[s e e s], ...
        'YData',[yl4(1) yl4(1) yl4(2) yl4(2)], ...
        'FaceColor',c4, 'FaceAlpha',0.12, ...
        'EdgeColor','none', ...
        'Tag','BulkLabelRegion', ...
        'HitTest','off','PickableParts','none');
end

if ishghandle(ax6)
    axes(ax6); hold(ax6,'on');
    yl6 = get(ax6,'YLim');
    patch('Parent',ax6, ...
        'XData',[s e e s], ...
        'YData',[yl6(1) yl6(1) yl6(2) yl6(2)], ...
        'FaceColor',c6, 'FaceAlpha',0.10, ...
        'EdgeColor','none', ...
        'Tag','BulkLabelRegion', ...
        'HitTest','off','PickableParts','none');
end
end

%% ========================================================================
%%                    Click-to-zoom helpers
%% ========================================================================
function enableClickZoom(figHandle, ax4, ax6, allDur_s, turnOn)
if turnOn
    try
        zoom(figHandle,'off');
        pan(figHandle,'off');
        brush(figHandle,'off');
        datacursormode(figHandle,'off');
    catch
    end
    if ~isappdata(figHandle,'oldWbdf')
        setappdata(figHandle,'oldWbdf', get(figHandle,'WindowButtonDownFcn'));
    end
    set(figHandle,'WindowButtonDownFcn', @(src,evt) clickZoomHandler(src, ax4, ax6, allDur_s));
else
    if isappdata(figHandle,'oldWbdf')
        oldf = getappdata(figHandle,'oldWbdf');
        set(figHandle,'WindowButtonDownFcn', oldf);
        rmappdata(figHandle,'oldWbdf');
    else
        set(figHandle,'WindowButtonDownFcn', '');
    end
    try
        z = zoom(figHandle);
        z.Motion = 'horizontal';
        z.Enable = 'on';
    catch
    end
end
end

function clickZoomHandler(src, ax4, ax6, allDur_s)
stype = get(src,'SelectionType');
ax = ancestor(hittest(src),'axes');
if isempty(ax) || (~isequal(ax,ax4) && ~isequal(ax,ax6))
    ax = ax4;
end
cp = get(ax,'CurrentPoint');  cx = cp(1,1);

xl = get(ax4,'XLim'); currW = diff(xl);

switch stype
    case 'normal', w = 500;
    case 'open',   w = max(100, currW/2);
    case 'alt',    w = min(allDur_s, currW*2);
    case 'extend', w = 200;
    otherwise,     w = currW;
end

x1 = max(0, cx - w/2);
x2 = min(allDur_s, cx + w/2);
if x1 == 0, x2 = min(allDur_s, x1 + w); end
if x2 == allDur_s, x1 = max(0, x2 - w); end
set(ax4,'XLim',[x1 x2]);
set(ax6,'XLim',[x1 x2]);
drawnow;
end

%% ========================================================================
%%                    Misc helpers
%% ========================================================================
function W = mergeTouchingWindows(W)
if isempty(W), return; end
W = sortrows(W,1);
out = W(1,:);
for i = 2:size(W,1)
    last = out(end,:); curr = W(i,:);
    if curr(1) <= last(2)
        out(end,2) = max(last(2), curr(2));
    else
        out = [out; curr]; %#ok<AGROW>
    end
end
W = out;
end

function behavioralState = markBinsAsEmpty(startIdx, binsToScore, behavioralState)
for ii = startIdx:numel(binsToScore)
    brem = binsToScore(ii);
    behavioralState{brem,1} = 'Not Sleep';
end
end


function behavioralState = setBetweenAsEmpty(betweenIdx, binsToScore, behavioralState)
for idx = betweenIdx
    bmid = binsToScore(idx);
    behavioralState{bmid,1} = [];
end
end

function [jumpBi, betweenIdx] = pickJumpOnPlot(figHandle, allDur_s, binsToScore, bi, binWidth_s)
figure(figHandle);
[t,~,~] = ginput(1);
if isempty(t), jumpBi = []; betweenIdx = []; return; end
t = max(0, min(t, allDur_s));
targetBin = max(1, ceil(t / binWidth_s));
jumpBi = find(binsToScore >= targetBin, 1, 'first');
if isempty(jumpBi)
    betweenIdx = (bi+1):numel(binsToScore);
    return;
end
if jumpBi > bi
    betweenIdx = (bi+1):(jumpBi-1);
else
    betweenIdx = [];
end
end

function [jumpBi, betweenIdx] = pickJumpByTime(figHandle, allDur_s, binsToScore, bi, binWidth_s)
defaultT = num2str(binsToScore(bi) * binWidth_s);
answer = inputdlg('Jump start time (seconds):','Jump',[1 35],{defaultT});
if isempty(answer), jumpBi = []; betweenIdx = []; return; end
t = str2double(answer{1});
if isnan(t), jumpBi = []; betweenIdx = []; return; end
t = max(0, min(t, allDur_s));
targetBin = max(1, ceil(t / binWidth_s));
jumpBi = find(binsToScore >= targetBin, 1, 'first');
if isempty(jumpBi)
    betweenIdx = (bi+1):numel(binsToScore);
    return
end
if jumpBi > bi
    betweenIdx = (bi+1):(jumpBi-1);
else
    betweenIdx = [];
end
end

function [ok, selLabel, s, e] = bulkLabelPlotDialog(figHandle, ax4, ax6, allDur_s)
ok = false; selLabel = ''; s = []; e = [];

[indx, tf] = listdlg('PromptString','Choose label:', ...
    'SelectionMode','single', ...
    'ListString',{'Not Sleep','NREM Sleep','REM Sleep'}, ...
    'InitialValue',1,'ListSize',[180 90]);
if ~tf, return; end
labels = {'Not Sleep','NREM Sleep','REM Sleep'};
selLabel = labels{indx};

figure(figHandle);
[x1,~,~] = ginput(1); if isempty(x1), return; end
[x2,~,~] = ginput(1); if isempty(x2), return; end
s = x1; e = x2;
if e < s, tmp = s; s = e; e = tmp; end
s = max(0, s); e = min(allDur_s, e);

try
    axes(ax4); hold(ax4,'on');
    yl = get(ax4,'YLim');
    p = patch([s e e s],[yl(1) yl(1) yl(2) yl(2)], [0 0 0], ...
        'FaceAlpha',0.07, 'EdgeColor','none','HandleVisibility','off');
    drawnow; pause(0.15); if isgraphics(p), delete(p); end
catch
end

ok = true;
end

function [ok, selLabel, s, e] = bulkLabelTimeDialog(figHandle, allDur_s)
ok = false; selLabel = ''; s = []; e = [];

[indx, tf] = listdlg('PromptString','Choose label:', ...
    'SelectionMode','single', ...
    'ListString',{'Not Sleep','NREM Sleep','REM Sleep'}, ...
    'InitialValue',1,'ListSize',[180 90]);
if ~tf, return; end %#ok<*NOPRT>
labels = {'Not Sleep','NREM Sleep','REM Sleep'};
selLabel = labels{indx};

answ = inputdlg({'Start time (s):','End time (s):'}, ...
    'Bulk label (time)',[1 28], {'0', num2str(allDur_s)});
if isempty(answ), return; end
s = str2double(answ{1}); e = str2double(answ{2});
if isnan(s) || isnan(e), return; end
if e < s, tmp = s; s = e; e = tmp; end
s = max(0, s); e = min(allDur_s, e);

ok = true;
end

function behavioralState = applyBulkLabel(behavioralState, s, e, binsToScore, numBins, selLabel, binWidth_s)
bStart = max(1, floor(s / binWidth_s) + 1);
bEnd   = min(numBins, ceil(e / binWidth_s));

if ~isempty(binsToScore) && numel(binsToScore) < numBins
    mask       = ismember(bStart:bEnd, binsToScore);
    targetBins = (bStart:bEnd);
    targetBins = targetBins(mask);
else
    targetBins = bStart:bEnd;
end

for bb = targetBins
    behavioralState{bb,1} = selLabel;
end
end

function forceCloseSelector(figHandle)
try
    if ishghandle(figHandle) && isappdata(figHandle,'selGUIsCaptured')
        h = getappdata(figHandle,'selGUIsCaptured');
        h = h(ishghandle(h));
        for k = 1:numel(h)
            try
                set(h(k),'CloseRequestFcn','');
                delete(h(k));
            catch
            end
        end
        rmappdata(figHandle,'selGUIsCaptured');
    end

    strayTag = findall(0,'Type','figure','Tag','SelectSleepStateGUI');
    strayTag = strayTag(ishghandle(strayTag));
    arrayfun(@(hh) delete(hh), strayTag);

    strayName = findall(0,'Type','figure','-regexp','Name','Select.*Sleep|Sleep.*State');
    strayName = strayName(ishghandle(strayName));
    arrayfun(@(hh) delete(hh), strayName);
catch
end
end

function openSleepSelectorAndCapture(figHandle)
preFigs  = findall(0,'Type','figure');
SelectSleepState_GUI;
drawnow; pause(0.05);
postFigs = findall(0,'Type','figure');
selGUIs  = setdiff(postFigs, preFigs);

if ~isempty(selGUIs)
    if isappdata(figHandle,'selGUIsCaptured')
        old = getappdata(figHandle,'selGUIsCaptured');
        selGUIs = [old(:); selGUIs(:)];
        selGUIs = selGUIs(ishghandle(selGUIs));
        selGUIs = unique(selGUIs,'stable');
    end
    setappdata(figHandle,'selGUIsCaptured', selGUIs);
end
end

function freezeLegends(figHandle)
try
    L = findobj(figHandle,'Type','Legend');
    for k = 1:numel(L)
        if isprop(L(k),'AutoUpdate')
            set(L(k),'AutoUpdate','off');
        end
    end
    try
        set(groot,'defaultLegendAutoUpdate','off');
    catch
    end
catch
end
end