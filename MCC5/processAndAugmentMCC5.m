function processAndAugmentMCC5(dataFolders, outputFolder, selectedChannel, original_fs, decimateFactor, filterType, numTeeth, applyAugmentations, augmentations, enablePlotting, featureParams, augParams)
% PROCESSANDAUGMENTMCC5 Processes, augments, and analyzes MCC5 signals.
%
% This function is designed to be called from a runner script like
% 'run_experiments_MCC5.mlx'. It processes all CSV files within the
% provided data folders in parallel.

    % --- 1. File Discovery ---
    csvFileList = {};
    for i = 1:numel(dataFolders)
        folder = dataFolders{i};
        files = dir(fullfile(folder, '*.csv'));
        for j = 1:numel(files)
            csvFileList{end+1} = fullfile(folder, files(j).name);
        end
    end

    if isempty(csvFileList)
        warning('No .csv files found in the specified data folders.');
        return;
    end

    % --- 2. Parallel Processing ---
    parfor k = 1:numel(csvFileList)
        
        fullPath = csvFileList{k};
        [~, fname_for_log, ~] = fileparts(fullPath);

        try
            fprintf('Processing: %s\n', fname_for_log);

            % --- 2.1. Load Data and Extract Metadata ---
            [folderPath, ~, ~] = fileparts(fullPath);
            [~, label, ~] = fileparts(folderPath); % Label is the parent folder's name

            % Use the robust parsing function
            [rpm, torque] = extractOperatingConditions(fname_for_log);
            if isnan(rpm) || isnan(torque)
                warning('Could not parse RPM or Torque from %s. Skipping.', fname_for_log);
                continue;
            end
            
            % Read the signal table
            opts = detectImportOptions(fullPath);
            if ~ismember(selectedChannel, opts.VariableNames)
                warning('Channel "%s" not found in %s. Skipping.', selectedChannel, fname_for_log);
                continue;
            end
            opts.SelectedVariableNames = {selectedChannel};
            signalTable = readtable(fullPath, opts);
            base_signal = signalTable{:, 1};

            % --- 2.2. Decimation ---
            if decimateFactor > 1
                fs = original_fs / decimateFactor;
                base_signal = decimate(base_signal, decimateFactor);
            else
                fs = original_fs;
            end

            % --- 2.3. Augmentation Stage ---
            signalsToProcess = {base_signal};
            signalLabels = {'original'};
            
            if applyAugmentations
                for i = 1:numel(augmentations)
                    augType = lower(augmentations{i});
                    augmented_signal = [];
                    switch augType
                        case 'gaussian_noise'
                            augmented_signal = augment_gaussian_noise(base_signal, augParams.noise_level);
                        case 'masking_noise'
                            augmented_signal = augment_masking_noise(base_signal, augParams.mask_fraction);
                        case 'translation'
                            augmented_signal = augment_translation(base_signal, augParams.shift_amount);
                        case 'amplitude_shift'
                            augmented_signal = augment_amplitude_shift(base_signal, augParams.scale_factor);
                        case 'time_stretch'
                            augmented_signal = augment_time_stretch(base_signal, augParams.stretch_factor);
                    end
                    if ~isempty(augmented_signal)
                        signalsToProcess{end+1} = augmented_signal;
                        signalLabels{end+1} = augType;
                    end
                end
            end

            % --- 2.4. Process Each Signal (Original + Augmented) ---
            for sig_idx = 1:numel(signalsToProcess)
                current_signal = signalsToProcess{sig_idx};
                current_label = signalLabels{sig_idx};
                
                % --- Apply Filter ---
                switch lower(filterType)
                    case 'lowpass',  filtered_signal = lowpassGearMesh(current_signal, fs, rpm, numTeeth);
                    case 'highpass', filtered_signal = highpassGearMesh(current_signal, fs, rpm, numTeeth);
                    case 'bandpass', filtered_signal = bandpassGearMesh(current_signal, fs, rpm, numTeeth);
                    otherwise,       filtered_signal = current_signal; % 'none'
                end

                % --- 2.5. MODE SWITCH: Plotting or Feature Extraction ---
                if enablePlotting
                    plotFolder = fullfile(outputFolder, 'plots');
                    dataset_name = sprintf('MCC5_%s_%s', filterType, current_label);
                    plotFFTAndSave(filtered_signal, fs, rpm, numTeeth, ...
                        dataset_name, label, rpm, torque, plotFolder);
                else
                    % --- Feature Extraction ---
                    seg_len = featureParams.segment_length;
                    overlap = featureParams.overlap;
                    num_segments = floor((numel(filtered_signal) - overlap) / (seg_len - overlap));
                    
                    if num_segments < 1, continue; end
                    
                    all_features = [];
                    for seg = 1:num_segments
                        start_idx = (seg-1) * (seg_len - overlap) + 1;
                        end_idx = start_idx + seg_len - 1;
                        segment = filtered_signal(start_idx:end_idx);
                        
                        seg_features = [];
                        if ismember('time', featureParams.domains), seg_features = [seg_features, extractTimeDomainFeatures(segment, featureParams.time_features)]; end
                        if ismember('frequency', featureParams.domains), seg_features = [seg_features, extractFrequencyDomainFeatures(segment, fs, featureParams.freq_features)]; end
                        if ismember('time-frequency', featureParams.domains), seg_features = [seg_features, extractTimeFrequencyDomainFeatures(segment, fs, featureParams.time_freq_features)]; end
                        all_features = [all_features; seg_features];
                    end
                    
                    if ~isempty(all_features)
                        feature_names = generateFeatureNames(featureParams);
                        feature_table = array2table(all_features, 'VariableNames', feature_names);
                        
                        metadata_table = table(repmat({label}, height(feature_table), 1), ...
                            repmat(rpm, height(feature_table), 1), ...
                            repmat(torque, height(feature_table), 1), ...
                            'VariableNames', {'Label', 'Speed', 'Torque'});
                            
                        combined_table = [metadata_table, feature_table];
                        
                        % --- MODIFIED LINE: All features now save to one folder ---
                        csvFolder = fullfile(outputFolder, 'features');
                        if ~exist(csvFolder, 'dir'), mkdir(csvFolder); end
                        
                        outputFileName = fullfile(csvFolder, ...
                            sprintf('%s_%s_%s_%dNm_%drpm_features.csv', ...
                            label, filterType, current_label, torque, rpm));
                            
                        writetable(combined_table, outputFileName);
                    end
                end
            end

        catch ME
            fprintf(2, '--- ERROR processing %s: %s (Line %d) ---\n', fname_for_log, ME.message, ME.stack(1).line);
        end
    end % End parfor
end

function [rpm, torque] = extractOperatingConditions(filename)
% A more robust helper to extract numeric values for speed and load.
% It handles different separators and orders.
    rpm = NaN;
    torque = NaN;
    
    % This regular expression is more flexible. It looks for two number-unit
    % pairs separated by either an underscore or a dash.
    expr = '(\d+)(rpm|Nm)[-_](\d+)(rpm|Nm)';
    tokens = regexp(filename, expr, 'tokens', 'once');
    
    if ~isempty(tokens) && numel(tokens) == 4
        % We found a match. Now, assign the values based on the units.
        val1 = str2double(tokens{1});
        unit1 = tokens{2};
        val2 = str2double(tokens{3});
        unit2 = tokens{4};
        
        if strcmpi(unit1, 'rpm')
            rpm = val1;
            torque = val2;
        else % The first unit was Nm
            torque = val1;
            rpm = val2;
        end
    end
end