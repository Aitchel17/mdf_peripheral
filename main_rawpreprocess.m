%%
directory = 'G:\tmp\00_igkl\hql088\251006_hql088_whiskerb\HQL088_whiskerb251006_003_pa04';

preprocess = raw_preprocess(directory);





%%
preprocess.raw_sleepscoringdata = preprocess.loadrawdata();

%%
util_checkstack(preprocess.raw_sleepscoringdata.eye)
%%
window = uifigure();
mainlayout = uigridlayout(window, [2,1]);
mainlayout.RowHeight = {'fit', 'fit'};
mainlayout.ColumnWidth = {'1x'};
eyepanel = uipanel(mainlayout, 'Title', sprintf('draw eye roi'));
HStack = sliceViewer(ax, preprocess.raw_sleepscoringdata.eye,'Parent',eyepanel);
ax = findobj(HStack, 'Type', 'axes');
roi = drawpolygon(ax);

controlpanel = uipanel(mainlayout, 'Title', sprintf('confirmbutton'));
controlpanel.Layout.Row = 2;
controlpanel.Layout.Column = 1;

StatePanelLayout = uigridlayout(controlpanel, [1, 2]);
StatePanelLayout.RowHeight = {'fit'};
StatePanelLayout.ColumnWidth = repmat({'1x'}, 2, 1);




%%
drawbutton = uibutton(StatePanelLayout, ...
                  "Text", 'adf', ...
                  'ButtonPushedFcn', @(~, ~) drawpolygon() ...
                 );
drawbutton.Layout.Row = 2;
drawbutton.Layout.Column = 2;


%%
uicontrol(controlpanel,'Style','pushbutton','String','Nextstep', 'Callback',@(~,~) uiresume(window));

uiwait(window)
close(window)
%%

function drawpolygon()
    polygon = drawpolygon();
end