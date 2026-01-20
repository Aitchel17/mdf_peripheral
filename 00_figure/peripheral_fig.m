classdef peripheral_fig < handle
    %PERIPHERAL Fig Handle class for managing figures in sleep scoring app
    %   Mimics basic functionality of make_fig but designed for persistence
    %   and specific application needs (whisker, EMG, ECoG, etc.)

    properties
        fig
        ax
        % Figure settings
        fig_name
        monitor_xyinch = [5 5]; % Default position
        xy_sizeinch = [5 2];    % Default size
        fig_color = 'w';
        axis_color = 'k';
        fontsize = 12;
        fontname = 'Arial';
    end

    methods
        function obj = peripheral_fig(fig_name, kwargs)
            %SLEEP_FIGURE Construct an instance of this class
            %   fig_name: char, Name of the figure
            %   kwargs.Parent: Axis handle (optional). If provided, plots into this axis.
            %   kwargs.position_rect: [x y w h] in inches (optional, ignored if Parent is used)

            arguments
                fig_name char
                kwargs.Parent = [] % Axis or UIAxes handle
                kwargs.position_rect (1,4) double = [5 5 5 2]
            end

            obj.fig_name = fig_name;

            if ~isempty(kwargs.Parent) && isgraphics(kwargs.Parent)
                % Use existing axis
                obj.ax = kwargs.Parent;
                obj.fig = ancestor(obj.ax, 'figure');
                % Do NOT change position of parent figure
            else
                % Create new figure
                if isfield(kwargs, 'position_rect')
                    obj.monitor_xyinch = kwargs.position_rect(1:2);
                    obj.xy_sizeinch = kwargs.position_rect(3:4);
                end

                obj.fig = figure("Name", fig_name, "NumberTitle", "off");
                set(obj.fig, 'Units', 'inches', ...
                    "Position", [obj.monitor_xyinch(1) obj.monitor_xyinch(2) obj.xy_sizeinch(1) obj.xy_sizeinch(2)]);

                obj.initialize_axis();
            end
        end

        function initialize_axis(obj)
            if isempty(obj.ax) || ~isvalid(obj.ax)
                obj.ax = axes(obj.fig);
            end
            obj.preset_axis();
        end

        function ax_handle = get_axis_handle(obj)
            % Returns the axis handle for external GUI integration
            if isempty(obj.ax) || ~isvalid(obj.ax)
                obj.initialize_axis();
            end
            ax_handle = obj.ax;
        end

        function reset_axis(obj)
            % Resets the axis content and re-applies styling
            if ~isempty(obj.ax) && isvalid(obj.ax)
                cla(obj.ax);
                obj.preset_axis();
            end
        end

        function plot_line(obj, data, kwargs)
            %PLOT_LINE General 1D plotting (Whisker, Pupil, EMG, Force)
            %   data: 1D array
            %   Name-Value pairs:
            %       'Color': char or [r g b], default 'k'
            %       'LineWidth': double, default 1
            %       'XAxis': array, default 1:length(data)

            arguments
                obj
                data
                kwargs.Color = 'k'
                kwargs.LineWidth = 1
                kwargs.XAxis = []
            end

            if isempty(obj.ax) || ~isvalid(obj.ax); obj.initialize_axis(); end

            if isempty(kwargs.XAxis)
                x = 1:length(data);
            else
                x = kwargs.XAxis;
            end

            plot(obj.ax, x, data, 'Color', kwargs.Color, 'LineWidth', kwargs.LineWidth);

            xlim(obj.ax, [min(x) max(x)]);
            % ylim depends on data, let auto-scale handle it or set manually via helper
        end

        function plot_ecogspectrum(obj, ecog_spectrum)
            %PLOT_ECOGSPECTRUM Plots ECoG spectrogram
            %   Expects struct with fields: T, F, log_norm_spectrum

            if isempty(obj.ax) || ~isvalid(obj.ax); obj.initialize_axis(); end

            % Matches logic from plot_ecogspectrum.m
            % surface(x, y, z, c)
            surface(obj.ax, ecog_spectrum.T, ...
                ecog_spectrum.F, ...
                zeros(size(ecog_spectrum.log_norm_spectrum)), ...
                ecog_spectrum.log_norm_spectrum, ...
                'LineStyle', 'none');

            set(obj.ax, 'YScale', 'log');
            xlim(obj.ax, [min(ecog_spectrum.T) max(ecog_spectrum.T)]);
            ylabel(obj.ax, 'Freq (Hz)');
            xlabel(obj.ax, 'sec');

            % Ensure view is 2D
            view(obj.ax, 2);
        end

        function save2svg(obj, save_folder)
            %SAVE2SVG Save figure as SVG
            arguments
                obj
                save_folder char
            end

            if ~isfolder(save_folder)
                mkdir(save_folder);
            end

            filepath = fullfile(save_folder, [obj.fig_name '.svg']);
            print(obj.fig, filepath, "-dsvg", "-vector");
            fprintf('Figure saved to: %s\n', filepath);
        end

        function close(obj)
            if ~isempty(obj.fig) && isvalid(obj.fig)
                close(obj.fig);
            end
        end
    end

    methods (Access = private)
        function preset_axis(obj)
            % Standard axis styling
            set(obj.fig, 'Color', obj.fig_color);
            set(obj.ax, 'Color', 'none', ... % Transparent axis background
                'XColor', obj.axis_color, ...
                'YColor', obj.axis_color, ...
                'Box', 'off', ...
                'TickDir', 'out', ...
                'LineWidth', 1, ...
                'FontName', obj.fontname, ...
                'FontSize', obj.fontsize, ...
                'Layer', 'top');
        end
    end
end
