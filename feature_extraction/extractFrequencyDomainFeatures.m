function features = extractFrequencyDomainFeatures(x, fs, featureList)
% EXTRACTFREQUENCYDOMAINFEATURES  Compute selected freq-domain features for one channel.
%
%   F = extractFrequencyDomainFeatures(x, fs) returns the default four
%     features: [meanFreq, medianFreq, bandwidth, flatness].
%
%   F = extractFrequencyDomainFeatures(x, fs, FEATURELIST) returns only
%   the features named in FEATURELIST (a cell-array of strings), in that order.
%   Supported names are:
%     {'meanFreq','medianFreq','bandwidth','flatness', ...
%      'entropy','skewness','kurtosis'}

    %--- validate inputs ---------------------------------------------------
    if nargin < 3 || isempty(featureList)
        featureList = {'meanFreq','medianFreq','bandwidth','flatness'};
    else
        validateattributes(featureList,{'cell'},{'vector'},mfilename,'featureList',3);
    end

    % list of everything supported
    valid = {'meanFreq','medianFreq','bandwidth','flatness', ...
             'entropy','skewness','kurtosis'};
    for i = 1:numel(featureList)
        if ~ismember(featureList{i}, valid)
            error('Unknown feature "%s". Supported names are: %s', ...
                  featureList{i}, strjoin(valid,', '));
        end
    end

    %--- compute PSD once --------------------------------------------------
    [Pxx, f] = pwelch(x, [], [], [], fs);

    %--- preallocate output ------------------------------------------------
    nF = numel(featureList);
    features = zeros(1,nF);

    %--- compute each requested feature ------------------------------------
    for i = 1:nF
        name = featureList{i};
        switch name
            case {'meanFreq'}
                features(i) = sum(f .* Pxx) / sum(Pxx);

            case 'medianFreq'
                features(i) = medfreq(x, fs);

            case 'bandwidth'
                features(i) = obw(x, fs);

            case 'flatness'
                features(i) = geomean(Pxx) / mean(Pxx);

            case 'entropy'
                features(i) = -sum(Pxx .* log(Pxx));

            case 'skewness'
                features(i) = skewness(Pxx);

            case 'kurtosis'
                features(i) = kurtosis(Pxx);
        end
    end
end
