function processAndAugmentSignals(dataFolders, outputFolder, decimateFactor, filterType, augmentations, enablePlotting, featureParams, varargin)
    % processAndAugmentSignals - A flexible function to process and augment TDMS signals.

    % --- Input Parser for Augmentation Parameters ---
    p = inputParser;
    addParameter(p, 'noise_level', 0.01);
    addParameter(p, 'mask_fraction', 0.05);
    addParameter(p, 'shift_amount', 50);
    addParameter(p, 'scale_factor', 1.1);
    addParameter(p, 'stretch_factor', 1.2);
    parse(p, varargin{:});
    augParams = p.Results;

    % --- File Discovery ---
    % Renamed 'fileList' to 'tdmsFileList' to avoid potential name conflicts
    tdmsFileList = {};
    for i = 1:numel(dataFolders)
        folder = dataFolders{i};
        files = dir(fullfile(folder, '*.tdms'));
        for j = 1:numel(files)
            tdmsFileList{end+1} = fullfile(folder, files(j).name);
        end
    end

    if isempty(tdmsFileList)
        warning('No .tdms files found in the specified folders.');
        return;
    end

    % --- Parallel Processing with Error Handling---
    parfor k = 1:numel(tdmsFileList)
        
        % Get filename for logging purposes, even if an error occurs early
        [~, fname_for_log, ~] = fileparts(tdmsFileList{k});

        try
            % --- START of processing for a single file ---
            fullpath = tdmsFileList{k};
            fprintf('Processing file: %s\n', fname_for_log);

            % --- 1. Load, Extract Metadata, and Decimate ---
            raw = tdmsread(fullpath);
            dataTable = raw{1};
            [label, torque, speed, ~, ~] = extractVariables(fullpath);

            original_fs = 100000;
            base_signal = dataTable{:, 2};

            if decimateFactor > 1
                fs = original_fs / decimateFactor;
                base_signal = decimate(base_signal, decimateFactor);
            else
                fs = original_fs;
            end

            % --- 2. Create a List of Signals (Original + Augmentations) ---
            signalsToProcess = {base_signal};
            signalLabels = {'original'};

            if ~isempty(augmentations)
                for i = 1:numel(augmentations)
                    augType = augmentations{i};
                    augmented_signal = [];
                    switch lower(augType)
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

            % --- 3. Process Each Signal (Filter, then Plot or Extract Features) ---
            numTeeth = 22;
            for i = 1:numel(signalsToProcess)
                current_signal = signalsToProcess{i};
                current_label = signalLabels{i};
                
                % --- Apply Filter ---
                switch lower(filterType)
                    case 'lowpass'
                        filtered_signal = lowpassGearMesh(current_signal, fs, speed, numTeeth);
                    case 'highpass'
                        filtered_signal = highpassGearMesh(current_signal, fs, speed, numTeeth);
                    case 'bandpass'
                        filtered_signal = bandpassGearMesh(current_signal, fs, speed, numTeeth);
                    otherwise % 'none'
                        filtered_signal = current_signal;
                end

                % --- MODE SWITCH: Plotting or Feature Extraction ---
                if enablePlotting
                    plotFolder = fullfile(outputFolder, sprintf('plots_%s_%s', filterType, current_label));
                    dataset_name = sprintf('%s_%s', filterType, current_label);
                    plotFFTAndSave(filtered_signal, fs, speed, numTeeth, ...
                        dataset_name, label, speed, torque, plotFolder);
                else
                    % --- Feature Extraction ---
                    seg_len = featureParams.segment_length;
                    overlap = featureParams.overlap;
                    num_segments = floor((numel(filtered_signal) - overlap) / (seg_len - overlap));
                    all_features = [];
    
                    for seg = 1:num_segments
                        start_idx = (seg-1) * (seg_len - overlap) + 1;
                        end_idx = start_idx + seg_len - 1;
                        segment = filtered_signal(start_idx:end_idx);
                        
                        segment_features = [];
                        if ismember('time', featureParams.domains)
                            segment_features = [segment_features, extractTimeDomainFeatures(segment, featureParams.time_features)];
                        end
                        if ismember('frequency', featureParams.domains)
                            segment_features = [segment_features, extractFrequencyDomainFeatures(segment, fs, featureParams.freq_features)];
                        end
                        if ismember('time-frequency', featureParams.domains)
                            segment_features = [segment_features, extractTimeFrequencyDomainFeatures(segment, fs, featureParams.time_freq_features)];
                        end
                        all_features = [all_features; segment_features];
                    end
                    
                    if ~isempty(all_features)
                        feature_names = generateFeatureNames(featureParams);
                        feature_table = array2table(all_features, 'VariableNames', feature_names);
                        
                        metadata_table = table(repmat({label}, height(feature_table), 1), ...
                            repmat(speed, height(feature_table), 1), ...
                            repmat(torque, height(feature_table), 1), ...
                            'VariableNames', {'Label', 'Speed', 'Torque'});
                            
                        combined_table = [metadata_table, feature_table];
                        
                        csvFolder = fullfile(outputFolder, 'features');
                        if ~exist(csvFolder, 'dir'), mkdir(csvFolder); end
                        
                        outputFileName = fullfile(csvFolder, ...
                            sprintf('%s_%s_%s_%dNm_%drpm_features.csv', ...
                            label, filterType, current_label, torque, speed));
                            
                        writetable(combined_table, outputFileName);
                    end
                end
            end
            
        catch ME
            % --- This block runs ONLY if an error occurred in the 'try' block ---
            fprintf(2, '\n------------------------------------------------\n');
            fprintf(2, '⚠️ ERROR processing file: %s\n', fname_for_log);
            fprintf(2, '   Skipping this file. Reason: %s\n', ME.message);
            fprintf(2, '   Error occurred in function "%s" on line %d.\n', ME.stack(1).name, ME.stack(1).line);
            fprintf(2, '------------------------------------------------\n\n');
        end
        
    end % End of parfor loop
end