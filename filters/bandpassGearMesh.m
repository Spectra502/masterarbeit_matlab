function filteredSignal = bandpassGearMesh(signal, fs, rpm, numTeeth, bw, order)
%BANDPASSGEARMESH  Band-pass filter around the gear-mesh frequency
%
%   y = bandpassGearMesh(x, fs, rpm, numTeeth)
%   y = bandpassGearMesh(x, fs, rpm, numTeeth, bw)
%   y = bandpassGearMesh(x, fs, rpm, numTeeth, bw, order)
%
%   Inputs:
%     x        : Nx1 (or 1xN) time-series
%     fs       : sampling rate [Hz]
%     rpm      : shaft speed [revolutions per minute]
%     numTeeth : number of teeth on the gear
%     bw       : (optional) pass-band width [Hz], default = 10 Hz
%     order    : (optional) Butterworth order, default = 4
%
%   Output:
%     y        : same size as x, band-pass filtered
%
%   The center frequency is the gear-mesh: fc = (rpm/60)*numTeeth.
%   The pass-band edges are [fc–bw/2, fc+bw/2].  A zero-phase
%   Butterworth band-pass is applied via filtfilt.

    % defaults
    if nargin < 6
        order = 4;
    end
    if nargin < 5 || isempty(bw)
        bw = 50;  % Hz
    end

    % compute gear-mesh freq
    f_gm = (rpm/60) * numTeeth;

    % define edges
    f_low  = f_gm - bw/2;
    f_high = f_gm + bw/2;

    % sanity checks
    nyq = fs/2;
    if f_low <= 0
        error('Lower cutoff = %.2f Hz ≤ 0. Reduce bw or increase rpm/numTeeth.', f_low);
    end
    if f_high >= nyq
        error('Upper cutoff = %.2f Hz ≥ Nyquist = %.2f Hz. Reduce bw or increase fs.', f_high, nyq);
    end

    % normalized band edges
    Wn = [f_low, f_high] / nyq;

    % design & apply
    [b, a] = butter(order, Wn, 'bandpass');
    filteredSignal = filtfilt(b, a, signal);
end
