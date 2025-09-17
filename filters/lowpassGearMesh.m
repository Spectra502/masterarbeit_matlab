function filteredSignal = lowpassGearMesh(signal, fs, rpm, numTeeth, order)
%LOWPASSGEARMESH  Low-pass filter below the gear-mesh frequency
%
%   filteredSignal = lowpassGearMesh(signal, fs, rpm, numTeeth)
%   filteredSignal = lowpassGearMesh(signal, fs, rpm, numTeeth, order)
%
%   Inputs:
%     - signal   : Nx1 (or 1xN) vector of time-series data
%     - fs       : sampling frequency in Hz
%     - rpm      : rotational speed in revolutions per minute (scalar)
%     - numTeeth : number of teeth on the gear (scalar)
%     - order    : (optional) Butterworth filter order (default = 4)
%
%   Output:
%     - filteredSignal : same size as signal, after low-pass filtering
%
%   The cutoff fc is set to the gear-mesh frequency:
%       fc = (rpm / 60) * numTeeth     [Hz]
%   A Butterworth low-pass is designed with normalized Wn = fc/(fs/2).
%
%   Example:
%     fs = 100e3; rpm = 1800; N = 22;
%     x = randn(10000,1);
%     y = lowpassGearMesh(x, fs, rpm, N);
%
    if nargin < 5
        order = 4;
    end

    % compute gear-mesh frequency (Hz)
    f_gm = (rpm / 60) * numTeeth;

    % normalized cutoff (must be < 1)
    Wn = f_gm / (fs/2);
    if Wn >= 1
        error('Gear‐mesh frequency (%.1f Hz) is ≥ Nyquist (%.1f Hz)', f_gm, fs/2);
    elseif Wn <= 0
        error('Gear‐mesh frequency must be > 0');
    end

    % design Butterworth low-pass
    [b, a] = butter(order, Wn, 'low');

    % apply zero-phase filtering
    filteredSignal = filtfilt(b, a, signal);
end
