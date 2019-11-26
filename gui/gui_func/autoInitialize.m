function [trackDat,expmt] = autoInitialize(trackDat,expmt,gui_handles)
% Initialization routine for all MARGO protocols:
%
%   - initializes and configures hardware devices with selected settings
%   - initializes the trackDat struct
%   - initializes raw binary data files and associated RawDataFields
%   - initializes labels from the label data
%   - initializes display handles
%   - opens the video input source (camera or video file)

% load COM device settings
dev_status = expmt.hardware.COM.status;
com_settings = expmt.hardware.COM.settings;
for i=1:numel(dev_status)
    dev = expmt.hardware.COM.devices{i};
    switch dev_status{i}
        case 'open'
            [dev, com_settings, ~] = load_com_settings(dev, i, com_settings);
            if strcmpi(dev.status,'closed')
               fopen(dev);
            end
        case 'closed'
            if strcmpi(dev.status,'open')
               fclose(dev);
            end
    end
    expmt.hardware.COM.status{i} = dev.status;
end

% Initialize infrared and white illuminators
writeInfraredWhitePanel(expmt.hardware.COM.light,1,...
                        expmt.hardware.light.infrared);
writeInfraredWhitePanel(expmt.hardware.COM.light,0,...
                        expmt.hardware.light.white);

% clear any objects drawn to gui window
clean_gui(gui_handles.axes_handle);

% initialize tracking variables
trackDat.tStamp = ...
    repmat({zeros(1)}, expmt.meta.roi.n, 1);                               % time stamps of centroid updates

%%
% create new "trace" fields trackDat.traces and trackDat.candidates

% tracking fields
expmt = trim_fields(expmt);
if isfield(trackDat,'fields')
    ff = trackDat.fields;
    trackDat = initializeTrackDat(expmt);

    % enforce minimum mandatory fields
    mandatory_fields = {'centroid';'time';'dropped_frames'};
    missing_ff = cellfun(@(mf) ~any(strcmpi(mf,ff)),mandatory_fields);
    ff = [ff;mandatory_fields(missing_ff)];
    trackDat.fields = ff;
else
    trackDat = initializeTrackDat(expmt);
end

cam_center = repmat(fliplr(size(expmt.meta.ref)./2),...
                size(expmt.meta.roi.centers));
expmt.meta.roi.cam_dist = ...
    sqrt((expmt.meta.roi.centers(:,1)-cam_center(:,1)).^2 + ...
        (expmt.meta.roi.centers(:,2)-cam_center(:,2)).^2);

% set colormap and enable display control

       colormap(cmsat());
set_display_mode(gui_handles.display_menu,'raw');

if strcmp(expmt.meta.source,'camera') && ~isvalid(expmt.hardware.cam.vid)
    expmt = getVideoInput(expmt,gui_handles);
end

if ~expmt.meta.initialize
    return
end

%% estimate num data entries

nDataPoints = expmt.parameters.duration * ...
    expmt.parameters.target_rate * 3600 * length(expmt.meta.roi.centers);
if nDataPoints > 1E7
    msg = {'WARNING: high estimated number of data points';...
        ['ROIs x Target Rate x Duration = ' num2str(nDataPoints,2)];...
        'consider lowering acquisition rate to reduce file size'};
    gui_notify(msg,gui_handles.disp_note);
end

%% update de-bivort monitor server

if isfield(gui_handles,'deviceID')

    webop = weboptions('Timeout',0.65);
    status=true;
    try
        minstr = num2str(round(expmt.parameters.duration * 60));
        minstr = [repmat('0',1,4-length(minstr)) minstr];
        webread(['http://lab.debivort.org/mu.php?id=' ...
            gui_handles.deviceID '&st=1' minstr],webop);
    catch
        status = false;
    end
    if ~status
        gui_notify(['unable to connect to '...
            'http://lab.debivort.org'],gui_handles.disp_note);
    end
end

%% Initialize labels, file paths, and files for tracked fields

expmt.meta.date = datestr(clock,'mm-dd-yyyy-HH-MM-SS_');
expmt.meta.labels_table = labelMaker(expmt);

% Query label fields and set label for file
lab_fields = expmt.meta.labels_table.Properties.VariableNames;
expmt.meta.path.name = [expmt.meta.date '_' expmt.meta.name];
for i = 1:length(lab_fields)
    switch lab_fields{i}
        case 'Strain'
            expmt.meta.(lab_fields{i}) = expmt.meta.labels_table{1,i}{:};
            expmt.meta.path.name = ...
                [expmt.meta.path.name '_' expmt.meta.labels_table{1,i}{:}];
        case 'Sex'
            expmt.meta.(lab_fields{i}) = expmt.meta.labels_table{1,i}{:};
            expmt.meta.path.name = ...
                [expmt.meta.path.name '_' expmt.meta.labels_table{1,i}{:}];
        case 'Treatment'
            expmt.meta.(lab_fields{i}) = expmt.meta.labels_table{1,i}{:};
            expmt.meta.path.name = ...
                [expmt.meta.path.name '_' expmt.meta.labels_table{1,i}{:}];
        case 'Day'
            if ~isnan(expmt.meta.labels_table{1,i})
                expmt.meta.(lab_fields{i}) = expmt.meta.labels_table{1,i};
                expmt.meta.path.name = ...
                    [expmt.meta.path.name '_Day' ...
                    num2str(expmt.meta.labels_table{1,i})];
            end
        case 'ID'
            if ~isnan(expmt.meta.labels_table{1,i})
                ids = expmt.meta.labels_table{:,i};
                expmt.meta.path.name = ...
                    [expmt.meta.path.name '_' num2str(ids(1))...
                    '-' num2str(ids(end))];
            end
    end
end

% remove any illegal characters from path
illegal = ' *."/\[]:;|=,';
expmt.meta.path.name(ismember(expmt.meta.path.name,illegal))='_';

% make a new directory for the files
expmt.meta.path.dir = ...
    unixify([expmt.meta.path.full '/' expmt.meta.path.name '/']);
mkdir(expmt.meta.path.dir);
expmt.meta.rawdir = ...
    unixify([expmt.meta.path.full '/' expmt.meta.path.name '/raw_data/']);
mkdir(expmt.meta.rawdir);

% add any optional fields
f=trackDat.fields;
append_fields = cellfun(@(x) ~any(strcmp(x,expmt.meta.fields)),f);
for i = 1:length(append_fields)
    % initialize new raw data field
    if append_fields(i)
        expmt.data.(f{i}) = RawDataField('Parent',expmt);
    end
end
if size(expmt.meta.fields,2) > 1
    expmt.meta.fields = expmt.meta.fields';
end
expmt.meta.fields = [expmt.meta.fields; f(append_fields)];
trackDat.fields = expmt.meta.fields;

% generate file ID for files to write
for i = 1:length(trackDat.fields)

    expmt.data.(trackDat.fields{i}).path = ...
        [expmt.meta.rawdir expmt.meta.date '_' trackDat.fields{i} '.bin'];
    if numel(expmt.data.(trackDat.fields{i}).path) > 260
        error(['RAW DATA file path exceeds maximum allowed length. '...
            'Shorten the file path and initialize the experiment again. '...
            'Note: label information such as strain and treatment are '...
            'automatically incorporated into the file path and may'...
            'need to be abbreviated. ']);
    end
    if strcmpi(trackDat.fields{i},'weightedCentroid')
        trackDat.weightedCentroid = trackDat.centroid;
    end
    % open fileID with write permission
    expmt.data.(trackDat.fields{i}).fID = ...
        fopen(expmt.data.(trackDat.fields{i}).path,'W');
end

% save current parameters to .mat file prior to experiment
save([expmt.meta.path.dir expmt.meta.path.name '.mat'],'expmt');

%% Setup the camera and/or video object

expmt = getVideoInput(expmt,gui_handles);
switch expmt.meta.source
    case 'video'
        expmt.meta.video.current_frame = 1;
end

% initialize video recording if enabled
if isfield(expmt.meta,'video_out') && expmt.meta.video_out.record
    expmt = initializeVidRecording(expmt,gui_handles);
elseif isfield(trackDat,'video_index') || ...
        any(strcmpi('video_index',expmt.meta.fields)) || ...
        any(strcmpi('video_index',trackDat.fields)) || ...
        (isfield(expmt.meta,'video_out') && ~expmt.meta.video_out.subsample)

    % remove video index from raw data output if video is not recorded
    expmt.meta.fields(strcmpi('video_index',expmt.meta.fields)) = [];
    trackDat.fields(strcmpi('video_index',trackDat.fields)) = [];
    if any(strcmpi('video_index',fieldnames(expmt.data)))
        expmt.data = rmfield(expmt.data,'video_index');
    end
    if any(strcmpi('video_index',fieldnames(trackDat)))
        trackDat = rmfield(trackDat,'video_index');
    end
end

expmt.meta.initialize = false;
expmt.meta.finish = true;
expmt.meta.num_traces = sum(expmt.meta.roi.num_traces);

% initialize centroid markers
clean_gui(gui_handles.axes_handle);
hold on
trackDat.hMark = ...
    plot(trackDat.centroid(:,1),trackDat.centroid(:,2),'ro',...
        'Parent',gui_handles.axes_handle);
hold off

% start the timer for the experiment
tic;
trackDat.tPrev = toc;
trackDat.lastFrame = false;
gui_notify('tracking initialized',gui_handles.disp_note);
