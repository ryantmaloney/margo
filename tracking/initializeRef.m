function [expmt] = initializeRef(gui_handles,expmt)


clearvars -except gui_handles expmt

gui_notify('initializing reference',gui_handles.disp_note);

gui_fig = gui_handles.gui_fig;
imh = findobj(gui_handles.axes_handle,'-depth',3,'Type','image');   % image handle

if isempty(imh)
    % Take single frame
    switch expmt.meta.source
        case 'camera'
            trackDat.im = peekdata(expmt.hardware.cam.vid,1);
        case 'video'
            [trackDat.im, expmt.meta.video] = nextFrame(expmt.meta.video,gui_handles);
    end
    imh = imagesc(trackDat.im);
elseif strcmp(imh.CDataMapping,'direct')
    imh.CDataMapping = 'scaled';
end

% enable display adjustment and set set the view to thresholded by default
colormap('gray');
set(gui_handles.display_menu.Children,'Enable','on');
set(gui_handles.display_menu.Children,'Checked','off');
set(gui_handles.display_threshold_menu,'Checked','on');
gui_handles.display_menu.UserData = 3;
gui_handles.accept_track_thresh_pushbutton.Value = 0;

%% Setup the camera and/or video object

expmt = getVideoInput(expmt,gui_handles);

%% Assign parameters and placeholders

% Reference vars
nROIs = size(expmt.meta.roi.corners, 1);             % total number of ROIs
depth = gui_handles.edit_ref_depth.Value;       % number of rolling sub references
trackDat.ref.cen = NaN(nROIs,2,depth);          % placeholder for cen. coords where references are taken
trackDat.ref.ct = zeros(nROIs, 1);              % Reference number placeholder
trackDat.ref.t = 0;                             % reference time stamp
trackDat.ref.last_update = zeros(nROIs,1);
trackDat.ref.bg_mode = 'light';                 % set reference mode to dark
                                                % obj on light background


% tracking vars
trackDat.fields={'centroid';'area';'majorAxisLength'};  % Define fields for regionprops
trackDat.centroid=expmt.meta.roi.centers;                   	% placeholder for most recent non-NaN centroids
trackDat.tStamp=zeros(nROIs,1);
trackDat.ct = 0;
blob_lengths = NaN(100,1);


% Set maximum allowable distance to center of ROI as the long axis of the ROI
if expmt.parameters.distance_thresh == 20
    widths=(expmt.meta.roi.bounds(:,3));
    heights=(expmt.meta.roi.bounds(:,4));
    w=median(widths);
    h=median(heights);
    expmt.parameters.distance_thresh = ...
        round(sqrt(w^2+h^2)/2*0.9*10)/10 * expmt.parameters.mm_per_pix;
    gui_handles.edit_dist_thresh.String = ...
        num2str(expmt.parameters.distance_thresh);
end

% set min distance from previous ref locations before acquiring new ref for any given object
trackDat.ref.thresh = expmt.parameters.distance_thresh * 0.5;  

% Initialize reference with single image
[trackDat,expmt] = autoFrame(trackDat,expmt,gui_handles);
trackDat.ref.im = trackDat.im;
tmp_ref = trackDat.ref.im;
trackDat.ref.stack = squeeze(num2cell(repmat(trackDat.ref.im,1,1,depth),[1 2]));
pause(0.1);

% initialize variables for ref bg_mode auto detection           
dDifference = NaN(35,2);
diffStack = cell(2,1);
diffStack(:) = {uint8(zeros(size(trackDat.im,1),...
                    size(trackDat.ref.im,2),2))};


%% initialize display objects

clean_gui(gui_handles.axes_handle);
imh = findobj(gui_handles.axes_handle,'-depth',3,'Type','Image');
set(gca,'Xtick',[],'Ytick',[]);     % turn off tick marks
clearvars hCirc hText

% Initialize color variables
hsv_base = 360;                         % hsv red
hsv_targ = 240;                         % hsv blue
color_scale = 1 - hsv_targ/hsv_base;

% initialize 
hold on
color = zeros(nROIs,3);
color(:,1) = 1;
hCirc = scatter(expmt.meta.roi.corners(:,1),expmt.meta.roi.corners(:,2),...
    'o','filled','LineWidth',2);
hCirc.CData = color;

hold off


%% Collect reference until timeout OR "accept reference" GUI press

% Time stamp placeholders
trackDat.t = 0;
tic
trackDat.tPrev=toc;

while trackDat.t < expmt.parameters.duration*3600 &&...
        ~gui_handles.accept_track_thresh_pushbutton.Value
    
    trackDat.ref.freq = 30;
    
    % update time stamps and frame rate
    [trackDat] = autoTime(trackDat, expmt, gui_handles);

    % query next frame and optionally correct lens distortion
    [trackDat,expmt] = autoFrame(trackDat,expmt,gui_handles);
    
    if trackDat.ct == 0
        diffim = (trackDat.ref.im - expmt.meta.vignette.im) -...
                    (trackDat.im - expmt.meta.vignette.im);
        tmp_thresh = floor(graythresh(diffim)*255);
        
        if tmp_thresh > 4
            gui_handles.track_thresh_slider.Value = tmp_thresh;
            feval(gui_handles.track_thresh_slider.Callback,...
                gui_handles.track_thresh_slider,[]);
        end
    end

    % track objects and sort to ROIs
    [trackDat] = autoTrack(trackDat,expmt,gui_handles);
    
    % update blob length distribution
    if any(isnan(blob_lengths)) && any(~isnan(trackDat.majorAxisLength))
        n_remain = sum(isnan(blob_lengths));
        n_available = sum(~isnan(trackDat.majorAxisLength));
        if n_available <= n_remain
            idx = numel(blob_lengths)-n_remain+1;
            blob_lengths(idx:idx+n_available-1) =...
                trackDat.majorAxisLength(~isnan(trackDat.majorAxisLength));
        else
            idx = numel(blob_lengths)-n_remain+1;
            blob_lengths(idx:end) =...
                trackDat.majorAxisLength(...
                find(~isnan(trackDat.majorAxisLength),n_remain));
        end
        if ~any(isnan(blob_lengths))          
           tmp_thresh = (mean(blob_lengths) + std(blob_lengths)*3)*1.2;
           if tmp_thresh < trackDat.ref.thresh
                trackDat.ref.thresh = tmp_thresh;
           end
           trackDat.fields(strcmp(trackDat.fields,'majorAxisLength'))=[];
        end
    end

    % update ref at the reference frequency
    trackDat.px_dev = 0;
    [trackDat, expmt] = autoReference(trackDat, expmt, gui_handles);   

    % Update display
    if gui_handles.display_menu.UserData ~= 5
        
        % update the display
        autoDisplay(trackDat, expmt, imh, gui_handles);   
        nRefs = trackDat.ref.ct;

        % Update color indicator
        hue = 1-color_scale.*nRefs./depth;
        hsv_color = ones(numel(hue),3);
        hsv_color(:,1) = hue;
        color = hsv2rgb(hsv_color); 

        % Draw last known centroid for each ROI and update ref. number indicator
        hCirc.CData = color;
    end

    if trackDat.ct <= size(dDifference,1)
        % compute frame to frame change in the magnitude of the difference of
        % the difference image with bg_mode = 'light' and bg_mode = 'dark'
        diffStack{1}(:,:,mod(trackDat.ct-1,2)+1) = tmp_ref - trackDat.im;
        diffStack{2}(:,:,mod(trackDat.ct-1,2)+1) = trackDat.im - tmp_ref;
        tmp_dDif = cellfun(@(x) ...
            abs(diff(single(x),1,3)), diffStack,'UniformOutput',false);
        dDifference(mod(trackDat.ct-1,size(dDifference,1))+1,:) = ...
            cellfun(@(x) sum(x(:)),tmp_dDif);
    
        % select appropriate reference mode
        if ~any(isnan(dDifference(:)))
           
            avg_deltaDiff = nanmean(dDifference);
            if avg_deltaDiff(1) > avg_deltaDiff(2)
                trackDat.ref.bg_mode = 'light';
                gui_notify('detected dark objects on light background',...
                    gui_handles.disp_note);
            else
                trackDat.ref.bg_mode = 'dark';
                gui_notify('detected light objects on dark background',...
                    gui_handles.disp_note);
            end
            
        end
    end
    
    drawnow limitrate
    
end



%% Reset UI properties
trackDat.t = 0;
tic
trackDat.tPrev = toc;
autoTime(trackDat, expmt, gui_handles);
expmt.meta.ref = trackDat.ref;


expmt.meta.vignette.im = filterVignetting(expmt);

% Reset accept reference button
set(gui_handles.accept_track_thresh_pushbutton,'value',0);

% disable display control
set(gui_handles.display_menu.Children,'Enable','off');
set(gui_handles.display_menu.Children,'Checked','off');
gui_handles.display_raw_menu.Checked = 'on';
gui_handles.display_menu.UserData = 1;

