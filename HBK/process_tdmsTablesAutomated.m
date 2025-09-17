function process_tdmsTablesAutomated(tdmsTables, targetFilePath, segment_length, overlap, fs, selectedChannel, featureDomains)
    % Set default values if not provided
    if nargin < 4
        overlap = 500;
    end
    if nargin < 3
        segment_length = 1000;
    end
    if nargin < 5
        fs = 1000;  % Default sampling frequency
    end
    if nargin < 6
        selectedChannel = 1;  % Default to channel 1 if not provided
    end
    if nargin < 7
        featureDomains = {'time', 'frequency', 'time-frequency'};  % Default to all domains if not provided
    end

    % Get field names of the struct
    fields = fieldnames(tdmsTables);

    % Loop through each field in the struct
    for i = 1:numel(fields)
        fieldName = fields{i};
        dataTable = tdmsTables.(fieldName).data;

        % Extract signal columns (assume the first column is time)
        signal_columns = dataTable(:, 2:end);

        % Extract the specific channel (only one channel)
        channel_data = signal_columns(:, selectedChannel);  % This is still a table

        % Determine number of segments
        num_segments = floor((height(channel_data) - overlap) / (segment_length - overlap));

        % Initialize feature matrix
        features = [];

        % Loop through each segment and extract features
        for seg = 1:num_segments
            start_idx = (seg-1) * (segment_length - overlap) + 1;
            end_idx = start_idx + segment_length - 1;

            % Extract the segment for the selected channel (fixed indexing)
            segment = channel_data{start_idx:end_idx,1};  % Correct way to index into a table column

            % Initialize the segment's feature vector
            segment_features = [];

            % Extract the selected features based on `featureDomains`
            if any(strcmp(featureDomains, 'time'))
                timeDomainFeatures = extractTimeDomainFeatures(segment);
                segment_features = [segment_features, timeDomainFeatures];
            end

            if any(strcmp(featureDomains, 'frequency'))
                frequencyDomainFeatures = extractFrequencyDomainFeatures(segment, fs);
                segment_features = [segment_features, frequencyDomainFeatures];
            end

            if any(strcmp(featureDomains, 'time-frequency'))
                timeFrequencyDomainFeatures = extractTimeFrequencyDomainFeatures(segment, fs);
                segment_features = [segment_features, timeFrequencyDomainFeatures];
            end

            features = [features; segment_features];
        end

        % Feature names for the single channel (simplified)
        feature_names = generateFeatureNames(1, featureDomains);  % Just one channel

        % Convert features to table for easy export
        feature_table = array2table(features, 'VariableNames', feature_names);

        % Simplified metadata columns (only label, speed, and torque)
        metadata_table = table(repmat({tdmsTables.(fieldName).label}, height(feature_table), 1), ...
            repmat(tdmsTables.(fieldName).speed, height(feature_table), 1), ...
            repmat(tdmsTables.(fieldName).torque, height(feature_table), 1), ...
            'VariableNames', {'Label', 'Speed', 'Torque'});

        % Combine metadata and feature table
        combined_table = [metadata_table, feature_table];

        % % Construct output filename: sampling_frequency_domains_label_speed_torque
        % domains_str = strjoin(featureDomains, '_');  % Join domains with '_'
        % outputFileName = fullfile(targetFilePath, ...
        %     sprintf('%d_%s_%s_%d_%d_features.csv', fs, domains_str, tdmsTables.(fieldName).label, ...
        %     tdmsTables.(fieldName).speed, tdmsTables.(fieldName).torque));

        % Construct output filename: channel_name_sampling_frequency_Hz_domains_label_speed_torque
        %domains_str = strjoin(featureDomains, '_');  % Join domains with '_'
        domains_str = string(featureDomains);
        channel_name = sprintf('Channel%d', selectedChannel);  % Add the channel name at the start
        outputFileName = fullfile(targetFilePath, ...
            sprintf('%s_%dHz_%s_%s_%d_Nm_%d_rpm_features.csv', channel_name, round(fs), domains_str, ...
            tdmsTables.(fieldName).label, tdmsTables.(fieldName).torque, tdmsTables.(fieldName).speed));

        % Export the combined table to a CSV file
        writetable(combined_table, outputFileName);
    end
end
