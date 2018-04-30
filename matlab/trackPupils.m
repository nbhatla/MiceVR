function trackPupils(vLeftFileName, vRightFileName, frameLim, fps, otsuWeight, pupilSzRangePx, seSize, paratio, useGPU)
% This script will find the pupil in each of 2 videos, one containing each eye.
% It will then save these pupil locations in a file, as well as generate a
% composite video with both eyes side-by-side, and the pupils tracked with
% a red X.
%
% A helper script called analyzePupils.m will take the output of this
% script and analyze it, producing graphs and other analysis.

% > trackPupils('Candy_206_2.mp4', 'Candy_206_1.mp4', [1 1000], 60, 0.34, [50 2000], 4, 0)

% Good settings for arguments:
% NEW - single illuminator above
% otsuweight = 0.34      BAD = [0.5 0.47 0.44] Cryo_117
%                        BAD = [0.4 0.35] Berlin_001
%                        BAD = [0.3], GOOD [0.35] Alpha_133
%                        BAD = 0.34, 0.4 Quasar 78, GOOD 0.38
% maxPupilAspectRatio = 1.5   Used to detect eye blinks and to ignore
% candidate pupil

% OLD
% With imopen: 0.5 otsuweight is good with minSize = 200, [0.497vid-0.3] are
% bad, with Cryo - but 0.5 is bad with Candy, but 0.492 is fine
% minPupilSize = 140 also bad with 0.5 otsuweight.
% Cryo - minSize = 50 is good, 70 or higher is bad
%        maxSize = 1500 is good?  1200 too small for Candy's dilation. 
%      otsuWeight = .5 is good, .55 is bad, .45 is bad
% OLD: [0.38 0.4] is good, 0.45 is bad! 0.35 bad unless imopen is used
% minPupilSzPx = 140 
% seSize = 10 hides whiskers/eye lashes, 5 does not!

tic

maxPupilAspectRatio = paratio;  % 1.437; 1.45 lets some through, so go smaller, but not less than 1.4; motion blur causes 1.4326
                            % Quasar had one eye > 2.2!  2.45 bad for Umpa.
                            % Changed to 2.6 on 4/27/18 when analyzing
                            % videos from rig3 from 4/25/18

% Wash to extend blanks out by 1 on either side?

sizeWt = 0.25; % Cryo 112 - 0.2 has some occasional failures
distWt = 10;
solWt = 1;
distFudge = 0.001;

pupilPosHistLen = 40;  % Keep track of the pupil over N frames

frameStart = frameLim(1);
frameStop = frameLim(2);

skip = zeros(1,2);
if (~isempty(vLeftFileName))
    v(1) = VideoReader(vLeftFileName); % v(1) is the video of the left eye
    [folder name ext] = fileparts(vLeftFileName);
else
    skip(1) = true;
end
if (~isempty(vRightFileName))
    % Hack but works
    if (~exist('v'))
        v(1) = VideoReader(vRightFileName);
    end
    v(2) = VideoReader(vRightFileName); % v(2) is the video of the right eye
    [folder name ext] = fileparts(vRightFileName);
else
    skip(2) = true;
end
if (skip(1) && skip(2))
    error('Need to specify at least 1 of 2 video filenames.');
end

if (isempty(folder))
    folder = '.';
end
outRoot = [folder '\' name(1:end-2)];

% Set a default video if only 1 video was recorded
if (skip(1))
    defVid = 2;
else
    defVid = 1;
end

relFrame = 1;

totalFrames = v(defVid).NumberOfFrames;

% Check a bunch of things to make sure both videos match, else exit with error
if (~skip(1) && ~skip(2))
    if (totalFrames ~= v(2).NumberOfFrames)
        error('The number of frames in each video does not match. Were frames dropped or is the video corrupt?');
    end
    if (v(1).Height ~= v(2).Height)
        error('The height of each video does not match. It must.');
    end
    if (v(1).Width ~= v(2).Width)
        error('The width of each video does not match. It must.');
    end
end

if frameStop == 0 || frameStop > totalFrames
    frameStop = totalFrames;
end

numFrames = frameStop - frameStart + 1;
% Reopen because Matlab is lame and has issues reading a video after
% NumberOfFrames has been accessed.
if (~skip(1))
    v(1) = VideoReader(vLeftFileName); % v(1) is the video of the left eye
    v(1).CurrentTime = frameStart * 1/fps - 1/fps;
end
if (~skip(2))
    v(2) = VideoReader(vRightFileName); % v(2) is the video of the right eye
    v(2).CurrentTime = frameStart * 1/fps - 1/fps;
end

% Init storage variables
centers = zeros(numFrames, 2, 2); % Z dimension is 1 for each eye, left eye first
areas = zeros(numFrames, 1, 2);  % Z dimension is 1 for each eye, left eye first

if (seSize > 0)
    if (totalFrames == numFrames)
        vout = VideoWriter([outRoot '_opened_ann.mp4'], 'MPEG-4');
    else
        vout = VideoWriter([outRoot '_part_opened_ann.mp4'], 'MPEG-4');        
    end
else
    if (totalFrames == numFrames)
        vout = VideoWriter([outRoot '_ann.mp4'], 'MPEG-4');    
    else
        vout = VideoWriter([outRoot '_part_ann.mp4'], 'MPEG-4');        
    end
end
vout.FrameRate = fps;
open(vout);

imLR = zeros(v(defVid).Height, v(defVid).Width, v(defVid).BitsPerPixel/8, 2, 'uint8'); % 2 RGB images per video frame, RGB despite being grayscale because it is MP4 encoding

if (skip(1))
    startVid = 2;
    stopVid = 2;
elseif (skip(2))
    startVid = 1;
    stopVid = 1;
else
    startVid = 1;
    stopVid = 2;
end

while relFrame + frameStart <= frameStop + 1
    %disp(relFrame + frameStart - 1);  %% UNCOMMENT to see status
    for i=startVid:stopVid  % 1 is L, 2 is R
        if (i == 1)
            imLR(:,:,:,i) = readFrame(v(1));
        else
            imLR(:,:,:,i) = readFrame(v(2));
        end
        
        %%%%% CORE ALGORITHM FOR FINDING PUPIL %%%%%%%%%%%%
        % It is important to to binarize before opening to keep parts of
        % the pupil that span an eyelash together.
        subIm = imbinarize(imLR(:,:,:,i), otsuWeight*graythresh(imLR(:,:,:,i)));
        
        % If you want to make this algorithm runnable in realt-time (60Hz), 
        % remove the imopen command by setting seSize arg to 0.
        if (seSize > 0)
            se = strel('disk', seSize);
            if (useGPU)
                subIm = imopen(gpuArray(subIm), se);  % This is slow, and takes about 3 sec per second of video (60 frames)
                subIm = gather(subIm);
            else
                subIm = imopen(subIm, se);  % This is slow, and takes about 3 sec per second of video (60 frames)
            end
        else
            subIm = imLR(:,:,:,i);
        end
            
        % Need to complement, so that pupil is white instead of black;
        % Matlab treats white as foreground and black as background.
        subIm = imcomplement(subIm(:,:,1));
        
        cc = bwconncomp(subIm);
        % For debugging:
        if (relFrame == 74 && i == 2)
            a = 0;
        end
        if (~isempty (cc.PixelIdxList))
            s = regionprops(subIm, {'Centroid', 'MajorAxisLength', 'MinorAxisLength', ...
                'Orientation', 'ConvexArea', 'Solidity'});
            s = s([s.ConvexArea] > pupilSzRangePx(1) & [s.ConvexArea] < pupilSzRangePx(2));
            if (~isempty(s))
                cA = [s.ConvexArea];
                solidity = [s.Solidity];
                curPos = cat(1, s.Centroid);
                if (relFrame > 1)
                    if (relFrame-1 > pupilPosHistLen)
                        startFr = relFrame - pupilPosHistLen;
                    else
                        startFr = 1;
                    end
                    c = centers(startFr:relFrame-1, :, i);
                    c = c(~isnan(c));
                    cNoNaN = reshape(c, numel(c)/2, 2);
                    avgPrevPos = mean(cNoNaN, 1);
                else
                    % Pupil will tend to be in the center of the screen, so initialize to there.
                    avgPrevPos = [v(defVid).Width/2 v(defVid).Height/2];
                end
                prevPos = repmat(avgPrevPos, size(curPos, 1), 1);
                dist = sqrt(power(curPos(:,1) - prevPos(:,1),2) + power(curPos(:,2) - prevPos(:,2),2))';
                %centroids = [s.Centroid];
                %roundy = [s.MajorAxisLength; s.MinorAxisLength]; 
                %roundy = roundy(1,:) - roundy(2,:);
                % Do not rely on roundy because it gives good signal 
                % if noise is splotchy in just the right way.
                [~,idx] = max( ...
                               solWt * solidity/max(solidity) + ...
                               distWt * min(dist) ./ (dist+distFudge) + ...
                               sizeWt * cA/max(cA));
                if (~isempty(idx))
                    % When the mouse blinks, the aspect ratio gets less
                    % circular and more elliptical.  This tests for that.
                    if (s(idx).MajorAxisLength / s(idx).MinorAxisLength < maxPupilAspectRatio)
                        centers(relFrame,:,i) = s(idx).Centroid; % raw pixel position
                        areas(relFrame,:,i) = s(idx).ConvexArea;  % in px - need to calibrate
                        %%% DRAW ONTO VIDEO FOR VALIDATION %%%
                        c = s(idx).Centroid;
                        rMaj = s(idx).MajorAxisLength / 2;
                        rMin = s(idx).MinorAxisLength / 2;
                        angle = -s(idx).Orientation;
                        dxMaj = rMaj * cosd(angle);
                        dyMaj = rMaj * sind(angle);
                        dxMin = rMin * cosd(angle+90);
                        dyMin = rMin * sind(angle+90);
                        lines = [c(1)-dxMaj, c(2)-dyMaj, c(1)+dxMaj, c(2)+dyMaj;
                                 c(1)-dxMin, c(2)-dyMin, c(1)+dxMin, c(2)+dyMin];
                        imLR(:,:,:,i) = insertShape(imLR(:,:,:,i), 'line', lines, ...
                            'LineWidth', 2, 'Color', 'red');
                    else
                        centers(relFrame,:,i) = [NaN NaN];
                        areas(relFrame,:,i) = [NaN];
                    end
                else
                    centers(relFrame,:,i) = [NaN NaN];
                    areas(relFrame,:,i) = [NaN];
                end
            else
                centers(relFrame,:,i) = [NaN NaN];
                areas(relFrame,:,i) = [NaN];
            end
        else
            centers(relFrame,:,i) = [NaN NaN];
            areas(relFrame,:,i) = [NaN];
        end
    end
    
    fusedFrame = cat(2, imLR(:,:,:,2), imLR(:,:,:,1));
    writeVideo(vout, fusedFrame);    

    relFrame = relFrame + 1;
end

if (totalFrames == numFrames)
    save([outRoot '_trk.mat'], 'centers', 'areas');
else  % Partial analysis, so change file name as such
    save([outRoot '_part_trk.mat'], 'centers', 'areas');    
end

close(vout);

t = toc;  % seconds
disp([num2str(round(t/(numFrames/fps), 1)) 'x realtime']);

beep

end