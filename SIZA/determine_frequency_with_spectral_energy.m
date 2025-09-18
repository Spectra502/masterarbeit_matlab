function determine_frequency_with_spectral_energy(input_folder, output_folder, label)
% DETERMINE_FREQUENCY_WITH_SPECTRAL_ENERGY - Determines sampling frequency
%   based on spectral energy for all .mat files in a folder.
%
%   Inputs:
%     - input_folder  : Path to the folder containing the .mat files.
%     - output_folder : Path to save the resulting CSV and image files.
%     - label         : The label for the current dataset.

    % Find all .mat files in the folder
    files = dir(fullfile(input_folder, '*.csv'));
    
    if isempty(files)
        warning('No .mat files found in: %s', input_folder);
        return;
    end
    
    results = table();

    % Process each file
    for i = 1:numel(files)
        fullFilePath = fullfile(input_folder, files(i).name);
        [~, filename, ~] = fileparts(files(i).name);
        
        try
            % Load signal data (assuming it's in a variable named 'data')
            loaded_data = load(fullFilePath);
            if isstruct(loaded_data) && isfield(loaded_data, 'data')
                 signal = loaded_data.data;
            else % If not 'data', find the first numeric array in the file
                fields = fieldnames(loaded_data);
                signal = [];
                for f_idx = 1:numel(fields)
                    if isnumeric(loaded_data.(fields{f_idx}))
                        signal = loaded_data.(fields{f_idx});
                        break;
                    end
                end
                if isempty(signal)
                    error('No numeric signal variable found in the file.');
                end
            end

            % --- Core Logic: Determine Sampling Frequency ---
            x = signal - mean(signal); % Remove DC offset
            N = length(x);
            assumed_fs = 50000; % A high assumed rate to find the real one
            
            X = fft(x);
            P2 = abs(X/N);
            P1 = P2(1:N/2+1);
            P1(2:end-1) = 2*P1(2:end-1);
            f = assumed_fs*(0:(N/2))/N;
            
            [~, idx] = max(P1(2:end)); % Find peak frequency (excluding DC)
            determined_fs = f(idx+1);

            % --- Plotting ---
            hFig = figure('Visible', 'off');
            plot(f, P1);
            title(sprintf('FFT Spectrum for %s', strrep(filename, '_', ' ')));
            xlabel('Frequency (Hz)');
            ylabel('|P1(f)|');
            grid on;
            
            % Save the plot in the designated output folder
            plot_filename = fullfile(output_folder, sprintf('%s.png', filename));
            print(hFig, plot_filename, '-dpng', '-r300');
            close(hFig);

            % --- Store results ---
            new_row = {filename, determined_fs};
            results = [results; new_row];

        catch ME
            fprintf(2, 'Error processing file %s: %s\n', files(i).name, ME.message);
        end
    end
    
    if ~isempty(results)
        results.Properties.VariableNames = {'FileName', 'Determined_Fs'};
        
        % --- Save CSV in the designated output folder ---
        csv_filename = fullfile(output_folder, sprintf('%s_csv_calculated_frequencies.csv', label));
        writetable(results, csv_filename);
    end
end