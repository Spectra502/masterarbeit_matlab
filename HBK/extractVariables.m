function [label, torque, speed, damageLabel, damageType] = extractVariables(fullFilePath)
% extractVariables - Extracts metadata from file path and filename.
%
% This function now derives the 'label' from the parent folder's name
% and continues to extract torque and speed from the filename itself.

    % --- 1. Extract Label from Folder Name ---
    [folderPath, ~, ~] = fileparts(fullFilePath);
    [~, label, ~] = fileparts(folderPath); % The label is the folder's name

    % --- 2. Define Damage Properties based on Label ---
    % You can customize this section based on your folder names
    switch lower(label)
        case 'healthy'
            damageLabel = 0;
            damageType = 'none';
        case 'micropitting'
            damageLabel = 1;
            damageType = 'micropitting';
        case 'severe_micropitting'
            damageLabel = 2;
            damageType = 'severe_micropitting';
        case 'wear_moderate'
            damageLabel = 3;
            damageType = 'wear_moderate';
        case 'dimples_light'
            damageLabel = 4;
            damageType = 'dimples_light';
        otherwise
            damageLabel = -1; % Or some other default/error value
            damageType = 'unknown';
    end

    % --- 3. Extract Torque and Speed from Filename ---
    [~, inputString, ~] = fileparts(fullFilePath); % Get just the filename

    pattern = '-112_5_';
    startIndex = strfind(inputString, pattern);

    if ~isempty(startIndex)
        startIndex = startIndex + length(pattern);
        remainderString = inputString(startIndex:end);

        numPattern = '(\d+)';
        tokens = regexp(remainderString, numPattern, 'tokens');

        if length(tokens) == 2
            torque = str2double(tokens{1});
            speed = str2double(tokens{2});
        elseif length(tokens) == 4
            torque = str2double(tokens{3});
            speed = str2double(tokens{4});
        else
            torque = NaN;
            speed = NaN;
        end
    else
        torque = NaN;
        speed = NaN;
    end

end