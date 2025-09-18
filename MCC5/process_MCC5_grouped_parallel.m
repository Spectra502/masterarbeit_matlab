function process_MCC5_grouped_parallel(varargin)
% PROCESS_MCC5_GROUPED_PARALLEL  Extract features per group (speed/torque)
% from a single folder of CSV files using parallel workers.
%
% Usage examples:
%   % Process only "speed_circulation" files, channel by name, high-pass:
%   process_SIZA_grouped_parallel('SourceFolder','H:\...\SIZA\CSV\pitting', ...
%       'Group','speed', 'SelectedChannel','CH1', ...
%       'FilterMode','highpass', 'TargetRoot','H:\...\Extracted_Features');
%
%   % Process only "torque_circulation" files, channel index 2, band-pass 50 Hz:
%   process_SIZA_grouped_parallel('Group','torque', 'SelectedChannel',2, ...
%       'FilterMode','bandpass', 'Bandwidth',50);
%
% PARAMETERS (Name-Value):
%   'SourceFolder'   : folder with the CSV files (default: current folder)
%   'TargetRoot'     : root for outputs (default: '<SourceFolder>\..\Extracted_Features')
%   'Group'          : 'speed' or 'torque'   [ONLY files from this group are processed]
%   'SelectedChannel': column name OR 1-based index of the channel to use
%   'FilterMode'     : 'none' | 'highpass' | 'bandpass'   (default 'highpass')
%   'Bandwidth'      : band width for band-pass around GMF (Hz), default 50
%   'Order'          : Butterworth order (default 4)
%   'Zteeth'         : gear teeth for GMF (default 22)
%   'MinFs'          : lower fs bound to keep (default 5000 Hz)
%   'MaxFs'          : upper fs bound to keep (default 20000 Hz)
%
% CSV expectations:
%   - One column per channel (with headers). The function prints the header
%     names it detects in the FIRST file so you can pick 'SelectedChannel'.
%   - Sampling frequency (EstimatedFS) is looked up from:
%       <SourceFolder>\<LABEL>_csv_fs_calculated\<LABEL>_csv_calculated_frequencies.csv
%     where LABEL is inferred from the filename prefix (e.g., 'gear_pitting_H').
%
% POSSIBLE CHANNELS (examples; your file will print exact names at runtime):
%   % {'CH1','CH2','CH3','AccX','AccY','AccZ','Mic','Vib1','Vib2', ...}
%
% Notes:
%   - Writes to: <TargetRoot>\<label>\time  \frequency  \time-frequency
%   - Calls your process_vectorSignal once per DOMAIN (no mixing).
%   - Uses a process-based pool (so plotting inside workers won’t error).

%% ---------- Parameters ----------
ip = inputParser;
ip.addParameter('SourceFolder', pwd, @(s)ischar(s)||isstring(s));
ip.addParameter('TargetRoot', '', @(s)ischar(s)||isstring(s));
ip.addParameter('Group', 'speed', @(s)any(strcmpi(s,{'speed','torque'})));
ip.addParameter('SelectedChannel', [], @(x)ischar(x)||isstring(x)||isscalar(x));
ip.addParameter('FilterMode', 'highpass', @(s)any(strcmpi(s,{'none','highpass','bandpass'})));
ip.addParameter('Bandwidth', 50, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('Order', 4, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('Zteeth', 22, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('MinFs', 5000, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('MaxFs', 20000, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.parse(varargin{:});
P = ip.Results;

sourceFolder = char(P.SourceFolder);
if isempty(P.TargetRoot)
    targetRoot = fullfile(fileparts(sourceFolder), 'Extracted_Features');
else
    targetRoot = char(P.TargetRoot);
end
groupWanted = lower(P.Group);
selChan = P.SelectedChannel;
filterMode = lower(P.FilterMode);
bw = P.Bandwidth;
order = P.Order;
Zteeth = P.Zteeth;
minFs = P.MinFs;
maxFs = P.MaxFs;

addpath('H:\Masterarbeit\Experiment_Database\normalization'); % your utils

if ~exist(targetRoot,'dir'), mkdir(targetRoot); end

%% ---------- File discovery & filename parsing ----------
csvFiles = dir(fullfile(sourceFolder, '*.csv'));
if isempty(csvFiles)
    disp('No CSV files found.'); return;
end

% Parse every filename: label, group, rpm, torque
n = numel(csvFiles);
info = repmat(struct('label',"", 'group',"", 'rpm',NaN, 'torque',NaN), n,1);
for k = 1:n
    info(k) = parse_name(csvFiles(k).name);
end

% Filter by wanted group
maskGroup = strcmpi({info.group}', groupWanted);
if ~any(maskGroup)
    warning('No files of group "%s" found.', groupWanted);
    return
end

% Infer LABEL from filenames (prefix before "_speed_circulation"/"_torque_circulation")
labels = string({info.label}');
uLabels = unique(labels(maskGroup));
if numel(uLabels) > 1
    warning('Multiple labels detected: %s. Using first: %s', strjoin(uLabels,', '), uLabels(1));
end
label = char(uLabels(1));

%% ---------- Load sampling frequency table (EstimatedFS) ----------
calcDir  = fullfile(sourceFolder, sprintf('%s_csv_fs_calculated', label));
calcPath = fullfile(calcDir, sprintf('%s_csv_calculated_frequencies.csv', label));
if ~exist(calcPath,'file')
    error('FS table not found: %s', calcPath);
end
Tfs = readtable(calcPath);
Tnames = lower(string(Tfs.Filename));
allNames = lower(string({csvFiles.name}'));
[tfMatch, loc] = ismember(allNames, Tnames);
fsVec = nan(n,1);
fsVec(tfMatch) = round(Tfs.EstimatedFS(loc(tfMatch)));

% Keep only the chosen group AND with valid fs
idx = find(maskGroup & ~isnan(fsVec) & fsVec>=minFs & fsVec<=maxFs);
if isempty(idx)
    warning('No files satisfy group=%s AND %g<=fs<=%g Hz.', groupWanted, minFs, maxFs);
    return
end

% Nyquist safety vs GMF
speedVec = [info.rpm]';
GMFVec   = (speedVec/60) * Zteeth;
nyqVec   = fsVec/2;
validNyq = GMFVec < nyqVec;
idx = idx(validNyq(idx));
if isempty(idx)
    warning('All files violate GMF < Nyquist. Nothing to do.'); return
end

fprintf('Processing %d/%d files in group "%s" (label "%s").\n', numel(idx), n, groupWanted, label);

%% ---------- Build output folders ----------
labelFolder = fullfile(targetRoot, label);
timeDir = fullfile(labelFolder, 'time');
freqDir = fullfile(labelFolder, 'frequency');
tfDir   = fullfile(labelFolder, 'time-frequency');
if ~exist(labelFolder,'dir'), mkdir(labelFolder); end
if ~exist(timeDir,'dir'), mkdir(timeDir); end
if ~exist(freqDir,'dir'), mkdir(freqDir); end
if ~exist(tfDir,'dir'), mkdir(tfDir); end

%% ---------- Show channel names from the FIRST file ----------
firstFile = fullfile(sourceFolder, csvFiles(idx(1)).name);
opts1 = detectImportOptions(firstFile, 'NumHeaderLines',0);
% Tip: choose your channel from the list below (printed in the console):
disp('Available columns in CSV (choose "SelectedChannel" by name or index):');
disp(opts1.VariableNames);

% If user chose by index, remember we'll use the k-th column of the table.

%% ---------- Parallel pool ----------
if isempty(gcp('nocreate')), parpool('Processes'); end
pctRunOnAll addpath('H:\Masterarbeit\Experiment_Database\normalization');

segment_length = 1000;
overlap        = 500;

%% ---------- PARFOR ----------
parfor ii = 1:numel(idx)
    k = idx(ii);
    fileName     = csvFiles(k).name;
    fullFilePath = fullfile(sourceFolder, fileName);
    fs     = fsVec(k);
    rpm    = info(k).rpm;
    torque = info(k).torque;

    try
        % Read table and select one channel
        opts = detectImportOptions(fullFilePath, 'NumHeaderLines',0);
        Tsig = readtable(fullFilePath, opts);

        % Select channel by name or index
        if isempty(selChan)
            % default: first numeric column
            numericMask = varfun(@isnumeric, Tsig, 'OutputFormat','uniform');
            if ~any(numericMask)
                warning('No numeric columns in %s. Skipping.', fileName);
                continue
            end
            x = Tsig{:, find(numericMask,1,'first')};
            chanName = Tsig.Properties.VariableNames{find(numericMask,1,'first')};
        elseif isnumeric(selChan)
            idxCol = selChan;
            if idxCol < 1 || idxCol > width(Tsig)
                warning('SelectedChannel index out of range for %s. Skipping.', fileName);
                continue
            end
            x = Tsig{:, idxCol};
            chanName = Tsig.Properties.VariableNames{idxCol};
        else
            vname = char(selChan);
            if ~ismember(vname, Tsig.Properties.VariableNames)
                warning('SelectedChannel "%s" not found in %s. Skipping.', vname, fileName);
                continue
            end
            x = Tsig.(vname);
            chanName = vname;
        end

        % Ensure column vector, finite & normalized
        x = x(:);
        if ~all(isfinite(x))
            x(~isfinite(x)) = NaN;
            if all(isnan(x)), warning('All-NaN signal in %s. Skipping.', fileName); continue; end
            x = fillmissing(x,'linear','EndValues','nearest');
        end
        xmin = min(x); xmax = max(x);
        if xmax == xmin, warning('Constant signal in %s. Skipping.', fileName); continue; end
        x = (x - xmin) / (xmax - xmin);

        % Filter (if requested)
        switch filterMode
            case 'highpass'
                y = highpassGearMeshRobust(x, fs, rpm, Zteeth, order);
            case 'bandpass'
                [y, ok] = bandpassGearMeshRobust(x, fs, rpm, Zteeth, bw, order);
                if ~ok
                    fprintf('Skipping %s after bandpass guards.\n', fileName);
                    continue
                end
            otherwise % 'none'
                y = x;
        end

        % One domain at a time (no mixing)
        process_vectorSignal(y, timeDir, segment_length, overlap, ...
                             fs, {'time'}, label, rpm, torque, chanName, true);

        process_vectorSignal(y, freqDir, segment_length, overlap, ...
                             fs, {'frequency'}, label, rpm, torque, chanName, true);

        process_vectorSignal(y, tfDir,   segment_length, overlap, ...
                             fs, {'time-frequency'}, label, rpm, torque, chanName, true);

    catch ME
        warning('Failed on %s: %s', fileName, ME.message);
    end
end

end % main function


%% ===== Helpers =====

function s = parse_name(fname)
% Parse 'label_group_circulation_<A><UnitA>[-|_]<B><UnitB>.csv'
% Handles both:
%   ..._speed_circulation_10Nm-1000rpm.csv
%   ..._torque_circulation_2000rpm_20Nm.csv
    s = struct('label',"", 'group',"", 'rpm',NaN, 'torque',NaN);
    [~, base] = fileparts(fname);
    expr = '(?i)^(?<label>.+?)_(?<group>speed|torque)_circulation_(?<n1>\d+)(?<u1>rpm|nm)[-_](?<n2>\d+)(?<u2>rpm|nm)$';
    m = regexp(base, expr, 'names', 'once');
    if isempty(m)
        return
    end
    s.label = string(m.label);
    s.group = lower(string(m.group));
    % Assign rpm/torque based on units
    n1 = str2double(m.n1); n2 = str2double(m.n2);
    if strcmpi(m.u1,'rpm'), s.rpm = n1; else, s.torque = n1; end
    if strcmpi(m.u2,'rpm'), s.rpm = n2; else, s.torque = n2; end
end

