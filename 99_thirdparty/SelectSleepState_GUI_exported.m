classdef SelectSleepState_GUI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        figure1                     matlab.ui.Figure
        Aa1AwakeNn2NREMRr3REMLabel  matlab.ui.control.Label
        SelectthebuttonsorpresskeyboardLabel  matlab.ui.control.Label
        CloseButton                 matlab.ui.control.StateButton
        text2                       matlab.ui.control.Label
        togglebutton3               matlab.ui.control.StateButton
        togglebutton2               matlab.ui.control.StateButton
        togglebutton1               matlab.ui.control.StateButton
    end

    
    methods (Access = private)
        function varargout = gui_mainfcn(app, gui_State, varargin)
            
            gui_StateFields =  {'gui_Name'
                'gui_Singleton'
                'gui_OpeningFcn'
                'gui_OutputFcn'
                'gui_LayoutFcn'
                'gui_Callback'};
            gui_Mfile = '';
            for i=1:length(gui_StateFields)
                if ~isfield(gui_State, gui_StateFields{i})
                    error(message('MATLAB:guide:StateFieldNotFound', gui_StateFields{ i }, gui_Mfile));
                elseif isequal(gui_StateFields{i}, 'gui_Name')
                    gui_Mfile = [gui_State.(gui_StateFields{i}), '.m'];
                end
            end
            
            numargin = length(varargin);
            
            if numargin == 0
                % SELECTBEHAVIORALSTATEGUI_JNEUROSCI2022
                % create the GUI only if we are not in the process of loading it
                % already
                gui_Create = true;
            elseif local_isInvokeActiveXCallback(app, gui_State, varargin{:})
                % SELECTBEHAVIORALSTATEGUI_JNEUROSCI2022(ACTIVEX,...)
                vin{1} = gui_State.gui_Name;
                vin{2} = [get(varargin{1}.Peer, 'Tag'), '_', varargin{end}];
                vin{3} = varargin{1};
                vin{4} = varargin{end-1};
                vin{5} = guidata(varargin{1}.Peer);
                feval(vin{:});
                return;
            elseif local_isInvokeHGCallback(app, gui_State, varargin{:})
                % SELECTBEHAVIORALSTATEGUI_JNEUROSCI2022('CALLBACK',hObject,eventData,handles,...)
                gui_Create = false;
            else
                % SELECTBEHAVIORALSTATEGUI_JNEUROSCI2022(...)
                % create the GUI and hand varargin to the openingfcn
                gui_Create = true;
            end
            
            if ~gui_Create
                % In design time, we need to mark all components possibly created in
                % the coming callback evaluation as non-serializable. This way, they
                % will not be brought into GUIDE and not be saved in the figure file
                % when running/saving the GUI from GUIDE.
                designEval = false;
                if (numargin>1 && ishghandle(varargin{2}))
                    fig = varargin{2};
                    while ~isempty(fig) && ~ishghandle(fig,'figure')
                        fig = get(fig,'parent');
                    end
            
                    designEval = isappdata(0,'CreatingGUIDEFigure') || (isscalar(fig)&&isprop(fig,'GUIDEFigure'));
                end
            
                if designEval
                    beforeChildren = findall(fig);
                end
            
                % evaluate the callback now
                varargin{1} = gui_State.gui_Callback;
                if nargout
                    [varargout{1:nargout}] = feval(varargin{:});
                else
                    feval(varargin{:});
                end
            
                % Set serializable of objects created in the above callback to off in
                % design time. Need to check whether figure handle is still valid in
                % case the figure is deleted during the callback dispatching.
                if designEval && ishghandle(fig)
                    set(setdiff(findall(fig),beforeChildren), 'Serializable','off');
                end
            else
                if gui_State.gui_Singleton
                    gui_SingletonOpt = 'reuse';
                else
                    gui_SingletonOpt = 'new';
                end
            
                % Check user passing 'visible' P/V pair first so that its value can be
                % used by oepnfig to prevent flickering
                gui_Visible = 'auto';
                gui_VisibleInput = '';
                for index=1:2:length(varargin)
                    if length(varargin) == index || ~ischar(varargin{index})
                        break;
                    end
            
                    % Recognize 'visible' P/V pair
                    len1 = min(length('visible'),length(varargin{index}));
                    len2 = min(length('off'),length(varargin{index+1}));
                    if ischar(varargin{index+1}) && strncmpi(varargin{index},'visible',len1) && len2 > 1
                        if strncmpi(varargin{index+1},'off',len2)
                            gui_Visible = 'invisible';
                            gui_VisibleInput = 'off';
                        elseif strncmpi(varargin{index+1},'on',len2)
                            gui_Visible = 'visible';
                            gui_VisibleInput = 'on';
                        end
                    end
                end
            
                % Open fig file with stored settings.  Note: This executes all component
                % specific CreateFunctions with an empty HANDLES structure.
            
            
                % Do feval on layout code in m-file if it exists
                gui_Exported = ~isempty(gui_State.gui_LayoutFcn);
                % this application data is used to indicate the running mode of a GUIDE
                % GUI to distinguish it from the design mode of the GUI in GUIDE. it is
                % only used by actxproxy at this time.
                setappdata(0,genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]),1);
                if gui_Exported
                    gui_hFigure = feval(gui_State.gui_LayoutFcn, gui_SingletonOpt);
            
                    % make figure invisible here so that the visibility of figure is
                    % consistent in OpeningFcn in the exported GUI case
                    if isempty(gui_VisibleInput)
                        gui_VisibleInput = get(gui_hFigure,'Visible');
                    end
                    set(gui_hFigure,'Visible','off')
            
                    % openfig (called by local_openfig below) does this for guis without
                    % the LayoutFcn. Be sure to do it here so guis show up on screen.
                    movegui(gui_hFigure,'onscreen');
                else
                    gui_hFigure = local_openfig(app, gui_State.gui_Name, gui_SingletonOpt, gui_Visible);
                    % If the figure has InGUIInitialization it was not completely created
                    % on the last pass.  Delete this handle and try again.
                    if isappdata(gui_hFigure, 'InGUIInitialization')
                        delete(gui_hFigure);
                        gui_hFigure = local_openfig(app, gui_State.gui_Name, gui_SingletonOpt, gui_Visible);
                    end
                end
                if isappdata(0, genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]))
                    rmappdata(0,genvarname(['OpenGuiWhenRunning_', gui_State.gui_Name]));
                end
            
                % Set flag to indicate starting GUI initialization
                setappdata(gui_hFigure,'InGUIInitialization',1);
            
                % Fetch GUIDE Application options
                gui_Options = getappdata(gui_hFigure,'GUIDEOptions');
                % Singleton setting in the GUI MATLAB code file takes priority if different
                gui_Options.singleton = gui_State.gui_Singleton;
            
                if ~isappdata(gui_hFigure,'GUIOnScreen')
                    % Adjust background color
                    if gui_Options.syscolorfig
                        set(gui_hFigure,'Color', get(0,'DefaultUicontrolBackgroundColor'));
                    end
            
                    % Generate HANDLES structure and store with GUIDATA. If there is
                    % user set GUI data already, keep that also.
                    data = guidata(gui_hFigure);
                    handles = guihandles(gui_hFigure);
                    if ~isempty(handles)
                        if isempty(data)
                            data = handles;
                        else
                            names = fieldnames(handles);
                            for k=1:length(names)
                                data.(char(names(k)))=handles.(char(names(k)));
                            end
                        end
                    end
                    guidata(gui_hFigure, data);
                end
            
                % Apply input P/V pairs other than 'visible'
                for index=1:2:length(varargin)
                    if length(varargin) == index || ~ischar(varargin{index})
                        break;
                    end
            
                    len1 = min(length('visible'),length(varargin{index}));
                    if ~strncmpi(varargin{index},'visible',len1)
                        try set(gui_hFigure, varargin{index}, varargin{index+1}), catch break, end
                    end
                end
            
                % If handle visibility is set to 'callback', turn it on until finished
                % with OpeningFcn
                gui_HandleVisibility = get(gui_hFigure,'HandleVisibility');
                if strcmp(gui_HandleVisibility, 'callback')
                    set(gui_hFigure,'HandleVisibility', 'on');
                end
            
                feval(gui_State.gui_OpeningFcn, gui_hFigure, [], guidata(gui_hFigure), varargin{:});
            
                if isscalar(gui_hFigure) && ishghandle(gui_hFigure)
                    % Handle the default callbacks of predefined toolbar tools in this
                    % GUI, if any
                    guidemfile('restoreToolbarToolPredefinedCallback',gui_hFigure);
            
                    % Update handle visibility
                    set(gui_hFigure,'HandleVisibility', gui_HandleVisibility);
            
                    % Call openfig again to pick up the saved visibility or apply the
                    % one passed in from the P/V pairs
                    if ~gui_Exported
                        gui_hFigure = local_openfig(app, gui_State.gui_Name, 'reuse',gui_Visible);
                    elseif ~isempty(gui_VisibleInput)
                        set(gui_hFigure,'Visible',gui_VisibleInput);
                    end
                    if strcmpi(get(gui_hFigure, 'Visible'), 'on')
                        figure(gui_hFigure);
            
                        if gui_Options.singleton
                            setappdata(gui_hFigure,'GUIOnScreen', 1);
                        end
                    end
            
                    % Done with GUI initialization
                    if isappdata(gui_hFigure,'InGUIInitialization')
                        rmappdata(gui_hFigure,'InGUIInitialization');
                    end
            
                    % If handle visibility is set to 'callback', turn it on until
                    % finished with OutputFcn
                    gui_HandleVisibility = get(gui_hFigure,'HandleVisibility');
                    if strcmp(gui_HandleVisibility, 'callback')
                        set(gui_hFigure,'HandleVisibility', 'on');
                    end
                    gui_Handles = guidata(gui_hFigure);
                else
                    gui_Handles = [];
                end
            
                if nargout
                    [varargout{1:nargout}] = feval(gui_State.gui_OutputFcn, gui_hFigure, [], gui_Handles);
                else
                    feval(gui_State.gui_OutputFcn, gui_hFigure, [], gui_Handles);
                end
            
                if isscalar(gui_hFigure) && ishghandle(gui_hFigure)
                    set(gui_hFigure,'HandleVisibility', gui_HandleVisibility);
                end
            end
        end
        
        function local_CreateFcn(app, hObject, eventdata, createfcn, appdata)
            
            if ~isempty(appdata)
               names = fieldnames(appdata);
               for i=1:length(names)
                   name = char(names(i));
                   setappdata(hObject, name, getfield(appdata,name));
               end
            end
            
            if ~isempty(createfcn)
               if isa(createfcn,'function_handle')
                   createfcn(hObject, eventdata);
               else
                   eval(createfcn);
               end
            end
        end
        
        function result = local_isInvokeActiveXCallback(app, gui_State, varargin)
            
            try
                result = ispc && iscom(varargin{1}) ...
                         && isequal(varargin{1},gcbo);
            catch
                result = false;
            end
        end
        
        function result = local_isInvokeHGCallback(app, gui_State, varargin)
            
            try
                fhandle = functions(gui_State.gui_Callback);
                result = ~isempty(findstr(gui_State.gui_Name,fhandle.file)) || ...
                         (ischar(varargin{1}) ...
                         && isequal(ishghandle(varargin{2}), 1) ...
                         && (~isempty(strfind(varargin{1},[get(varargin{2}, 'Tag'), '_'])) || ...
                            ~isempty(strfind(varargin{1}, '_CreateFcn'))) );
            catch
                result = false;
            end
        end
        
        function gui_hFigure = local_openfig(app, name, singleton, visible)
            
            % openfig with three arguments was new from R13. Try to call that first, if
            % failed, try the old openfig.
            if nargin('openfig') == 2
                % OPENFIG did not accept 3rd input argument until R13,
                % toggle default figure visible to prevent the figure
                % from showing up too soon.
                gui_OldDefaultVisible = get(0,'defaultFigureVisible');
                set(0,'defaultFigureVisible','off');
                gui_hFigure = matlab.hg.internal.openfigLegacy(name, singleton);
                set(0,'defaultFigureVisible',gui_OldDefaultVisible);
            else
                % Call version of openfig that accepts 'auto' option"
                gui_hFigure = matlab.hg.internal.openfigLegacy(name, singleton, visible);
            %     %workaround for CreateFcn not called to create ActiveX
            %         peers=findobj(findall(allchild(gui_hFigure)),'type','uicontrol','style','text');
            %         for i=1:length(peers)
            %             if isappdata(peers(i),'Control')
            %                 actxproxy(peers(i));
            %             end
            %         end
            end
        end
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function SelectBehavioralStateGUI_OpeningFcn(app, varargin)
            % Ensure that the app appears on screen when run
            global buttonState %#ok<GVMIS>
            buttonState = 0;
            global ButtonValue %#ok<GVMIS>
            ButtonValue = 0;
                        movegui(app.figure1, 'onscreen');

            % Create GUIDE-style callback args - Added by Migration Tool
            [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app); %#ok<ASGLU>
            
            % This function has no output args, see OutputFcn.
            % hObject    handle to figure
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            % varargin   command line arguments to SelectBehavioralStateGUI_IOS (see VARARGIN)
            
            % Choose default command line output for SelectBehavioralStateGUI_IOS
            handles.output = hObject;
            
            % Update handles structure
            guidata(hObject, handles);
        end

        % Value changed function: togglebutton1
        function togglebutton1_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
%             [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            global ButtonValue %#ok<GVMIS>
            global closeButtonState %#ok<GVMIS>

            ButtonValue = 1;
            % hObject    handle to togglebutton1 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            ButtonSelect_IOS
%                         delete(app)
            if closeButtonState == 1
                        delete(app)
            end
        end

        % Value changed function: togglebutton2
        function togglebutton2_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
%             [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            global ButtonValue %#ok<GVMIS>
            global closeButtonState %#ok<GVMIS>

            ButtonValue = 2;
            % hObject    handle to togglebutton2 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            ButtonSelect_IOS
%                         delete(app)
            if closeButtonState == 1
                        delete(app)
            end
        end

        % Value changed function: togglebutton3
        function togglebutton3_Callback(app, event)
            % Create GUIDE-style callback args - Added by Migration Tool
%             [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            global ButtonValue %#ok<GVMIS>
            global closeButtonState %#ok<GVMIS>

            ButtonValue = 3;
            % hObject    handle to togglebutton3 (see GCBO)
            % eventdata  reserved - to be defined in a future version of MATLAB
            % handles    structure with handles and user data (see GUIDATA)
            ButtonSelect_IOS
%                         delete(app)
            if closeButtonState == 1
                        delete(app)
            end
        end

        % Window key press function: figure1
        function figure1WindowKeyPress(app, event)
            ButtonSelect_IOS
%             [hObject, eventdata, handles] = convertToGUIDECallbackArguments(app, event); %#ok<ASGLU>
            global ButtonValue %#ok<GVMIS>
            global closeButtonState %#ok<GVMIS>

            Key =  event.Character;
            switch Key
                case 'a'
                                ButtonValue = 1;
                case 'n'
                                ButtonValue = 2;
                case 'r'
                                ButtonValue = 3;
                case 'A'
                                ButtonValue = 1;
                case 'N'
                                ButtonValue = 2;
                case 'R'
                                ButtonValue = 3;
                case '1'
                                ButtonValue = 1;
                case '2'
                                ButtonValue = 2;       
                case '3'
                                ButtonValue = 3;
                otherwise 
                                warndlg('Please select of the buttons or type an appropriate letter','Warning');
                                global buttonState %#ok<GVMIS>
                                buttonState = 0;
                                ButtonValue = 0;
            end
            if closeButtonState == 1
                        delete(app)
            end

        end

        % Close request function: figure1
        function figure1CloseRequest(app, event)
            warndlg('Please select of the buttons or type an appropriate letter before closing GUI','Warning');
            global ButtonValue %#ok<GVMIS>
            if ButtonValue ~= 0
            delete(app)
            end            
        end

        % Value changed function: CloseButton
        function CloseButtonValueChanged(app, event)
                delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create figure1 and hide until all components are created
            app.figure1 = uifigure('Visible', 'off');
            app.figure1.Position = [680 915 573 194];
            app.figure1.Name = 'SelectSleepStage';
            app.figure1.Resize = 'off';
            app.figure1.CloseRequestFcn = createCallbackFcn(app, @figure1CloseRequest, true);
            app.figure1.WindowKeyPressFcn = createCallbackFcn(app, @figure1WindowKeyPress, true);
            app.figure1.HandleVisibility = 'callback';
            app.figure1.Tag = 'FigureX';

            % Create togglebutton1
            app.togglebutton1 = uibutton(app.figure1, 'state');
            app.togglebutton1.ValueChangedFcn = createCallbackFcn(app, @togglebutton1_Callback, true);
            app.togglebutton1.Tag = 'togglebutton1';
            app.togglebutton1.Text = 'Not Sleep';
            app.togglebutton1.BackgroundColor = [0 0 0];
            app.togglebutton1.FontName = 'Arial';
            app.togglebutton1.FontSize = 24;
            app.togglebutton1.FontColor = [1 1 1];
            app.togglebutton1.Position = [25 55 140 52];

            % Create togglebutton2
            app.togglebutton2 = uibutton(app.figure1, 'state');
            app.togglebutton2.ValueChangedFcn = createCallbackFcn(app, @togglebutton2_Callback, true);
            app.togglebutton2.Tag = 'togglebutton2';
            app.togglebutton2.Text = 'NREM Sleep';
            app.togglebutton2.BackgroundColor = [0 0 1];
            app.togglebutton2.FontName = 'Arial';
            app.togglebutton2.FontSize = 24;
            app.togglebutton2.FontColor = [1 1 1];
            app.togglebutton2.Position = [203 55 162 52];

            % Create togglebutton3
            app.togglebutton3 = uibutton(app.figure1, 'state');
            app.togglebutton3.ValueChangedFcn = createCallbackFcn(app, @togglebutton3_Callback, true);
            app.togglebutton3.Tag = 'togglebutton3';
            app.togglebutton3.Text = 'REM Sleep';
            app.togglebutton3.BackgroundColor = [1 0 0];
            app.togglebutton3.FontName = 'Arial';
            app.togglebutton3.FontSize = 24;
            app.togglebutton3.FontColor = [1 1 1];
            app.togglebutton3.Position = [409 55 142 52];

            % Create text2
            app.text2 = uilabel(app.figure1);
            app.text2.Tag = 'text2';
            app.text2.HorizontalAlignment = 'center';
            app.text2.VerticalAlignment = 'top';
            app.text2.WordWrap = 'on';
            app.text2.FontName = 'Arial';
            app.text2.FontSize = 30;
            app.text2.Position = [82 115 414 39];
            app.text2.Text = 'Select Behavioral State';

            % Create CloseButton
            app.CloseButton = uibutton(app.figure1, 'state');
            app.CloseButton.ValueChangedFcn = createCallbackFcn(app, @CloseButtonValueChanged, true);
            app.CloseButton.Text = 'Close';
            app.CloseButton.BackgroundColor = [0.7176 0.2745 1];
            app.CloseButton.FontName = 'Arial';
            app.CloseButton.FontSize = 18;
            app.CloseButton.FontColor = [1 1 1];
            app.CloseButton.Position = [252 157 66 29];

            % Create SelectthebuttonsorpresskeyboardLabel
            app.SelectthebuttonsorpresskeyboardLabel = uilabel(app.figure1);
            app.SelectthebuttonsorpresskeyboardLabel.HorizontalAlignment = 'center';
            app.SelectthebuttonsorpresskeyboardLabel.FontWeight = 'bold';
            app.SelectthebuttonsorpresskeyboardLabel.FontColor = [1 0 0];
            app.SelectthebuttonsorpresskeyboardLabel.Position = [174 27 221 23];
            app.SelectthebuttonsorpresskeyboardLabel.Text = 'Select the buttons or press keyboard';

            % Create Aa1AwakeNn2NREMRr3REMLabel
            app.Aa1AwakeNn2NREMRr3REMLabel = uilabel(app.figure1);
            app.Aa1AwakeNn2NREMRr3REMLabel.HorizontalAlignment = 'center';
            app.Aa1AwakeNn2NREMRr3REMLabel.FontColor = [0 0 1];
            app.Aa1AwakeNn2NREMRr3REMLabel.Position = [169 5 232 24];
            app.Aa1AwakeNn2NREMRr3REMLabel.Text = 'A/a/1 - Awake, N/n/2 - NREM, R/r/3 - REM';

            % Show the figure after all components are created
            app.figure1.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = SelectSleepState_GUI_exported(varargin)

            runningApp = getRunningApp(app);

            % Check for running singleton app
            if isempty(runningApp)

                % Create UIFigure and components
                createComponents(app)

                % Register the app with App Designer
                registerApp(app, app.figure1)

                % Execute the startup function
                runStartupFcn(app, @(app)SelectBehavioralStateGUI_OpeningFcn(app, varargin{:}))
            else

                % Focus the running singleton app
                figure(runningApp.figure1)

                app = runningApp;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.figure1)
        end
    end
end