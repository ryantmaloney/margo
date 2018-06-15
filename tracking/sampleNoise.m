function [expmt] = sampleNoise(gui_handles, expmt)
% 
% Samples the background noise distribution prior to imaging for the
% purpose of determining when to force reset background reference images.
% For the sampling to accurate, it is important for the tracking during the
% sampling period to be clean (ie. majority of the tracked objects appear
% above the imaging threshold with few above-threshold pixels due to
% noise).

gui_notify('sampling imaging noise',gui_handles.disp_note);

gui_fig = gui_handles.gui_fig;
imh = findobj(gui_handles.axes_handle,'-depth',3,'Type','image');   % image handle

colormap('gray');
set(gui_handles.display_menu.Children,'Enable','on');
set(gui_handles.display_menu.Children,'Checked','off');
set(gui_handles.display_threshold_menu,'Checked','on');
gui_handles.display_menu.UserData = 3;


%% Sampling Parameters

pixDistSize=100;                            % Num values to record in p
pixelDist=NaN(pixDistSize,1);               % Distribution of total number of pixels above image threshold
roiDist=NaN(pixDistSize,expmt.ROI.n);       % Distribution of total number of pixels above image threshold

% tracking vars
trackDat.Centroid = expmt.ROI.centers;     % placeholder for most recent non-NaN centroids
trackDat.fields = {'Centroid';'Area'};     % Define fields for regionprops
trackDat.tStamp = zeros(size(expmt.ROI.centers(:,1),1),1);
trackDat.t = 0;
trackDat.ct = 0;
trackDat.ref = expmt.ref;

%% Initalize camera and axes

expmt = getVideoInput(expmt,gui_handles);

%% Sample noise

% initialize display objects
clean_gui(gui_handles.axes_handle);
imh = findobj(gui_handles.axes_handle,'-depth',3,'Type','Image');
set(gca,'Xtick',[],'Ytick',[]);
clearvars hCirc
hold on
hCirc = plot(expmt.ROI.centers(:,1),expmt.ROI.centers(:,2),'o','Color',[1 0 0]);
hold off

tic
trackDat.tPrev = toc;
old_rate = gui_handles.gui_fig.UserData.target_rate;
gui_handles.gui_fig.UserData.target_rate = 100;

while trackDat.ct < pixDistSize;

    % update time stamps and frame rate
    trackDat = autoTime(trackDat, expmt, gui_handles,1);
    gui_handles.edit_time_remaining.String = num2str(pixDistSize - trackDat.ct);

    % query next frame and optionally correct lens distortion
    [trackDat,expmt] = autoFrame(trackDat,expmt,gui_handles);

    % track objects and sort to ROIs
    [trackDat] = autoTrack(trackDat,expmt,gui_handles);

    %Update display if display tracking is ON
    if gui_handles.display_menu.UserData ~= 5

        % Draw last known centroid for each ROI and update ref. number indicator
        hCirc.XData = trackDat.Centroid(:,1);
        hCirc.YData = trackDat.Centroid(:,2);
       
        % update the display
        autoDisplay(trackDat, expmt, imh, gui_handles);

    end


   % Create distribution for num pixels above imageThresh
   % Image statistics used later during acquisition to detect noise
   diffim = (trackDat.ref.im - expmt.vignette.im) - ...
       (trackDat.im - expmt.vignette.im);
   thresh_im = diffim(:) > gui_handles.track_thresh_slider.Value;
   pixelDist(mod(trackDat.ct-1,pixDistSize)+1) = nansum(thresh_im);
   roiDist(mod(trackDat.ct-1,pixDistSize)+1,:) = ...
       cellfun(@(x) sum(thresh_im(x)),expmt.ROI.pixIdx);
   
end

switch expmt.source
    case 'video'
        gui_handles.edit_time_remaining.String = num2str(expmt.video.nFrames);
    case 'camera'
        updateTimeString(round(gui_handles.edit_exp_duration.Value * 3600),...
                        gui_handles.edit_time_remaining);
end
drawnow limitrate
gui_handles.gui_fig.UserData.target_rate = old_rate;
gui_notify('noise sampling complete',gui_handles.disp_note);

% Assign outputs
expmt.noise.dist = pixelDist;
expmt.noise.std = nanstd(pixelDist);
expmt.noise.mean = nanmean(pixelDist);
expmt.noise.roi_dist = roiDist;
expmt.noise.roi_std = nanstd(roiDist(roiDist>4));
expmt.noise.roi_mean = nanmean(roiDist(roiDist>4));

