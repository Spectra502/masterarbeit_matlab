function plotFFTAndSave( ...
        x, Fs, rpm, gearteeth, ...
        dataset, labelStr, speedValue, torqueValue, ...
        outputFolder)
% plotFFTAndSave  Compute & save a smoothed, single‐sided FFT (dB vs. log‐freq).
% ... (rest of the help comments) ...

    % --- FIX: Prepare a "clean" version of the label for the plot title ---
    % This replaces underscores with spaces to avoid TeX interpreter errors.
    plotLabelStr = strrep(labelStr, '_', ' ');


    %---------- 1. Compute frequencies of interest ----------
    rot_freq = rpm / 60;                % [Hz]
    gmf      = gearteeth * rot_freq;    % [Hz]

    %---------- 2. FFT → single‐sided spectrum in dB (smoothed) ----------
    N     = numel(x);
    X     = fft(x);
    P2    = abs(X / N);
    P1    = P2(1:floor(N/2)+1);
    P1(2:end-1) = 2 * P1(2:end-1);
    f1    = Fs * (0:(floor(N/2))) / N;       % frequency axis to Nyquist
    P1_dB = 20 * log10(P1);
    P1_dB_smooth = movmean(P1_dB, 10);

    %---------- 3. Plot (offscreen) ----------
    hFig = figure('Visible','off');
    semilogx(f1(2:end), P1_dB_smooth(2:end), 'b');
    hold on;
    if rot_freq > 0
        xline(rot_freq, 'r--', 'LineWidth', 1, ...
              'Label','Rot Freq', 'Interpreter', 'none'); % Interpreter none is safer
    end
    if gmf > 0
        xline(gmf, 'g--', 'LineWidth', 1, ...
              'Label','GMF', 'Interpreter', 'none'); % Interpreter none is safer
    end
    hold off;
    grid on;
    xlabel('Frequency (Hz, Log–scale)');
    ylabel('Magnitude (dB, Smoothed)');

    % Build the title using the "clean" label string
    titleStr = sprintf('%s   |   Speed: %g rpm   |   Torque: %g Nm', ...
                        plotLabelStr, speedValue, torqueValue);
    title(titleStr, 'Interpreter','none');

    %---------- 4. Build baseFileName and save as PNG ----------
    % Use the original labelStr for the filename
    baseFileName = sprintf('%s_%s_%g_Nm_%g_rpm', ...
                           dataset, labelStr, torqueValue, speedValue);

    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    savePath = fullfile(outputFolder, [baseFileName, '.png']);
    print(hFig, savePath, '-dpng', '-r300');

    %---------- 5. Close the figure ----------
    close(hFig);
end