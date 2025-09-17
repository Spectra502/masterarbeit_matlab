function processAndAugmentSignals(dataFolders, outputFolder, decimateFactor, filterType, augmentations, enablePlotting, varargin)
    % processAndAugmentSignals - A flexible function to process and augment TDMS signals.
    %
    % New processing order:
    % 1. Load and decimate the signal.
    % 2. Create augmented versions of the signal.
    % 3. Apply filtering to BOTH the original and augmented signals.
    % 4. Plot and save the results.

    % --- Input Parser for Augmentation Parameters ---
    p = inputParser;
    addParameter(p, 'noise_level', 0.003);
    addParameter(p, 'mask_fraction', 0.15);
    addParameter(p, 'shift_amount', 110);
    addParameter(p, 'scale_factor', 0.7);
    addParameter(p, 'stretch_factor', 0.7);
    parse(p, varargin{:});
    augParams = p.Results;

    % --- File Discovery ---
    fileList = {};
    for i = 1:numel(dataFolders)
        folder = dataFolders{i};
        files = dir(fullfile(folder, '*.tdms'));
        for j = 1:numel(files)
            fileList{end+1} = fullfile(folder, files(j).name);
        end
    end

    if isempty(fileList)
        warning('No .tdms files found in the specified folders.');
        return;
    end

    % --- Parallel Processing ---
    parfor k = 1:numel(fileList)
        fullpath = fileList{k};
        [~, fname, ~] = fileparts(fullpath);
        fprintf('Processing file: %s\n', fname);

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

        % --- 2. Create a "To-Do" List of Signals (Original + Augmentations) ---
        signalsToProcess = {base_signal}; % Start with the original signal
        signalLabels = {'original'};       % Label for the original signal

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

        % --- 3. Process Each Signal in the List (Filter and Plot) ---
        numTeeth = 22; % Can be made a parameter
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

            % --- Plotting ---
            if enablePlotting
                % Folder name combines filter type and augmentation type
                plotFolder = fullfile(outputFolder, sprintf('plots_%s_%s', filterType, current_label));
                dataset_name = sprintf('%s_%s', filterType, current_label);
                
                plotFFTAndSave(filtered_signal, fs, speed, numTeeth, ...
                    dataset_name, label, speed, torque, plotFolder);
            end
        end
    end % End of parfor loop
end