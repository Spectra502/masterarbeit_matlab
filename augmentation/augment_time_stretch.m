function x_aug = augment_time_stretch(x, stretch_factor)
    % Stretches or compresses the signal
    % stretch_factor (>1 expands, <1 compresses)
    t = linspace(1, length(x), round(length(x) * stretch_factor)); % New time axis
    x_aug = interp1(1:length(x), x, t, 'linear'); % Interpolate signal
end