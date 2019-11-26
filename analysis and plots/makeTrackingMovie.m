% Creates a movie with tracking overlay from an expmt master struct and raw
% movie file of the tracking. Set overlay parameters. Set parameters for
% the tracking over. Browse to the expmt .mat file, accompanying movie
% file, and select a save path for output video.

% Parameters
frame_rate = 15;            % output frame rate
frame_increment = 1;        % sampling rate of the frames (no sub-sampling = 1)
mode = 'centroid';          % valid modes: ('centroid'|'orientation')
trail_length = 3;          % length of centroid comet trail (number of frames)
options = struct();

% configure plotting options - (optional)
options.centroid = {'Marker'; 'o'; 'LineStyle'; 'none';...
    'MarkerFaceColor'; 'g'; 'MarkerEdgeColor'; 'none';...
    'MarkerSize'; 4; 'LineWidth'; 2.5};
options.trail = {'LineStyle'; '-'; 'Color'; 'b'; 'LineWidth'; 2};


%% get file paths

[ePath,eDir] = uigetfile('*.mat','Select a expmt .mat file containing centroid traces');
load([eDir,ePath]);
[movPath,movDir] = uigetfile({'*.avi;*.mp4;*.mov'},'Select accompanying raw movie file',eDir);
savePath = [movDir expmt.meta.path.name '_track_overlay'];
[SaveName,SaveDir] = uiputfile({'*.avi';'*.mov';'*.mp4'},'Select path and file name for output movie',savePath);


%%

% intialize video objects
rVid = VideoReader([movDir,movPath]);
wVid = VideoWriter([SaveDir,SaveName],'Motion JPEG AVI');
wVid.FrameRate = frame_rate;
wVid.Quality = 100;
if expmt.meta.num_frames ~= rVid.NumberOfFrames
    error('frame number mismatch between tracking and video files');
end

% find first frame with traces
attach(expmt);
max_n = 10000;
max_n(max_n>expmt.meta.num_frames) = expmt.meta.num_frames;
tmp_c = [expmt.data.centroid.raw(1:max_n,1,:);...
    expmt.data.centroid.raw(1:max_n,2,:)];
[r,~] = find(~isnan(tmp_c));
fr_offset = min(r);

% intialize axes and image
open(wVid);
fr = read(rVid,fr_offset);
if size(fr,3) > 1
    fr = fr(:,:,2);
end
fh = figure('units','pixels','outerposition',[0 0 size(fr,2) size(fr,1)]);
fh.Units = 'pixels';
%fh.MenuBar = 'none';
fh.Name = 'Video Preview';


imh = image(fr);
imh.CDataMapping = 'scaled';
       colormap(cmsat());
ah = gca;
ah.Units = 'normalized';
ah.Position = [0 0 1 1];
fh.Position([3 4]) = [1280 960];
set(ah,'Xtick',[],'YTick',[],'Units','pixels');
fh.Units = 'pixels';
fh.Position(3) = ah.Position(3);
axis equal tight
ah.CLim = [0 255];
fh.Resize = 'off';
hold on

% initialize centroid markers
attach(expmt);
switch mode
    case 'orientation'
        handles = draw_orientation_ellipse(expmt, fr_offset, [], options);
    case 'centroid'
        handles = draw_centroid_trail(expmt, fr_offset, trail_length, [], options);
end

im_out = getframe(ah);

%%
ct = fr_offset;
fprintf('first centroids detected in frame %i\n', ct)

while ct < expmt.meta.num_frames

    if mod(ct,1000)==0
        fprintf('processing frame\t %i\t of\t %i\n',ct,expmt.meta.num_frames)
    end

    fr = read(rVid,ct);
    if size(fr,3)>1
        fr = fr(:,:,2);
    end
    imh.CData = fr;

    % draw orientation data
    switch mode
        case 'centroid'
            handles = draw_centroid_trail(expmt, ct, trail_length, handles, options);
        case 'orientation'
            handles = draw_orientation_ellipse(expmt, ct, handles, options);
    end

    drawnow
    im_out = getframe(ah);
    writeVideo(wVid,im_out.cdata);
    ct = ct+frame_increment;
end

close(wVid);
