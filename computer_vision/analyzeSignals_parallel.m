% analyzeSignals_parallel.m
function [plot_data, plot_limits] = analyzeSignals_parallel(signals)
    % Uses a parallel for-loop (parfor) to speed up the analysis.
    
    signal_names = fieldnames(signals);
    num_signals = length(signal_names);
    sampling_rate = 1000;

    % Create temporary cell arrays to store results from parallel workers
    psd_data = cell(num_signals, 1);
    spec_data = cell(num_signals, 1);
    
    parfor i = 1:num_signals
        name = signal_names{i};
        current_signal = signals.(name);
        
        % Perform calculations as before
        [psd, f_psd] = pspectrum(current_signal, sampling_rate);
        [s, f_spec, t_spec] = spectrogram(current_signal, 64, 32, [], sampling_rate);
        s_db = 10*log10(abs(s));
        
        % Store results for this worker
        psd_data{i} = {name, psd, f_psd};
        spec_data{i} = {name, s_db, f_spec, t_spec};
        
        % Display progress (optional, but helpful for long runs)
        fprintf('Analyzed signal: %s\n', name);
    end
    
    % --- Combine results after the parallel loop ---
    % This part must be a regular loop, as we need to aggregate the results.
    plot_data = struct();
    plot_limits.max_psd = 0;
    plot_limits.min_spec_db = inf;
    plot_limits.max_spec_db = -inf;
    
    for i = 1:num_signals
        % Unpack PSD data
        name = psd_data{i}{1};
        psd = psd_data{i}{2};
        f_psd = psd_data{i}{3};
        plot_data.(name).psd = psd;
        plot_data.(name).f_psd = f_psd;
        plot_limits.max_psd = max(plot_limits.max_psd, max(psd));
        
        % Unpack Spectrogram data
        s_db = spec_data{i}{2};
        f_spec = spec_data{i}{3};
        t_spec = spec_data{i}{4};
        plot_data.(name).s_db = s_db;
        plot_data.(name).f_spec = f_spec;
        plot_data.(name).t_spec = t_spec;
        plot_limits.min_spec_db = min(plot_limits.min_spec_db, min(s_db, [], 'all'));
        plot_limits.max_spec_db = max(plot_limits.max_spec_db, max(s_db, [], 'all'));
    end
end