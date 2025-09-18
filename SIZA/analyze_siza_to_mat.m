function analyze_siza_to_mat(input_folder, output_folder, label)
% ANALYZE_SIZA_TO_MAT - Estimates sampling frequency from CSV files and 
% saves the results as a robust .mat file.

    file_list = dir(fullfile(input_folder, '*.csv'));
    
    if isempty(file_list)
        warning('No .csv files found in: %s', input_folder);
        return;
    end

    % --- Use PARFOR to loop through each file in parallel ---
    all_results = cell(numel(file_list), 10); % Preallocate for all results

    parfor i = 1:numel(file_list)
        filename = file_list(i).name;
        file_path = fullfile(input_folder, filename);
        
        try
            % --- Metadata Extraction ---
            tokens_rpm = regexp(filename, '_(\d+)_rpm', 'tokens');
            tokens_torque = regexp(filename, '_(\d+)_Nm', 'tokens');
            if isempty(tokens_rpm) || isempty(tokens_torque)
                fprintf('  -> SKIPPING: Could not extract RPM/Torque from: %s\n', filename);
                continue;
            end
            rpm = str2double(tokens_rpm{1}{1});
            torque = str2double(tokens_torque{1}{1});
            gmf = (rpm / 60) * 22;
            rot_frequency = rpm / 60;

            % --- Robust Data Reading ---
            % Use readmatrix for reliability; it handles headers/delimiters better.
            signal = readmatrix(file_path);
            if isempty(signal), continue; end % Skip if file is empty
            signal = signal(:,1); % Ensure we only have the first column
            signal_length = numel(signal);

            % --- FFT and Peak Detection ---
            fs_known = 1.0;
            N = length(signal);
            Y = fft(signal);
            f_initial = (0:N-1) * (fs_known / N);
            magnitude_power = abs(Y).^2;
            [~, locs] = findpeaks(magnitude_power, 'MinPeakHeight', max(magnitude_power)*0.0001, 'MinPeakDistance', 500);
            
            if isempty(locs), continue; end

            detected_freqs = f_initial(locs)';
            peak_table = table(detected_freqs, 'VariableNames', {'Normalized_Frequency'});
            peak_table = sortrows(peak_table, 'Normalized_Frequency', 'ascend');
            
            % --- FS Estimation ---
            first_peak_normalized_freq = peak_table.Normalized_Frequency(1);
            fs_est = rot_frequency / first_peak_normalized_freq;

            % --- Plotting ---
            % This part remains the same
            hFig = figure('Visible', 'off');
            f_final = fs_est * (0:(floor(N/2))) / N;
            P2 = abs(Y / N);
            P1 = P2(1:floor(N/2)+1);
            P1(2:end-1) = 2 * P1(2:end-1);
            P1_dB_smooth = movmean(20*log10(P1), 10);
            semilogx(f_final(2:end), P1_dB_smooth(2:end));
            title(sprintf('SIZA [%s] - %d Nm - %d RPM', label, torque, rpm));
            xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
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

    % --- Final Step: Save Summary Table to a .MAT File ---
    valid_mask = ~cellfun('isempty', all_results(:,1));
    final_results = all_results(valid_mask, :);

    if ~isempty(final_results)
        summary_table = cell2table(final_results, 'VariableNames', ...
            {'Filename', 'Filepath', 'RPM', 'Torque', 'GMF', ...
             'RotationalFrequency', 'EstimatedFS', 'SignalLength', 'Label', 'ImagePath'});
        
        % Define the output .mat file path
        output_mat_path = fullfile(output_folder, sprintf('%s_calculated_frequencies.mat', label));
        
        % Save the summary_table variable into the .mat file
        save(output_mat_path, 'summary_table');
        
        fprintf('Summary .mat file saved to: %s\n', output_mat_path);
    end
end