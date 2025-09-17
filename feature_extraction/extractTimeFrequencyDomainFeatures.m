function features = extractTimeFrequencyDomainFeatures(x, fs, featureList)
% EXTRACTTIMEFREQUENCYDOMAINFEATURES  Compute selected time–frequency features for one signal.
%
%   F = extractTimeFrequencyDomainFeatures(x, fs) returns the default
%     three wavelet features: [meanWavelet, varWavelet, entropyWavelet].
%
%   F = extractTimeFrequencyDomainFeatures(x, fs, FEATURELIST) returns
%   only the features named in FEATURELIST (cell-array of strings), in that
%   order. Supported names are:
%     { 'meanWavelet', 'varWavelet', 'entropyWavelet', 'energyWavelet', ...
%       'meanSpectrogram', 'varSpectrogram', 'entropySpectrogram', 'energySpectrogram' }

    %--- default & input check ---------------------------------------------
    if nargin < 3 || isempty(featureList)
        featureList = {'meanWavelet','varWavelet','entropyWavelet'};
    else
        validateattributes(featureList, {'cell'}, {'vector'}, mfilename, 'featureList', 3);
    end

    valid = { 'meanWavelet', 'varWavelet', 'entropyWavelet', 'energyWavelet', ...
              'meanSpectrogram', 'varSpectrogram', 'entropySpectrogram', 'energySpectrogram' };
    for k = 1:numel(featureList)
        if ~ismember(featureList{k}, valid)
            error('Unknown feature "%s". Supported names:\n  %s', ...
                  featureList{k}, strjoin(valid,', '));
        end
    end

    % ensure column vector
    x = x(:);

    %--- compute TF representations once -----------------------------------
    % 1) Wavelet (continuous, analytic Morlet)
    [cfs, ~] = cwt(x, 'amor', fs);
    W = abs(cfs(:));  % flatten all scales & times

    % 2) Spectrogram (window=128, overlap=120, nfft=128)
    [~,~,~,P] = spectrogram(x, 128, 120, 128, fs);
    S = abs(P(:));    % flatten freqs & times

    %--- allocate & compute -----------------------------------------------
    nF = numel(featureList);
    features = zeros(1, nF);
    for k = 1:nF
        name = featureList{k};
        switch name
            case 'meanWavelet'
                features(k) = mean(W);

            case 'varWavelet'
                features(k) = var(W);

            case 'entropyWavelet'
                features(k) = wentropy(W, 'shannon');

            case 'energyWavelet'
                features(k) = sum(W.^2);

            case 'meanSpectrogram'
                features(k) = mean(S);

            case 'varSpectrogram'
                features(k) = var(S);

            case 'entropySpectrogram'
                features(k) = wentropy(S, 'shannon');

            case 'energySpectrogram'
                features(k) = sum(S.^2);

            otherwise
                % should never happen
                error('Unhandled feature "%s".', name);
        end
    end
end
