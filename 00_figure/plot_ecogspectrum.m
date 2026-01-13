function plot_ecogspectrum(ecog_spectrum)
fig = figure(Name='ECoG spectrum');
ax = axes('Parent', fig);
ecog_spectrum.zdata = zeros(size(ecog_spectrum.log_norm_spectrum));
%%
surface(ax, ecog_spectrum.T, ...
    ecog_spectrum.F, ...
    zeros(size(ecog_spectrum.log_norm_spectrum)), ...
    ecog_spectrum.log_norm_spectrum, ...
    'LineStyle', 'none');

set(ax, 'YScale', 'log');
xlim(ax, [0 30]);
ylabel(ax, 'Freq (Hz)');
xlabel(ax, 'sec');
set(ax, 'FontSize', 14);
end

