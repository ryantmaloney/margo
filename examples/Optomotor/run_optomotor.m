function expmt = run_optomotor(expmt,gui_handles,varargin)
%% Parse variable inputs

for i = 1:length(varargin)
    
    arg = varargin{i};
    
    if ischar(arg)
        switch arg
            case 'Trackdat'
                i=i+1;
                trackDat = varargin{i};     % manually pass in trackDat rather than initializing
        end
    end
end

%% Initialization: Get handles and set default preferences

gui_notify(['executing ' mfilename '.m'],gui_handles.disp_note);

% clear memory
clearvars -except gui_handles expmt trackDat

% get image handle
imh = findobj(gui_handles.axes_handle,'-depth',3,'Type','image');  


%% Experimental Setup

% Initialize tracking variables
trackDat.fields={'centroid';'orientation';'time';...
    'speed';'StimStatus';'Texture';'SpatialFreq';...
    'AngularVel';'Contrast'};  % properties of the tracked objects to be recorded

% initialize labels, files, and cam/video
[trackDat,expmt] = autoInitialize(trackDat,expmt,gui_handles);

% lastFrame = false until last frame of the last video file is reached
trackDat.lastFrame = false;


%% Initialize the psychtoolbox window and query projector properties
bg_color=[0 0 0];
expmt = initialize_projector(expmt, bg_color);
pause(1);

set(gui_handles.display_menu.Children,'Checked','off')
set(gui_handles.display_menu.Children,'Enable','on')
gui_handles.display_none_menu.Checked = 'on';
gui_handles.display_menu.UserData = 5;

%% Calculate ROI coords in the projector space and expand the edges by a small border to ensure ROI is fully covered

% tmp vars
nROIs = expmt.meta.roi.n;
scor = NaN(size(expmt.meta.roi.corners));
rcor = expmt.meta.roi.corners;
scen = NaN(nROIs,2);
rcen = expmt.meta.roi.centers;

% convert ROI coordinates to projector coordinates for stimulus targeting
Fx = expmt.hardware.projector.Fx;
Fy = expmt.hardware.projector.Fy;
scen(:,1) = Fx(rcen(:,1),rcen(:,2));
scen(:,2) = Fy(rcen(:,1),rcen(:,2));

scor(:,1) = Fx(rcor(:,1), rcor(:,2));   
scor(:,2) = Fy(rcor(:,1), rcor(:,2));
scor(:,3) = Fx(rcor(:,3), rcor(:,4));
scor(:,4) = Fy(rcor(:,3), rcor(:,4));

% add a buffer to stim bounding box to ensure entire ROI is covered
sbbuf = nanmean([scor(:,3)-scor(:,1), scor(:,4)-scor(:,2)],2)*0.05;
scor(:,[1 3]) = [scor(:,1)-sbbuf, scor(:,3)+sbbuf];
scor(:,[2 4]) = [scor(:,2)-sbbuf, scor(:,4)+sbbuf];


%% Pre-allocate stimulus image for texture making

% Determine stimulus size
pin_sz=round(nanmean(nanmean([scor(:,3)-scor(:,1) scor(:,4)-scor(:,2)]))*4);
if pin_sz<0
   disp('Pin_sz was negative, taking absolute value');
   pin_sz=abs(pin_sz);
end

nCycles = expmt.parameters.num_cycles;            % num dark-light cycles in 360 degrees
mask_r = expmt.parameters.mask_r;                 % radius of center circle dark mask (as fraction of stim_size)
ang_vel = expmt.parameters.ang_per_frame;         % angular velocity of stimulus (degrees/frame)
contrast = expmt.parameters.contrast;
subim_r = floor(pin_sz/2*sqrt(2)/2);

% Initialize the stimulus image
stim.im = initialize_pinwheel(pin_sz,pin_sz,nCycles,mask_r,contrast);
imcenter = [size(stim.im,1)/2+0.5 size(stim.im,2)/2+0.5];
stim.bounds = [imcenter(2)-subim_r imcenter(1)-subim_r imcenter(2)+subim_r imcenter(1)+subim_r];
ssz_x = stim.bounds(3)-stim.bounds(1)+1;
ssz_y = stim.bounds(4)-stim.bounds(2)+1;

% Initialize source rect and scaling factors
stim.bs_src = [0 0 ssz_x/2 ssz_y/2];
stim.cen_src = CenterRectOnPointd(stim.bs_src,ssz_x/2,ssz_y/2);
stim.scale = NaN(nROIs,2);
stim.scale(:,1) = (ssz_x/2)./(scor(:,3)-scor(:,1));
stim.scale(:,2) = (ssz_y/2)./(scor(:,4)-scor(:,2));

%% Slow phototaxis specific parameters

trackDat.local_spd = NaN(15,nROIs);
trackDat.prev_ori = NaN(nROIs,1);

% Placeholder for pinwheel textures positively/negatively rotating
stim.pinTex_pos = ...
    Screen('MakeTexture', expmt.hardware.screen.window, stim.im);  
stim.pinTex_neg = ...
    Screen('MakeTexture', expmt.hardware.screen.window, stim.im); 

trackDat.StimStatus = false(nROIs,1);
trackDat.Texture = true(nROIs,1);
trackDat.SpatialFreq = expmt.parameters.num_cycles;
trackDat.AngularVel = expmt.parameters.ang_per_frame;
trackDat.Contrast = expmt.parameters.contrast;

stim.t = zeros(nROIs,1);
stim.timer = zeros(nROIs,1);
stim.ct = 0;                     % Counter for number of looming stim displayed each stimulation period
stim.prev_ori=NaN(nROIs,1);
stim.dir = true(nROIs,1);  % Direction of rotation for the light
stim.angle = 0;
stim.corners = scor;
stim.centers = scen;
stim.sz = pin_sz;

% assign stim settings to ExperimentData
expmt.meta.stim = stim;
expmt.hardware.projector.Fx = Fx;
expmt.hardware.projector.Fy = Fy;

% set stim block timer if stim mode is sweep
switch expmt.parameters.stim_mode
    case 'sweep'
        expmt.meta.sweep.t = 0;
end

name=strcat(string(datetime('now', 'Format','yyyy-MM-dd-HH_mm')), 'stim');
save(name, 'stim', 'pin_sz', 'nCycles', 'mask_r', 'contrast');

%% Main Experimental Loop

% make sure the mouse cursor is at screen edge
robot = java.awt.Robot;
robot.mouseMove(1, 1);

% run experimental loop until duration is exceeded or last frame
% of the last video file is reached
while ~trackDat.lastFrame
    
    % update time stamps and frame rate
    [trackDat] = autoTime(trackDat, expmt, gui_handles);

    % query next frame and optionally correct lens distortion
    [trackDat,expmt] = autoFrame(trackDat,expmt,gui_handles);

    % track, sort to ROIs, and output optional fields to sorted fields,
    % and sample the number of pixels above the image threshold
    trackDat = autoTrack(trackDat,expmt,gui_handles);

    % update the stimuli
    [trackDat, expmt] = updateOptoStim(trackDat, expmt);
    
    % output data to binary files
    [trackDat,expmt] = autoWriteData(trackDat, expmt, gui_handles);

    % update ref at the reference frequency or reset if noise thresh is exceeded
    [trackDat, expmt] = autoReference(trackDat, expmt, gui_handles);  
    
    % update the display
    trackDat = autoDisplay(trackDat, expmt, imh, gui_handles);

end

name=strcat(string(datetime('now', 'Format','yyyy-MM-dd-HH_mm')), 'stim2');
save(name, 'trackDat', 'expmt');

function updateText(h,pos,val)

h.Position = pos{:}+10;
h.String = num2str(val);
