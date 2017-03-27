function [trackDat,expmt] = autoInitialize(trackDat,expmt,gui_handles)

% clear any objects drawn to gui window
clean_gui(gui_handles.axes_handle);

% set colormap and enable display control
colormap('gray');
set(gui_handles.display_menu.Children,'Checked','off')
set(gui_handles.display_menu.Children,'Enable','on')
gui_handles.display_raw_menu.Checked = 'on';
gui_handles.display_menu.UserData = 1;

%% Initialize tracking variables

trackDat.Centroid=expmt.ROI.centers;                        % last known centroid of the object in each ROI 
trackDat.tStamp = zeros(size(expmt.ROI.centers(:,1),1),1);  % time stamps of centroid updates
trackDat.t = 0;                                             % time elapsed, initialize to zero
trackDat.ct = 0;                                            % frame count
trackDat.drop_ct = zeros(size(expmt.ROI.centers(:,1),1),1); % number of frames dropped for each obj
trackDat.t_ref = 0;                                         % time elapsed since last reference image
trackDat.ref_ct = 0;                                        % num references taken
trackDat.px_dist = zeros(10,1);                             % distribution of pixels over threshold  
trackDat.pix_dev = zeros(10,1);                             % stdev of pixels over threshold

%% Initialize labels, file paths, and files for tracked fields

expmt.date = datestr(clock,'mm-dd-yyyy-HH-MM-SS_');         % get date string
expmt.labels_table = labelMaker(expmt);                           % convert labels cell into table format

% Query label fields and set label for file
lab_fields = expmt.labels_table.Properties.VariableNames;
expmt.fLabel = [expmt.date '_' expmt.Name];
for i = 1:length(lab_fields)
    switch lab_fields{i}
        case 'Strain'
            expmt.(lab_fields{i}) = expmt.labels_table{1,i}{:};
            expmt.fLabel = [expmt.fLabel '_' expmt.labels_table{1,i}{:}];
        case 'Sex'
            expmt.(lab_fields{i}) = expmt.labels_table{1,i}{:};
            expmt.fLabel = [expmt.fLabel '_' expmt.labels_table{1,i}{:}];
        case 'Treatment'
            expmt.(lab_fields{i}) = expmt.labels_table{1,i}{:};
            expmt.fLabel = [expmt.fLabel '_' expmt.labels_table{1,i}{:}];
        case 'Day'
            expmt.(lab_fields{i}) = expmt.labels_table{1,i};
            expmt.fLabel = [expmt.fLabel '_Day' num2str(expmt.labels_table{1,i})];
    end
end

% make a new directory for the files
expmt.fdir = [expmt.fpath '\' expmt.fLabel '\'];
mkdir(expmt.fdir);

% generate file ID for files to write
for i = 1:length(trackDat.fields)                           
    expmt.(trackDat.fields{i}).path = ...                   % initialize path for new file    
        [expmt.fdir expmt.fLabel '_' trackDat.fields{i} '.bin'];
    expmt.(trackDat.fields{i}).fID = ...
        fopen(expmt.(trackDat.fields{i}).path,'w');         % open fileID with write permission
end

% save current parameters to .mat file prior to experiment
params = fieldnames(gui_handles.gui_fig.UserData);
for i = 1:length(params)
    expmt.parameters.(params{i}) = gui_handles.gui_fig.UserData.(params{i});
end
save([expmt.fdir expmt.fLabel '.mat'],'expmt');


%% Setup the camera and/or video object

expmt = getVideoInput(expmt,gui_handles);

% initialize video recording if enabled
if strcmp(gui_handles.record_video_menu.Checked,'on')
    [trackDat,expmt] = initializeVidRecording(trackDat,expmt,gui_handles);
end