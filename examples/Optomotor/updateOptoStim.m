function [trackDat, expmt] = updateOptoStim(trackDat, expmt)

% Calculate radial distance for each fly
r = sqrt((trackDat.centroid(:,1)-expmt.meta.roi.centers(:,1)).^2 +...
    (trackDat.centroid(:,2)-expmt.meta.roi.centers(:,2)).^2);

% Update which stimuli (if any) need to be turned on
stim = expmt.meta.stim;
trackDat.local_spd(mod(trackDat.ct-1,15)+1,:) = trackDat.speed;
moving = nanmean(trackDat.local_spd)' > 3;
trackDat.moving = moving;
in_center = r < (expmt.meta.roi.bounds(:,4)./4);
timeup = trackDat.t - stim.timer > expmt.parameters.stim_int;
stim_on = trackDat.StimStatus;

% query stim mode and calculate time to switching block in
% parameter sweep mode is enabled
if strcmp(expmt.parameters.stim_mode,'sweep')
    
    switching_block = ...
        ((expmt.sweep.t + expmt.sweep.interval*60) - trackDat.t) < ...
        expmt.parameters.stim_int;
    [trackDat,expmt] = updateStimBlocks(trackDat, expmt);
else
    switching_block = false;
end

%   Activate the stimulus when flies are: moving, away from the
%   edges, have exceeded the mandatory wait time between subsequent
%       presentations, and are not already being presented with a stimulus

if switching_block
    activate_stim = false(size(moving));
else
    activate_stim = moving & in_center & timeup & ~stim_on;
end

% Randomize the rotational direction & Set stim status to ON
trackDat.Texture(activate_stim) = rand(sum(activate_stim),1)>0.5;
stim_on(activate_stim) = true;
stim.t(activate_stim)=trackDat.t;

% Turn off stimuli that have exceed the display duration
stim_OFF = ...
    trackDat.t-stim.t >= expmt.parameters.stim_duration &...
    stim_on;
stim_on(stim_OFF) = false;        % Set stim status to OFF

% Update stim timer for stimulus turned off
if any(stim_OFF)
    % Reset the stimulus timer
    stim.timer(stim_OFF)=trackDat.t;
end

if any(stim_on | stim_OFF)
    
    stim.ct = stim.ct+1;
    
    % Advance the stimulus angle
    stim.angle=stim.angle+(expmt.parameters.ang_per_frame.*trackDat.ifi);
    if stim.angle >= 360
        stim.angle=stim.angle-360;
    end
    
    % Rotate stim image and generate stim texture
    p_rotim = ...
        imrotate(stim.im, stim.angle, 'bilinear', 'crop');
    p_rotim = ...
        p_rotim(stim.bounds(2):stim.bounds(4),...
        stim.bounds(1):stim.bounds(3));
    n_rotim = ...
        imrotate(stim.im, -stim.angle, 'bilinear', 'crop');
    n_rotim = ...
        n_rotim(stim.bounds(2):stim.bounds(4),...
        stim.bounds(1):stim.bounds(3));
    
    % Calculate the displacement from the ROI center in projector space
    p_cen = NaN(sum(stim_on),2);
    dbl_cen = double(trackDat.centroid);
    p_cen(:,1) = ...
        expmt.hardware.projector.Fx(...
        dbl_cen(stim_on,1),...
        dbl_cen(stim_on,2));
    p_cen(:,2) = ...
        expmt.hardware.projector.Fy(...
        dbl_cen(stim_on,1),...
        dbl_cen(stim_on,2));
    p_dist = ...
        [p_cen(:,1) - stim.centers(stim_on,1),...
        p_cen(:,2) - stim.centers(stim_on,2)];
    p_dist = p_dist .* stim.scale(stim_on,:);
    src_rects = NaN(size(stim.corners(stim_on,:)));
    src_rects(:,[1 3]) = [stim.cen_src(1)-p_dist(:,1),...
        stim.cen_src(3)-p_dist(:,1)];
    src_rects(:,[2 4]) = [stim.cen_src(2)-p_dist(:,2),...
        stim.cen_src(4)-p_dist(:,2)];
    
    Screen('Close', stim.pinTex_pos);
    Screen('Close', stim.pinTex_neg);
    stim.pinTex_pos = ...
        Screen('MakeTexture',expmt.hardware.screen.window, p_rotim);
    stim.pinTex_neg = ...
        Screen('MakeTexture',expmt.hardware.screen.window, n_rotim);
    
    % disp(trackDat.Texture(stim_on));
    % Pass textures to screen
    if any(trackDat.Texture(stim_on))
        
        %if
%         disp('saving texture')
%         name=strcat(string(datetime('now', 'Format','yyyy-MM-dd-HH_mm')), 'texture');
%         src_save=src_rects(trackDat.Texture(stim_on),:)';
%         stim_on_save=stim_on;
%         save(name, 'stim', 'trackDat', 'expmt', 'src_save', 'stim_on_save');
        %end
        
        
        Screen('DrawTextures', expmt.hardware.screen.window, ...
            stim.pinTex_pos,...
            src_rects(trackDat.Texture(stim_on),:)', ...
            stim.corners(...
            stim_on & trackDat.Texture,:)',...
            [],[],[],[],[],[]);
    end
    if any(~trackDat.Texture(stim_on))
        
        Screen('DrawTextures', expmt.hardware.screen.window, ...
            stim.pinTex_neg,...
            src_rects(~trackDat.Texture(stim_on),:)', ...
            stim.corners(stim_on & ...
            ~trackDat.Texture,:)', [],[], [], [],[], []);
    end
    
    % Flip to the screen
    expmt.hardware.screen.vbl = ...
        Screen('Flip', expmt.hardware.screen.window, ...
        expmt.hardware.screen.vbl + ...
        (expmt.hardware.screen.waitframes - 0.5) *...
        expmt.hardware.screen.ifi);
end

% re-assign stim to ExperimentData
expmt.meta.stim = stim;
trackDat.StimStatus = stim_on;