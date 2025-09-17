function features = extractTimeDomainFeatures(x, featureList)
% EXTRACTTIMEDOMAINFEATURES  Compute selected time-domain features for one signal.
%
%   F = extractTimeDomainFeatures(x) returns the default three features:
%     [mean, skewness, kurtosis].
%
%   F = extractTimeDomainFeatures(x, FEATURELIST) returns only the features
%   named in FEATURELIST (a cell-array of strings), in that order.
%   Supported names are:
%     { 'mean', 'rms', 'std', 'skewness', 'kurtosis', ...
%       'ptp', 'crest', 'impulse', 'clearance', 'shape', ...
%       'energy', 'entropy' }

    %--- default and validate ------------------------------------------------
    if nargin < 2 || isempty(featureList)
        featureList = {'mean','skewness','kurtosis'};
    else
        validateattributes(featureList, {'cell'}, {'vector'}, mfilename, 'featureList', 2);
    end

    valid = { 'mean', 'rms', 'std', 'skewness', 'kurtosis', ...
              'ptp', 'crest', 'impulse', 'clearance', 'shape', ...
              'energy', 'entropy' };
    for i = 1:numel(featureList)
        if ~ismember(featureList{i}, valid)
            error('Unknown feature "%s". Supported names are:\n  %s', ...
                  featureList{i}, strjoin(valid,', '));
        end
    end

    % ensure column-vector
    x = x(:);

    %--- preallocate output ---------------------------------------------------
    nF = numel(featureList);
    features = zeros(1, nF);

    %--- compute each requested feature ---------------------------------------
    for i = 1:nF
        name = featureList{i};
        switch name
            case 'mean'
                features(i) = mean(x);

            case 'rms'
                features(i) = rms(x);

            case 'std'
                features(i) = std(x);

            case 'skewness'
                features(i) = skewness(x);

            case 'kurtosis'
                features(i) = kurtosis(x);

            case 'ptp'  % peak-to-peak
                features(i) = peak2peak(x);

            case 'crest'
                features(i) = max(abs(x)) / rms(x);

            case 'impulse'
                features(i) = max(abs(x)) / mean(abs(x));

            case 'clearance'
                features(i) = max(abs(x)) / mean(sqrt(abs(x)));

            case 'shape'
                features(i) = rms(x) / mean(abs(x));

            case 'energy'
                features(i) = sum(x.^2);

            case 'entropy'
                % requires Signal Processing Toolbox
                features(i) = wentropy(x, 'shannon');

            otherwise
                % should never get here
                error('Unhandled feature "%s".', name);
        end
    end
end
