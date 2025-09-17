function tdmsTables = processTDMSFilesAutomated( ...
        decimateFactor, imageFolder, normalization_method, ...
        fileList, folderPath)
    % processTDMSFilesAutomated  Process all .tdms in one folder
    %
    % Inputs:
    %   decimateFactor       (opt) integer ≥1, default = 1
    %   imageFolder          (opt) path to save FFT plots, default = ''
    %   normalization_method (opt) 'robust_scaling'|'min_max'|'z_score'
    %   fileList             cell array of .tdms filenames
    %   folderPath           string: folder containing those files
    %
    % Output:
    %   tdmsTables           struct with one field per file

    %—— 1) Defaults ——
    if nargin < 1 || isempty(decimateFactor),       decimateFactor = 1;       end
    if nargin < 2,       imageFolder    = '';      end
    if nargin < 3,       normalization_method = ''; end
    if nargin < 5
        error('Must supply fileList and folderPath as inputs');
    end

    tdmsTables = struct();

    %—— 2) Bail out if empty ——
    if isempty(fileList)
        warning('No .tdms files to process in "%s".', folderPath);
        return;
    end

    %—— 3) Loop over each file in this folder ——
    for k = 1:numel(fileList)
        fname    = fileList{k};
        fullpath = fullfile(folderPath, fname);

        % extract metadata
        [label, torque, speed, damageLabel, damageType] = extractVariables(fname);
        
        [~, label] = fileparts(folderPath)
        % read TDMS
        raw       = tdmsread(fullpath)
        dataTable = raw{1};

        % decimate & normalize
        if decimateFactor > 1
            fs = 100000/decimateFactor;
            sampledData = dataTable(1:decimateFactor:end, :);
            sampledData{:,2} = decimate(dataTable{:,2}, decimateFactor);
            %shift_amount = round(0.22 * numel(sampledData{:,2}));
            switch normalization_method
                case 'augment_translation'
                    sampledData{:,2} = augment_translation(sampledData{:,2}, shift_amount);
                case 'normal'
                    sampledData{:,2} = sampledData{:,2};
                case 'highpass'
                    sampledData{:,2} = min_max_normalization(sampledData{:,2});
                    sampledData{:,2} = highpassGearMesh(sampledData{:,2}, fs, speed, 22, 4);
                case 'lowpass'
                    sampledData{:,2} = min_max_normalization(sampledData{:,2});
                    sampledData{:,2} = lowpassGearMesh(sampledData{:,2}, fs, speed, 22, 4);
                case 'bandpass'
                    sampledData{:,2} = min_max_normalization(sampledData{:,2});
                    sampledData{:,2} = bandpassGearMesh(sampledData{:,2}, fs, speed, 22, 50);
            end
            if ~isempty(imageFolder)
                %plotFFTAndSave( sampledData{:,2}, fs, speed, 22, ...
                %   'HBK_transformed', label, speed, torque, imageFolder);
            end
        else
            sampledData = dataTable;
            fs = 100000;
        end

        % make safe field name
        [~, base, ~]   = fileparts(fname);
        fld            = matlab.lang.makeValidName(base);

        % save
        tdmsTables.(fld).data        = sampledData;
        tdmsTables.(fld).fs          = fs;
        tdmsTables.(fld).label       = label;
        tdmsTables.(fld).torque      = torque;
        tdmsTables.(fld).speed       = speed;
        tdmsTables.(fld).damageLabel = damageLabel;
        tdmsTables.(fld).damageType  = damageType;
    end
end
