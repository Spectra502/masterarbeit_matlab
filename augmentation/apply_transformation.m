function modifiedStruct = apply_transformation(dataStruct, transformFunc, varargin)
    % Applies a given transformation function to the 'data' field in a struct.
    % 
    % dataStruct: Original struct (e.g., tdmsTables_healthy)
    % transformFunc: Function handle for augmentation (e.g., @augment_gaussian_noise)
    % varargin: Additional parameters for the transform function (e.g., noise level)
    % 
    % Returns:
    % modifiedStruct: Struct with the same format, but with modified data.
    
    modifiedStruct = dataStruct; % Copy input struct
    fieldNames = fieldnames(dataStruct); % Get field names (e.g., dataset names)

    for i = 1:length(fieldNames)
        fieldName = fieldNames{i}; % Extract current field name
        subStruct = dataStruct.(fieldName); % Access nested struct

        % Check if 'data' field exists and is a table
        if isfield(subStruct, 'data') && istable(subStruct.data)
            dataTable = subStruct.data; % Extract table
            
            % Exclude "Time" column (assuming it's always the first column)
            numericData = dataTable{:, 2:end}; % Convert table to numeric (ignore "Time")

            % Apply the transformation function
            transformedData = transformFunc(numericData, varargin{:});

            % Store modified data back into the table
            dataTable{:, 2:end} = transformedData;
            modifiedStruct.(fieldName).data = dataTable; % Save updated table
        else
            warning('Field "data" not found or not a table in %s, skipping...', fieldName);
        end
    end
end
