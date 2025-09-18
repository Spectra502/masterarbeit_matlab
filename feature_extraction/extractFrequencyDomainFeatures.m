function features = extractFrequencyDomainFeatures(x, fs, featureList)
% EXTRACTFREQUENCYDOMAINFEATURES  Compute selected freq-domain features for one channel.
%
%   ... (help text) ...
%   Supported names are:
%     {'meanFreq','medianFreq','bandwidth','spectral_flatness', ...
%      'spectral_entropy','spectral_skewness','spectral_kurtosis'}

    %--- validate inputs ---------------------------------------------------
    if nargin < 3 || isempty(featureList)
        featureList = {'meanFreq','medianFreq','bandwidth','spectral_flatness'};
    else
        validateattributes(featureList,{'cell'},{'vector'},mfilename,'featureList',3);
    end

    % --- UPDATED: List of everything supported with new names ---
    valid = {'meanFreq','medianFreq','bandwidth','spectral_flatness', ...
             'spectral_entropy','spectral_skewness','spectral_kurtosis'};
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
        % --- UPDATED: Switch statement with new names ---
        switch name
            case 'meanFreq'
                features(i) = sum(f .* Pxx) / sum(Pxx);
            case 'medianFreq'
                features(i) = medfreq(x, fs);
            case 'bandwidth'
                features(i) = obw(x, fs);
            case 'spectral_flatness'
                features(i) = geomean(Pxx) / mean(Pxx);
            case 'spectral_entropy'
                features(i) = -sum(Pxx .* log(Pxx));
            case 'spectral_skewness'
                features(i) = skewness(Pxx);
            case 'spectral_kurtosis'
                features(i) = kurtosis(Pxx);
        end
    end
end