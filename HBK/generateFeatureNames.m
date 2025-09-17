function feature_names = generateFeatureNames(featureParams)
% generateFeatureNames - Creates a cell array of feature names for the CSV header.

    feature_names = {};

    if ismember('time', featureParams.domains)
        feature_names = [feature_names, featureParams.time_features];
    end
    
    if ismember('frequency', featureParams.domains)
        feature_names = [feature_names, featureParams.freq_features];
    end

    if ismember('time-frequency', featureParams.domains)
        feature_names = [feature_names, featureParams.time_freq_features];
    end
end