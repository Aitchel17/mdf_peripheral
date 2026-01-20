function plot_summary(axis)
%PLOT_SUMMARY Summary of this function goes here
%   Detailed explanation goes here
    summary_fig = figure("Name", "Summary", "Units", "inches", "Position", [0 0 10 12]);
    t = tiledlayout(5,1, 'Padding', 'compact', 'TileSpacing', 'compact');
    %%
    ax_handles = gobjects(1,4);
    for i = 1:4
        ax_handles(i) = nexttile;
        text(0.5, 0.5, sprintf('Data %d', i), 'HorizontalAlignment', 'center');
        axis off;
    end



    %%
    set(axis,"Parent",t)
    %%
    axis.Layout.Tile = 5;
    %%




end

