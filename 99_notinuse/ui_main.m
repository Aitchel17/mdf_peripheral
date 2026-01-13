%%
state = ui_state();
%%
state.Stack = preprocess.raw_sleepscoringdata.eye;

%%
[~,~,TotalFrames] = size(state.Stack); 
state.Frame = 1;
UI_Shift = 0;
UI_Channels = 1;
MinIntensity = 0;
MaxIntensity = 65535;

ScreenSize = get(0, 'ScreenSize');
WindowSize = [900, 600];
LeftEdge = (ScreenSize(3) - WindowSize(1)) / 2;
BottomEdge = (ScreenSize(4) - WindowSize(2)) / 2;

FontSize = 14;
%% Define UI layout
    Window = uifigure('Name', 'Pre-Processing Console for Imaging File', 'Position', [LeftEdge, BottomEdge, WindowSize]);
    Window.WindowKeyPressFcn = @KeyPressHandler;
    MainLayout = uigridlayout(Window, [1,2]);
    MainLayout.RowHeight = {'1x'};
    MainLayout.ColumnWidth = {'1x', 'fit'};

% Display raw image file
    ImagePanel = uipanel(MainLayout, "Title", 'Raw Image state.Stack Display');
    ImagePanel.Layout.Row = 1;
    ImagePanel.Layout.Column = 1;

    ImagePanelLayout = uigridlayout(ImagePanel, [3,1]);
    ImagePanelLayout.RowHeight = {'1x', 25, 50};
    ImagePanelLayout.ColumnWidth = {'1x'};

    ax_Displaystate.Stack = uiaxes(ImagePanelLayout);
    ax_Displaystate.Stack.Layout.Row = 1;
    ax_Displaystate.Stack.Layout.Column = 1;
    Displaystate.Stack = imshow(state.Stack(:,:,state.Frame), [], 'Parent', ax_Displaystate.Stack);
    
% Define image processing parameters
    ControlPanel = uipanel(MainLayout, "Title", 'Control Panel');
    ControlPanel.Layout.Row = 1;
    ControlPanel.Layout.Column = 2;

    ControlPanelLayout = uigridlayout(ControlPanel, [3,1]);
    ControlPanelLayout.RowHeight = {'1x', 'fit', 50};
    ControlPanelLayout.ColumnWidth = {'fit'};
    

% Controls: 
% Image Panel - Title, Slider, Label
    CurrentFrame = uilabel(ImagePanelLayout, ...
                          'Text', sprintf('Frame %d/%d	Pixel Shift: %d	Total Imaging Channels: %d', state.Frame, TotalFrames, UI_Shift, UI_Channels), ...
                          'HorizontalAlignment', 'left' ... 
                          );
    CurrentFrame.Layout.Row = 2;
    CurrentFrame.Layout.Column = 1;

    FrameSlider = uislider(ImagePanelLayout, ...
                           'Limits', [1, TotalFrames], ...
                           'Value', state.Frame, ...
                           'ValueChangingFcn', @(src, event) Update_Frame(round(event.Value)) ...
                          );
    FrameSlider.Layout.Row = 3;
    FrameSlider.Layout.Column = 1;

function x  = Update_Frame(NewFrame)
    state.Frame = NewFrame;
    Displaystate.Stack.CData = state.Stack(:,:,state.Frame);
    CurrentFrame.Text = sprintf('Frame %d/%d	Pixel Shift: %d	Total Imaging Channels: %d', state.Frame, TotalFrames, UI_Shift, UI_Channels);
    FrameSlider.Value = state.Frame;
end
