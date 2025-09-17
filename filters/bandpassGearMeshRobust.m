function [y, ok] = bandpassGearMeshRobust(x, fs, rpm, numTeeth, bw, order)
% Robust band-pass around GMF with SOS + guards
    if nargin < 6 || isempty(order), order = 4; end
    if nargin < 5 || isempty(bw),    bw    = 50; end

    ok = false;
    x = double(x(:));

    % 1) Sanitize signal
    if ~all(isfinite(x))
        x(~isfinite(x)) = NaN;
        if all(isnan(x)), y = []; return; end
        x = fillmissing(x,'linear','EndValues','nearest');
    end
    % Optional: guard against constant/near-constant signals
    xr = range(x);
    if ~isfinite(xr) || xr == 0, y = []; return; end

    % 2) Compute band and clamp within (0, Nyquist)
    fgm  = (rpm/60)*numTeeth;
    nyq  = fs/2;
    margin   = 1;     % keep at least 1 Hz away from 0/Nyquist
    minHalf  = 1;     % don’t design ultra-narrow <1 Hz half-band
    maxHalf  = max(0, min(fgm - margin, nyq - margin - fgm));
    if maxHalf <= 0, y = []; return; end
    halfBW   = min(max(bw/2, minHalf), maxHalf);
    f1 = fgm - halfBW;  f2 = fgm + halfBW;
    if ~(f1 > 0 && f2 < nyq && f1 < f2), y = []; return; end
    Wn = [f1 f2]/nyq;

    % 3) SOS design for stability
    [z,p,k]   = butter(order, Wn, 'bandpass');
    [sos, g]  = zp2sos(z,p,k);

    % 4) Length check for zero-phase filtering
    nfact = 3*(2*order);    % conservative
    if numel(x) <= nfact, y = []; return; end

    % 5) Filter (prefer sosfiltfilt if available)
    if exist('sosfiltfilt','file') == 2
        y = sosfiltfilt(sos, x*g);
    else
        % filtfilt accepts SOS,G in modern MATLAB; if not, multiply gain into sos path
        y = filtfilt(sos, g, x);
    end

    if isrow(x), y = y.'; end
    ok = true;
end
