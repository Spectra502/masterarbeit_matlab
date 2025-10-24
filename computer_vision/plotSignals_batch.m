% plotSignals_batch.m
function plotSignals_batch(plot_data, plot_limits, batch_size)
    % Generates plots in batches to conserve memory.
    
    signal_names = fieldnames(plot_data);
    num_signals = length(signal_names);
    
    if nargin < 3
        batch_size = 50; % Default batch size if not provided
    end

    if ~exist('output_plots', 'dir')
       mkdir('output_plots')
    end
    
    for i = 1:num_signals
        name = signal_names{i};
        data = plot_data.(name);

        fig1 = figure('Visible', 'off');
        plot(data.f_psd, data.psd);
        title(['Power Spectrum (' name ')']);
        ylim([0, plot_limits.max_psd * 1.1]);
        saveas(fig1, fullfile('output_plots', ['psd_' name '.png']));
        close(fig1); % Close the figure immediately after saving

        fig2 = figure('Visible', 'off');
        surf(data.t_spec, data.f_spec, data.s_db, 'EdgeColor', 'none');
        view(2);
        title(['Spectrogram (' name ')']);
        clim([plot_limits.min_spec_db, plot_limits.max_spec_db]);
        % ... (rest of the plot settings)
        saveas(fig2, fullfile('output_plots', ['spectrogram_' name '.png']));
        close(fig2);
        
        % --- Memory management ---
        % Periodically clear variables and check memory if needed.
        % For plotting, closing figures immediately is the most important step.
        % If 'plot_data' is extremely large, you could load it in batches too.
        if mod(i, batch_size) == 0
            fprintf('Processed batch %d of %d signals.\n', i/batch_size, ceil(num_signals/batch_size));
        end
    end
end