function analyze_siza_csv_files(input_folder, output_folder, label)
% ANALYZE_SIZA_CSV_FILES_PARALLEL - Estimates sampling frequency from CSV files using a parfor loop.

    file_list = dir(fullfile(input_folder, '*.csv'));
    
    if isempty(file_list)
        warning('No .csv files found in: %s', input_folder);
        return;
    end

    % --- Use PARFOR to loop through each file in parallel ---
    % Each iteration of the loop runs on a different core and returns one row of results.
    all_results = cell(numel(file_list), 10); % Preallocate cell for results

    parfor i = 1:numel(file_list)
        filename = file_list(i).name;
        file_path = fullfile(input_folder, filename);
        
        % Use a try-catch block inside parfor for robust error handling
        try
            fprintf('  Analyzing: %s\n', filename);

            % --- Metadata Extraction ---
            tokens_rpm = regexp(filename, '_(\d+)_rpm', 'tokens');
            tokens_torque = regexp(filename, '_(\d+)_Nm', 'tokens');
            if isempty(tokens_rpm) || isempty(tokens_torque)
                warning('Could not extract RPM or Torque from filename, skipping: %s', filename);
                continue;
            end
            rpm = str2double(tokens_rpm{1}{1});
            torque = str2double(tokens_torque{1}{1});
            gmf = (rpm / 60) * 22;
            rot_frequency = rpm / 60;

            % --- Read Data ---
            data = readtable(file_path);
            signal = data{:, 1};
            signal_length = numel(signal);

            % --- FFT and Peak Detection ---
            fs_known = 1.0;
            N = length(signal);
            Y = fft(signal);
            f_initial = (0:N-1) * (fs_known / N);
            magnitude_power = abs(Y).^2;
            min_peak_height = max(magnitude_power) * 0.0001;
            min_peak_distance = 500;
            [~, locs] = findpeaks(magnitude_power, 'MinPeakHeight', min_peak_height, 'MinPeakDistance', min_peak_distance);
            
            detected_freqs = f_initial(locs)';
            peak_table = table(detected_freqs, 'VariableNames', {'Normalized_Frequency'});
            peak_table = sortrows(peak_table, 'Normalized_Frequency', 'ascend');

            if isempty(peak_table)
                warning('No peaks were detected for file %s. Skipping.', filename);
                continue;
            end
            
            % --- FS Estimation ---
            first_peak_normalized_freq = peak_table.Normalized_Frequency(1);
            fs_est = rot_frequency / first_peak_normalized_freq;

            % --- Plotting (Figures are handled safely in parfor) ---
            hFig = figure('Visible', 'off');
            f_final = fs_est * (0:(floor(N/2))) / N;
            P2 = abs(Y / N);
            P1 = P2(1:floor(N/2)+1);
            P1(2:end-1) = 2 * P1(2:end-1);
            P1_dB_smooth = movmean(20 * log10(P1), 10);
            
            semilogx(f_final(2:end), P1_dB_smooth(2:end), 'b', 'LineWidth', 1.5);
            grid on; hold on;
            y_lim = ylim;
            xline(rot_frequency, 'g--', 'LineWidth', 1);
            text(rot_frequency * 0.85, y_lim(2) - 5, sprintf('Rot. Freq. = %.2f Hz', rot_frequency), 'Color', 'g', 'Rotation', 90, 'HorizontalAlignment', 'right');
            xline(gmf, 'r--', 'LineWidth', 1);
            text(gmf * 0.85, y_lim(2) - 5, sprintf('GMF = %.2f Hz', gmf), 'Color', 'r', 'Rotation', 90, 'HorizontalAlignment', 'right');
            hold off;
            title(sprintf('SIZA [%s] - %d Nm - %d RPM', label, torque, rpm));
            xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
            xlim([10^-1, fs_est/2]);
            fs_string = sprintf('Estimated FS = %.2f Hz', fs_est);
            annotation('textbox', [0.15, 0.15, 0.3, 0.1], 'String', fs_string, 'EdgeColor', 'black', 'FontWeight', 'bold', 'FitBoxToText', 'on', 'BackgroundColor', 'white');
            
            image_filename = sprintf('%s.png', filename(1:end-4));
            image_path = fullfile(output_folder, image_filename);
            print(hFig, image_path, '-dpng', '-r300');
            close(hFig);

            % --- Store results for this iteration ---
            all_results(i,:) = {filename, file_path, rpm, torque, gmf, rot_frequency, fs_est, signal_length, label, image_path};

        catch ME
            fprintf(2, 'Error processing %s: %s\n', filename, ME.message);
        end
    end

    % --- Final Step: Write Summary CSV ---
    % Remove any empty rows that may have resulted from errors
    all_results(all(cellfun('isempty', all_results), 2), :) = [];

    if ~isempty(all_results)
        summary_table = cell2table(all_results, 'VariableNames', ...
            {'Filename', 'Filepath', 'RPM', 'Torque', 'GMF', ...
             'RotationalFrequency', 'EstimatedFS', 'SignalLength', 'Label', 'ImagePath'});
        
        output_csv_path = fullfile(output_folder, sprintf('%s_csv_calculated_frequencies.csv', label));
        writetable(summary_table, output_csv_path);
        fprintf('Summary CSV saved to: %s\n', output_csv_path);
    end
end