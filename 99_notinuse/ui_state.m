classdef ui_state < handle
    %UI_STATE Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Stack
        TotalFrames
        Frame
        Display
        Label
        Slider_sli
        Slider_contrast
    end
    
    methods
        function obj = ui_state()
            %UI_STATE Construct an instance of this class
            %   Detailed explanation goes here
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

