function analyzePupils(trackFileName, numStim, frameLim, degPerPx)
% Once trackPupils is done, this script is used to analyze the pupil
% positions and plot a bunch of stuff.

tic;

trialColor = [0.9 0.9 0.9];
%leftColor = [1 1 0.79];  % off-yellow
%rightColor = [0.81 1 0.81];  % off-green

colorLeftNear = [1 0.87 0.71]; % dull orange
colorLeftFar = [1 1 0.79];  % dull yellow
colorRightNear = [0.84 0.89 0.99];  % dull blue
colorRightFar = [0.84 0.98 0.99]; % dull cyan
colorCenter = [1 0.9 0.99];  % dull purple

if (numStim == 4)
    allColors = [colorLeftNear; colorLeftFar; colorRightNear; colorRightFar];
elseif (numStim == 3)
    allColors = [colorLeftNear; colorRightNear; colorCenter];
end

frameStart = frameLim(1);
frameStop = frameLim(2);

% Be sure to change these if the x location of the trees changes
stimLeftNear = 19977;
stimLeftFar = 19978;
stimRightNear = 20023;
stimRightFar = 20022;
stimLeft = 19980;
stimRight = 20020;
stimCenter = 20000;

trialStartOffset = 1;  % Add this much to the recorded trial frame starts - for backwards compatibility
trialEndOffset = 0;

load(trackFileName, 'centers', 'areas');
if (isempty(strfind(trackFileName, '_part_trk.mat')))
    rootFileName = trackFileName(1:end-8);
else
    rootFileName = trackFileName(1:end-13);
end    

totalFrames = length(centers);

if frameStop == 0 || frameStop > totalFrames
    frameStop = totalFrames;
end

% Process the position changes for plotting later
% First, find the central position of the eye, given all of the data, and
% subtract that away.
elavCenter = nanmean(centers(:, 2, :));
elavDeg = -((centers(:,2,:) - elavCenter) .* degPerPx);
elavDeg = reshape(elavDeg, size(elavDeg, 1), size(elavDeg, 3));
azimCenter = nanmean(centers(:, 1, :));
azimDeg = -((centers(:,1,:) - azimCenter) .* degPerPx);
azimDeg = reshape(azimDeg, size(azimDeg, 1), size(azimDeg, 3));

% Read the actions file so the graph can be properly annotated
stimLocs = [];
actionLocs = [];
actionsFile = fopen([rootFileName '_actions.txt']);
if (actionsFile ~= -1) % File found
    fgetl(actionsFile);  % First line is a header so ignore
    expr = '.*?\t.*?\t.*?\t.*?\t(.*?)\t.*?\t.*?\t(.*?)\t'; % The last frame of each trial is in the 3rd column in the actions file
    while(true)
        line = fgetl(actionsFile);
        if (line ~= -1) % The file is not finished
            tokens = regexp(line, expr, 'tokens');
            stimLocs = [stimLocs str2num(tokens{1}{1})];
            actionLocs = [actionLocs str2num(tokens{1}{2})];
        else
            break;
        end
    end
end

ymin = -25;
ymax = 25;

% If trial times are available, incorporate into the graphs
load([rootFileName '.mat'], 'trialStarts', 'trialEnds');
if (trialStarts(1).FrameNumber ~= 0)  % new format includes 1, but old format didn't, so permit backwards compatibility
    trialStartFrames = [1-trialStartOffset trialStarts.FrameNumber] + trialStartOffset; % First trial start is not written
else
    trialStartFrames = [1 trialStarts(2:end).FrameNumber]; % First trial start is not written
end

if (exist('trialEnds', 'var'))
    if (length(trialStarts) == length(trialEnds))
        trialEndFrames = [trialEnds.FrameNumber] + trialEndOffset; % Last trial end was written
    else
        trialEndFrames = [trialEnds.FrameNumber totalFrames-trialEndOffset] + trialEndOffset; % Last trial end was not written, because game was interrupted
    end
else
    trialEndFrames = [trialStartFrames(2:end) totalFrames];
end

numCompletedTrials = length(stimLocs);

% If game ended mid-trial, don't color the final trial
if (length(trialStartFrames) > numCompletedTrials)
    trialStartFrames = trialStartFrames(1:end-1);
    trialEndFrames = trialEndFrames(1:end-1);
end

% Make trial intervals into matrices that can be plotted as patches
trimmedStarts = trialStartFrames(trialStartFrames >= frameStart);
numTruncatedStart = length(trialStartFrames) - length(trimmedStarts); % tells me how much was deleted up front
trimmedStarts = trimmedStarts(trimmedStarts <= frameStop);
numTruncatedEnd = length(trialStartFrames) - length(trimmedStarts) - numTruncatedStart;
if (trimmedStarts(1) > frameStart)
    trimmedStarts = [frameStart trimmedStarts];
    numTruncatedStart = numTruncatedStart - 1;
end
trimmedEnds = trialEndFrames(trialEndFrames <= frameStop);
trimmedEnds = trimmedEnds(trimmedEnds >= frameStart);
if (trimmedEnds(end) < frameStop && frameStop ~= totalFrames)
    trimmedEnds = [trimmedEnds frameStop];
end
xTrials = cat(1, trimmedStarts, trimmedEnds);
xTrials = cat(1, xTrials, flipud(xTrials));

yStim = [ymax; ymax; 0; 0];
yStim = repmat(yStim, 1, size(xTrials,2));
yAction = [0; 0; ymin; ymin];
yAction = repmat(yAction, 1, size(xTrials,2));

xPause = cat(1, trimmedEnds(1:end-1), trimmedStarts(2:end));
xPause = cat(1, xPause, flipud(xPause));
yPause = [ymax; ymax; ymin; ymin];
yPause = repmat(yPause, 1, size(xPause,2));

stimColors = zeros(1, numCompletedTrials, 3);  % Stim location colors to to use when plotting
actionColors = zeros(1, numCompletedTrials, 3);

if (numStim == 4)
    for i=1:numCompletedTrials
        if (stimLocs(i) == stimLeftNear)
            stimColors(1,i,:) = colorLeftNear;
            idx = 1;
        elseif (stimLocs(i) == stimLeftFar)
            stimColors(1,i,:) = colorLeftFar;
            idx = 2;
        elseif (stimLocs(i) == stimRightNear)
            stimColors(1,i,:) = colorRightNear;
            idx = 3;
        elseif (stimLocs(i) == stimRightFar)
            stimColors(1,i,:) = colorRightFar;            
            idx = 4;
        end
        
        if (actionLocs(i) == stimLeftNear)
            actionColors(1,i,:) = colorLeftNear;
            idx = 1;
        elseif (actionLocs(i) == stimLeftFar)
            actionColors(1,i,:) = colorLeftFar;
            idx = 2;
        elseif (actionLocs(i) == stimRightNear)
            actionColors(1,i,:) = colorRightNear;
            idx = 3;
        elseif (actionLocs(i) == stimRightFar)
            actionColors(1,i,:) = colorRightFar;            
            idx = 4;
        end
    end
elseif (numStim == 3)
    for i=1:numCompletedTrials
        if (stimLocs(i) == stimLeft)
            stimColors(1,i,:) = colorLeftNear;
            idx = 1;
        elseif (stimLocs(i) == stimRight)
            stimColors(1,i,:) = colorRightNear;
            idx = 2;
        elseif (stimLocs(i) == stimCenter)
            stimColors(1,i,:) = colorCenter;
            idx = 3;
        end
        
        if (actionLocs(i) == stimLeft)
            actionColors(1,i,:) = colorLeftNear;
            idx = 1;
        elseif (actionLocs(i) == stimRight)
            actionColors(1,i,:) = colorRightNear;
            idx = 2;
        elseif (actionLocs(i) == stimCenter)
            actionColors(1,i,:) = colorCenter;
            idx = 3;
        end
    end
end

stimColors = stimColors(1, 1+numTruncatedStart:end-numTruncatedEnd, :);
actionColors = actionColors(1, 1+numTruncatedStart:end-numTruncatedEnd, :);

% Collect data for averaging...
trimmedStimLocs = stimLocs(1+numTruncatedStart:end-numTruncatedEnd);
trimmedActionLocs = actionLocs(1+numTruncatedStart:end-numTruncatedEnd);
stimEyeMoveTrials = cell(numStim, 2);
actionEyeMoveTrials = cell(numStim, 2);
stimActionEyeMoveTrials = cell(numStim, numStim, 2);  % first axis is stimLoc, second is actionLoc, third is left/right eye
for i=1:length(trimmedStimLocs)
    if (numStim == 4)
        if (trimmedStimLocs(i) == stimLeftNear)
            idx1 = 1;
        elseif (trimmedStimLocs(i) == stimLeftFar)
            idx1 = 2;
        elseif (trimmedStimLocs(i) == stimRightNear)
            idx1 = 3;
        elseif (trimmedStimLocs(i) == stimRightFar)
            idx1 = 4;
        end
    elseif (numStim == 3)
        if (trimmedStimLocs(i) == stimLeft)
            idx1 = 1;
        elseif (trimmedStimLocs(i) == stimRight)
            idx1 = 2;
        elseif (trimmedStimLocs(i) == stimCenter)
            idx1 = 3;
        end        
    end
    for j=1:2
        s = stimEyeMoveTrials{idx1, j};
        s{end+1} = azimDeg(trimmedStarts(i):trimmedEnds(i)-1, j);
        stimEyeMoveTrials{idx1, j} = s;
    end

    if (numStim == 4)
        if (trimmedActionLocs(i) == stimLeftNear)
            idx2 = 1;
        elseif (trimmedActionLocs(i) == stimLeftFar)
            idx2 = 2;
        elseif (trimmedActionLocs(i) == stimRightNear)
            idx2 = 3;
        elseif (trimmedActionLocs(i) == stimRightFar)
            idx2 = 4;
        end
    elseif (numStim == 3)
        if (trimmedActionLocs(i) == stimLeft)
            idx2 = 1;
        elseif (trimmedActionLocs(i) == stimRight)
            idx2 = 2;
        elseif (trimmedActionLocs(i) == stimCenter)
            idx2 = 3;
        end
    end
    for j=1:2
        a = actionEyeMoveTrials{idx2, j};
        a{end+1} = azimDeg(trimmedStarts(i):trimmedEnds(i)-1, j);
        actionEyeMoveTrials{idx2, j} = a;
    end
    
    for j=1:2
        sa = stimActionEyeMoveTrials{idx1, idx2, j};
        sa{end+1} = azimDeg(trimmedStarts(i):trimmedEnds(i)-1, j);
        stimActionEyeMoveTrials{idx1, idx2, j} = sa;
    end
end

% Now, normalize by resampling, and then plot the average of the resampled eye movements.
maxLengths = zeros(size(stimEyeMoveTrials,1), 1);
minLengths = zeros(size(stimEyeMoveTrials,1), 1);
resampledStimEye = cell(size(stimEyeMoveTrials));
m = cell(size(stimEyeMoveTrials));
sem = cell(size(stimEyeMoveTrials));
% First, plot the stimulus average of the eye movements
for i=1:numStim
    stimEyeLengths = cellfun(@(x) length(x), stimEyeMoveTrials{i,1});
    maxLengths(i) = max(stimEyeLengths);
    minLengths(i) = min(stimEyeLengths);  % Use min instead of max, as max adds some artifacts at the end, and both give the same shape
    resampledStimEye{i,1} = cellfun(@(x) resample(x, minLengths(i), length(x)), stimEyeMoveTrials{i,1}, 'UniformOutput', false);
    d = cell2mat(resampledStimEye{i,1}(:)');
    m{i,1} = nanmean(d, 2);
    sem{i,1} = nanstd(d, [], 2) ./ sqrt(size(d, 1));
    resampledStimEye{i,2} = cellfun(@(x) resample(x, minLengths(i), length(x)), stimEyeMoveTrials{i,2}, 'UniformOutput', false);
    d = cell2mat(resampledStimEye{i,2}(:)');
    m{i,2} = nanmean(d, 2);
    sem{i,2} = nanstd(d, [], 2) ./ sqrt(size(d, 1));
    % Placeholder until I make this look pretty
    figure; 
    x = 1:length(m{i,1});
    h = plot(x, m{i,1}, 'r', x, m{i,2}, 'b'); 
    if (numStim == 3)
        if (i == 1)
            sLoc = 'Left';
        elseif (i == 2)
            sLoc = 'Right';
        else
            sLoc = 'Center';
        end
    else
        if (i == 1)
            sLoc = 'Left near';
        elseif (i == 2)
            sLoc = 'Left far';
        elseif (i == 3)
            sLoc = 'Right near';
        else
            sLoc = 'Right far';
        end
    end
    title([rootFileName ': ' sLoc ' stim: mean'], 'Interpreter', 'none');
    annotation('textbox', [.8 0 .2 .2], 'String', ['n=' num2str(length(stimEyeMoveTrials{i,1}))], 'FitBoxToText', 'on', 'EdgeColor', 'white');  
    legend(h, 'left eye', 'right eye');
    ylim([-10 10]);
end

% Second, plot the stimulus x navigation average of the eye movements
% This helps assess whether the eyes follow the stim, or the eyes follow
% the navigation!
maxLengths = zeros(size(stimActionEyeMoveTrials,1), size(stimActionEyeMoveTrials,2), 1);
minLengths = zeros(size(stimActionEyeMoveTrials,1), size(stimActionEyeMoveTrials,2), 1);
resampledStimActionEye = cell(size(stimActionEyeMoveTrials));
m = cell(size(stimActionEyeMoveTrials));
sem = cell(size(stimActionEyeMoveTrials));
for i=1:numStim
    for j=1:numStim
        if (~isempty(stimActionEyeMoveTrials{i,j,1}))
            stimActionEyeLengths = cellfun(@(x) length(x), stimActionEyeMoveTrials{i,j,1});
            maxLengths(i,j) = max(stimActionEyeLengths);
            minLengths(i,j) = min(stimEyeLengths);  % Use min instead of max, as max adds some artifacts at the end, and both give the same shape
            resampledStimActionEye{i,j,1} = cellfun(@(x) resample(x, minLengths(i,j), length(x)), stimActionEyeMoveTrials{i,j,1}, 'UniformOutput', false);
            d = cell2mat(resampledStimActionEye{i,j,1}(:)');
            m{i,j,1} = nanmean(d, 2);
            sem{i,j,1} = nanstd(d, [], 2) ./ sqrt(size(d, 1));
            resampledStimActionEye{i,j,2} = cellfun(@(x) resample(x, minLengths(i,j), length(x)), stimActionEyeMoveTrials{i,j,2}, 'UniformOutput', false);
            d = cell2mat(resampledStimActionEye{i,j,2}(:)');
            m{i,j,2} = nanmean(d, 2);
            sem{i,j,2} = nanstd(d, [], 2) ./ sqrt(size(d, 1));
            % Placeholder until I make this look pretty
            figure; 
            x = 1:length(m{i,j,1});
            h = plot(x, m{i,j,1}, 'r', x, m{i,j,2}, 'b'); 
            if (numStim == 3)
                if (i == 1)
                    sLoc = 'Left';
                elseif (i == 2)
                    sLoc = 'Right';
                else
                    sLoc = 'Center';
                end
                if (j == 1)
                    aLoc = 'Left';
                elseif (j == 2)
                    aLoc = 'Right';
                else
                    aLoc = 'Center';
                end
            else
                if (i == 1)
                    sLoc = 'Left near';
                elseif (i == 2)
                    sLoc = 'Left far';
                elseif (i == 3)
                    sLoc = 'Right near';
                else
                    sLoc = 'Right far';
                end
                if (j == 1)
                    aLoc = 'Left near';
                elseif (j == 2)
                    aLoc = 'Left far';
                elseif (j == 3)
                    aLoc = 'Right near';    
                else
                    aLoc = 'Right far';
                end
            end
            title([rootFileName ': ' sLoc ' stim / ' aLoc ' action'], 'Interpreter', 'none');
            annotation('textbox', [.8 0 .2 .2], 'String', ['n=' num2str(length(stimActionEyeMoveTrials{i,j,1}))], 'FitBoxToText', 'on', 'EdgeColor', 'white');  
            legend(h, 'left eye', 'right eye');
            ylim([-10 10]);
        end
    end
end


save([trackFileName(1:end-4) '_an.mat'], 'centers', 'areas', 'elavDeg', 'azimDeg', 'trialStartFrames', 'trialEndFrames', 'stimLocs', 'actionLocs');


% Plot stimulation and actions first
% Then plot inter-trial intervals
% Finally plot actual eye movement data
% ELEVATION PLOT
figure; hold on
patch(xTrials, yStim, stimColors, 'EdgeColor', 'none');
patch(xTrials, yAction, actionColors, 'EdgeColor', 'none');
if (~isempty(trialStartFrames))
    patch(xPause, yPause, trialColor, 'EdgeColor', trialColor);
end
h = plot(frameStart:frameStop, elavDeg(:, 1), 'r', frameStart:frameStop, elavDeg(:, 2), 'b');
title([rootFileName ': Pupil Elevation'], 'Interpreter', 'none');
ylabel('elevation rel. to first frame (deg, + right, - left)');
xlabel('frame #');
for i = 1:length(allColors)
    p(i) = patch(NaN, NaN, allColors(i,:));
end
if (numStim == 4)
    legend([h;p'], 'left eye', 'right eye', 'left near stim/act', 'left far stim/act', 'right near stim/act', 'right far stim/act');
elseif (numStim == 3)
    legend([h;p'], 'left eye', 'right eye', 'left stim/act', 'right stim/act', 'center stim/act');    
end
ylim([ymin ymax]);
dcmObj = datacursormode(gcf);
set(dcmObj,'UpdateFcn',@dataCursorCallback,'Enable','on');

% AZIMUTH PLOT
figure; hold on
p1 = patch(xTrials, yStim, stimColors, 'EdgeColor', 'none');
p2 = patch(xTrials, yAction, actionColors, 'EdgeColor', 'none');
if (~isempty(trialStartFrames))
    patch(xPause, yPause, trialColor, 'EdgeColor', trialColor);
end
h = plot(frameStart:frameStop, azimDeg(:, 1), 'r', frameStart:frameStop, azimDeg(:, 2), 'b');
title([rootFileName ': Pupil Azimuth'], 'Interpreter', 'none');
ylabel('azimuth rel. to first frame (deg, + right, - left)');
xlabel('frame #');
for i = 1:length(allColors)
    p(i) = patch(NaN, NaN, allColors(i,:));
end
if (numStim == 4)
    legend([h;p'], 'left eye', 'right eye', 'left near stim/act', 'left far stim/act', 'right near stim/act', 'right far stim/act');
elseif (numStim == 3)
    legend([h;p'], 'left eye', 'right eye', 'left stim/act', 'right stim/act', 'center stim/act');    
end
ylim([ymin ymax]);
dcmObj = datacursormode(gcf);
set(dcmObj,'UpdateFcn',@dataCursorCallback,'Enable','on');

% Group the eye movement trials by stimulus type, and plot the averages +- SEM
% Normalize the time interval.
% Do only azimuth for now; add elevation later
for i=1:numCompletedTrials
    
end

% Group the eye movement trials by action type, and plot the averages +- SEM


end