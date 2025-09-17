function plotFFTAndSave( ...
        x, Fs, rpm, gearteeth, ...
        dataset, labelStr, speedValue, torqueValue, ...
        outputFolder)
% plotFFTAndSave  Compute & save a smoothed, single‐sided FFT (dB vs. log‐freq).
%
%   plotFFTAndSave(x, Fs, rpm, gearteeth, dataset, labelStr, speedValue, torqueValue, outputFolder)
%
%   Inputs:
%     x             – time‐domain signal (vector)
%     Fs            – sampling frequency in Hz (scalar)
%     rpm           – rotational speed in RPM (scalar)
%     gearteeth     – number of teeth on the gear (scalar)
%     dataset       – string identifying the dataset (e.g. 'Run1', 'TestA')
%     labelStr      – a custom label (string) to appear in the title
%     speedValue    – numeric “speed” value (e.g. same as rpm or user‐defined)
%     torqueValue   – numeric “torque” value
%     outputFolder  – folder path (string) where the PNG will be saved
%
%   The function will:
%     • Compute rot_freq = rpm/60   and  gmf = gearteeth*rot_freq
%     • Build a single‐sided, smoothed FFT in dB vs. log‐frequency
%     • Plot (on semilogx), add xlines at rot_freq (red) and gmf (green)
%     • Build the title from `labelStr`, `speedValue`, `torqueValue`
%     • Construct baseFileName = "<dataset>_<label>_<torque>_<speed>"
%     • Save the figure as "<outputFolder>/<baseFileName>.png" at 300 dpi
%     • Close the figure automatically
%
%   Example:
%       plotFFTAndSave( ...
%           mySignal, 12e3, 1800, 20, ...
%           'Run1', 'SensorA', 1800, 200, ...
%           'C:\plots\');
%       % → saves "C:\plots\Run1_SensorA_200_1800.png"
%
%   ——————————————————————————————————————————————

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
    % hold on;
    % if rot_freq > 0
    %     xline(rot_freq, 'r--', 'LineWidth', 1, ...
    %           'Label','Rot\,Freq', ...
    %           'LabelOrientation','horizontal', ...
    %           'LabelVerticalAlignment','bottom');
    % end
    % if gmf > 0
    %     xline(gmf, 'g--', 'LineWidth', 1, ...
    %           'Label','GMF', ...
    %           'LabelOrientation','horizontal', ...
    %           'LabelVerticalAlignment','bottom');
    % end
    % hold off;
    grid on;
    xlabel('Frequency (Hz, Log–scale)');
    ylabel('Magnitude (dB, Smoothed)');

    % Build the title:
    % titleStr = sprintf('%s   |   Speed: %g rpm   |   Torque: %g Nm', ...
    %                     labelStr, speedValue, torqueValue);
    % title(titleStr, 'Interpreter','none');

    %---------- 4. Build baseFileName and save as PNG ----------
    % baseFileName = dataset_label_torque_speed
    %   (note: torqueValue first, then speedValue, per "dataset_label_torque_speed")
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
