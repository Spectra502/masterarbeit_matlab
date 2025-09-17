function augmentedStruct = apply_augmentations(dataStruct, noise_level, mask_fraction, shift_amount, scale_factor, stretch_factor)
    % Function to apply data augmentation to each sub-struct inside a struct
    % dataStruct: Main struct (e.g., tdmsTables_healthy)
    % noise_level: Std dev for Gaussian noise
    % mask_fraction: Fraction of elements to mask
    % shift_amount: Number of samples to shift
    % scale_factor: Amplitude scaling factor
    % stretch_factor: Time stretching factor
    
    augmentedStruct = struct(); % Initialize the output struct
    fieldNames = fieldnames(dataStruct); % Get all field names
    
    for i = 1:length(fieldNames)
        fieldName = fieldNames{i}; % Extract current field name (e.g., 'x24_03_25_15_21_23_112_5_500_Nm_500_rpm')
        subStruct = dataStruct.(fieldName); % Get the nested struct
        
        % Check if 'data' field exists inside the subStruct
        if isfield(subStruct, 'data')
            raw_signal = subStruct.data; % Extract the data field
        else
            warning('Field "data" not found in %s, skipping...', fieldName);
            continue;
        end
        
        % Ensure data is numeric
        if ~isnumeric(raw_signal)
            warning('Data in struct %s is not numeric, skipping...', fieldName);
            continue;
        end
        
        % Apply augmentations
        aug_noise = augment_gaussian_noise(raw_signal, noise_level);
        aug_mask = augment_masking_noise(raw_signal, mask_fraction);
        aug_shift = augment_translation(raw_signal, shift_amount);
        aug_scale = augment_amplitude_shift(raw_signal, scale_factor);
        aug_stretch = augment_time_stretch(raw_signal, stretch_factor);
        
        % Store augmented data in a new struct inside augmentedStruct
        augmentedStruct.(fieldName).aug_noise = aug_noise;
        augmentedStruct.(fieldName).aug_mask = aug_mask;
        augmentedStruct.(fieldName).aug_shift = aug_shift;
        augmentedStruct.(fieldName).aug_scale = aug_scale;
        augmentedStruct.(fieldName).aug_stretch = aug_stretch;
    end
end
