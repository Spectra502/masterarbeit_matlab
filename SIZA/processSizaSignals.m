function processSizaSignals(dataFolder, baseOutputFolder, filterType, numTeeth, augmentations, enablePlotting, featureParams, augParams)
%PROCESSSIZASIGNALS Processes all signals within a single SIZA data folder.

    % --- 1. Dynamic Path Construction for FS Summary File ---
    [~, label] = fileparts(dataFolder);
    fs_results_folder_name = sprintf('%s_csv_calculated_frequencies', label);
    fs_results_folder_path = fullfile(dataFolder, fs_results_folder_name);
    fs_csv_filename = sprintf('%s.csv', fs_results_folder_name);
    fs_summary_csv_path = fullfile(fs_results_folder_path, fs_csv_filename);
    
    % --- 2. Load Sampling Frequencies ---
    fprintf('Loading sampling frequency data from:\n  %s\n', fs_summary_csv_path);
    if ~exist(fs_summary_csv_path, 'file')
        error('FS summary CSV not found. Expected Path: %s', fs_summary_csv_path);
    end
    fs_table = readtable(fs_summary_csv_path);
    fs_map = containers.Map(fs_table.Filename, fs_table.EstimatedFS);
    
    % --- 3. File Discovery ---
    files = dir(fullfile(dataFolder, '*.csv'));
    validFiles = {};
    for j = 1:numel(files)
        if isKey(fs_map, files(j).name), validFiles{end+1} = files(j); end
    end
    if isempty(validFiles), warning('No valid .csv signal files found in %s.', dataFolder); return; end
    fprintf('Found %d valid signal files to process.\n', numel(validFiles));

    % --- 4. Parallel Processing ---
    parfor k = 1:numel(validFiles)
        file_info = validFiles{k};
        fname_with_ext = file_info.name;
        full_path = fullfile(file_info.folder, fname_with_ext);
        
        try
            % --- 4.1. Load Data and Metadata ---
            signal_table = readtable(full_path);
            base_signal = signal_table{:, 1};
            fs = fs_map(fname_with_ext);
            tokens_rpm = regexp(fname_with_ext, '_(\d+)_rpm', 'tokens');
            tokens_torque = regexp(fname_with_ext, '_(\d+)_Nm', 'tokens');
            rpm = str2double(tokens_rpm{1}{1});
            torque = str2double(tokens_torque{1}{1});

            % --- 4.2. Filtering ---
            switch lower(filterType)
                case 'lowpass',  filtered_signal = lowpassGearMesh(base_signal, fs, rpm, numTeeth);
                case 'highpass', filtered_signal = highpassGearMesh(base_signal, fs, rpm, numTeeth);
                case 'bandpass', filtered_signal = bandpassGearMesh(base_signal, fs, rpm, numTeeth);
                otherwise,       filtered_signal = base_signal;
            end

            % --- 4.3. MODE SWITCH: Plotting or Feature Extraction ---
            if enablePlotting
                plotFolder = fullfile(baseOutputFolder, label, 'plots');
                if ~exist(plotFolder, 'dir'), mkdir(plotFolder); end
                
                % Reusing the plotting function from the HBK folder
                plotFFTAndSave(filtered_signal, fs, rpm, numTeeth, ...
                    ['SIZA_' label], label, rpm, torque, plotFolder);
            else
                % Feature Extraction
                seg_len = featureParams.segment_length;
                overlap = featureParams.overlap;
                num_segments = floor((numel(filtered_signal) - overlap) / (seg_len - overlap));
                all_features = [];
                if num_segments > 0
                    for seg = 1:num_segments
                        start_idx = (seg-1)*(seg_len - overlap) + 1;
                        end_idx = start_idx + seg_len - 1;
                        segment = filtered_signal(start_idx:end_idx);
                        
                        seg_features = [];
                        if ismember('time', featureParams.domains), seg_features = [seg_features, extractTimeDomainFeatures(segment, featureParams.time_features)]; end
                        if ismember('frequency', featureParams.domains), seg_features = [seg_features, extractFrequencyDomainFeatures(segment, fs, featureParams.freq_features)]; end
                        if ismember('time-frequency', featureParams.domains), seg_features = [seg_features, extractTimeFrequencyDomainFeatures(segment, fs, featureParams.time_freq_features)]; end
                        all_features = [all_features; seg_features];
                    end
                end
                
                if ~isempty(all_features)
                    feature_names = generateFeatureNames(featureParams);
                    feature_table = array2table(all_features, 'VariableNames', feature_names);
                    metadata_table = table(repmat({label}, height(feature_table), 1), repmat(rpm, height(feature_table), 1), repmat(torque, height(feature_table), 1), 'VariableNames', {'Label', 'Speed', 'Torque'});
                    combined_table = [metadata_table, feature_table];
                    
                    csvFolder = fullfile(baseOutputFolder, label, 'features');
                    if ~exist(csvFolder, 'dir'), mkdir(csvFolder); end
                    
                    outputFileName = fullfile(csvFolder, sprintf('%s_%s_%dNm_%drpm_features.csv', label, filterType, torque, rpm));
                    writetable(combined_table, outputFileName);
                end
            end
        catch ME
             fprintf(2, '\nERROR processing file: %s. Reason: %s\n', fname_with_ext, ME.message);
        end
    end % End parfor
end