function process_siza_folders(dataFolders)
% PROCESS_SIZA_FOLDERS_CSV - Processes multiple SIZA data folders containing CSV files in parallel.

    if nargin < 1 || isempty(dataFolders) || ~iscell(dataFolders)
        error('Please provide a cell array of data folder paths.');
    end

    % --- START: Parallel Pool Management ---
    % Check if a parallel pool is already running, if not, start one.
    if isempty(gcp('nocreate'))
        parpool('local'); % Starts a pool with the default number of workers (usually one per core)
    end
    % --- END: Parallel Pool Management ---

    % Loop through each provided data folder (this loop remains sequential)
    for i = 1:numel(dataFolders)
        current_folder = dataFolders{i};
        
        if ~exist(current_folder, 'dir')
            warning('Folder not found, skipping: %s', current_folder);
            continue;
        end

        [~, label, ~] = fileparts(current_folder);
        output_folder_name = sprintf('%s_csv_calculated_frequencies', label);
        output_folder_path = fullfile(current_folder, output_folder_name);
        
        if ~exist(output_folder_path, 'dir')
            mkdir(output_folder_path);
        end
        
        fprintf('Processing folder: %s\n', current_folder);
        fprintf('Results will be saved in: %s\n', output_folder_path);
        
        % Call the analysis function which contains the parallel loop
        analyze_siza_csv_files(current_folder, output_folder_path, label);
    end
    
    % --- Clean up the parallel pool ---
    poolobj = gcp('nocreate');
    delete(poolobj);
    
    fprintf('\nProcessing complete for all folders.\n');
end