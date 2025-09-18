function analyze_siza_csv_files_simplified(input_folder, output_folder, label)
% ANALYZE_SIZA_CSV_FILES_ROBUST - Robustly estimates sampling frequency from 
% CSV files and saves a minimal summary CSV.

    file_list = dir(fullfile(input_folder, '*.csv'));
    
    if isempty(file_list)
        warning('No .csv files found in: %s', input_folder);
        return;
    end

    % --- Use PARFOR to loop through each file in parallel ---
    % Preallocate a cell array for the results.
    num_files = numel(file_list);
    all_results = cell(num_files, 2); 

    parfor i = 1:num_files
        filename = file_list(i).name;
        file_path = fullfile(input_folder, filename);
        
        try
            % --- 1. Metadata Extraction from Filename ---
            tokens_rpm = regexp(filename, '_(\d+)_rpm', 'tokens');
            if isempty(tokens_rpm)
                fprintf('  -> SKIPPING (No RPM): Could not extract RPM from filename: %s\n', filename);
                continue; % Skip this file
            end
            rpm = str2double(tokens_rpm{1}{1});
            rot_frequency = rpm / 60;

            % --- 2. Robust Data Reading ---
            % Use readmatrix to directly read numeric data, ignoring text headers.
            % This is much more reliable than readtable for this task.
            signal = readmatrix(file_path);
            
            % Check if the signal was read correctly and is not empty
            if isempty(signal) || ~isnumeric(signal)
                 fprintf('  -> SKIPPING (No Data): Failed to read numeric data from: %s\n', filename);
                 continue;
            end
            
            % Ensure we are working with the first column if multiple exist
            if size(signal, 2) > 1
                signal = signal(:, 1);
            end

            % --- 3. FFT and Peak Detection ---
            fs_known = 1.0; % Normalized frequency for calculation
            N = length(signal);
            Y = fft(signal);
            f_initial = (0:N-1) * (fs_known / N);
            magnitude_power = abs(Y).^2;
            
            % Find peaks in the spectrum
            [~, locs] = findpeaks(magnitude_power, 'MinPeakHeight', max(magnitude_power) * 0.0001);
            
            if isempty(locs)
                fprintf('  -> SKIPPING (No Peaks): No spectral peaks detected for file: %s\n', filename);
                continue;
            end

            % --- 4. FS Estimation ---
            % Find the first peak after DC offset (index 1)
            valid_freqs = f_initial(locs(locs > 1));
            if isempty(valid_freqs)
                fprintf('  -> SKIPPING (No Valid Peaks): Only a DC peak was found for file: %s\n', filename);
                continue;
            end
            
            first_peak_normalized_freq = min(valid_freqs);
            fs_est = rot_frequency / first_peak_normalized_freq;

            % --- 5. Store Results ---
            % If all steps succeeded, store the valid result
            fprintf('  -> SUCCESS: Processed %s, Estimated FS = %.2f Hz\n', filename, fs_est);
            all_results(i,:) = {filename, fs_est};

        catch ME
            fprintf(2, '  -> ERROR processing %s: %s (Line %d)\n', filename, ME.message, ME.stack(1).line);
        end
    end

    % --- Final Step: Write Summary CSV ---
    % Remove any empty rows that resulted from errors or skips
    valid_results_mask = ~cellfun('isempty', all_results(:,1));
    final_results = all_results(valid_results_mask, :);

    if ~isempty(final_results)
        summary_table = cell2table(final_results, 'VariableNames', {'Filename', 'EstimatedFS'});
        
        % Ensure output directory exists
        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end
        
        output_csv_path = fullfile(output_folder, sprintf('%s_csv_calculated_frequencies.csv', label));
        writetable(summary_table, output_csv_path);
        fprintf('\nRobust summary CSV saved to: %s\n', output_csv_path);
    else
        fprintf('\nNo files were successfully processed. No summary file was saved.\n');
    end
end