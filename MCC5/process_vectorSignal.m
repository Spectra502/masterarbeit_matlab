function process_vectorSignal(signalVector, targetFilePath, segment_length, overlap, fs, featureDomains, label, speed, torque, channelName, useNewNameStyle)
    % Defaults for original signature
    if nargin < 3 || isempty(segment_length), segment_length = 1000; end
    if nargin < 4 || isempty(overlap), overlap = 500; end
    if nargin < 5 || isempty(fs), fs = 1000; end
    if nargin < 6 || isempty(featureDomains), featureDomains = {'time','frequency','time-frequency'}; end
    if nargin < 7 || isempty(label), label = 'unknown'; end
    if nargin < 8 || isempty(speed), speed = 0; end
    if nargin < 9 || isempty(torque), torque = 0; end
    if nargin < 10 || isempty(channelName), channelName = 'Signal'; end
    if nargin < 11 || isempty(useNewNameStyle), useNewNameStyle = false; end

    % Number of segments
    num_segments = floor((length(signalVector) - overlap) / (segment_length - overlap));

    % Extract features per segment
    features = [];
    for seg = 1:num_segments
        start_idx = (seg-1) * (segment_length - overlap) + 1;
        end_idx   = start_idx + segment_length - 1;
        segment   = signalVector(start_idx:end_idx);

        segment_features = [];
        if any(strcmp(featureDomains, 'time'))
            segment_features = [segment_features, extractTimeDomainFeatures(segment)];
        end
        if any(strcmp(featureDomains, 'frequency'))
            segment_features = [segment_features, extractFrequencyDomainFeatures(segment, fs)];
        end
        if any(strcmp(featureDomains, 'time-frequency'))
            segment_features = [segment_features, extractTimeFrequencyDomainFeatures(segment, fs)];
        end

        features = [features; segment_features];
    end

    % Feature names and table
    feature_names = generateFeatureNames(1, featureDomains);  % one channel
    feature_table = array2table(features, 'VariableNames', feature_names);

    % Metadata
    metadata_table = table( ...
        repmat({label}, size(features,1), 1), ...
        repmat(speed,  size(features,1), 1), ...
        repmat(torque, size(features,1), 1), ...
        'VariableNames', {'Label', 'Speed', 'Torque'});

    combined_table = [metadata_table, feature_table];

    % ----- Output filename logic -----
    % If you're saving per-domain, featureDomains should be a single item.
    domains_str = strjoin(featureDomains, '_');

    if useNewNameStyle && numel(featureDomains) == 1
        % Example: Channel1_20000Hz_time_healthy_300_Nm_500_rpm_features.csv
        domainStr = featureDomains{1};
        outputBase = sprintf('%s_%dHz_%s_%s_%d_Nm_%d_rpm_features', ...
            channelName, fs, domainStr, label, torque, speed);
    else
        % Original style
        outputBase = sprintf('%s_%dHz_%s_%s_%d_Nm_%d_rpm_features', ...
            channelName, fs, domains_str, label, speed, torque);
    end

    ensureDir(targetFilePath);  % make sure the target exists
    outputFileName = fullfile(targetFilePath, [outputBase '.csv']);
    writetable(combined_table, outputFileName);
end

function ensureDir(p)
    if ~exist(p, 'dir')
        mkdir(p);
    end
end
