function [actionMap, trialFirstFrame, frac] = makeMapOfDecisionPrediction(mouseName, days, numTargets, poolingSize, threshold)
% This function generates a map of all mouse locations observed (pooled by poolingSize) and associates
% a prediction accuracy with each location on the map.  This should be better than findEarliestTimepointOfDecision
% because (a) some mice pause for inconsistent times at the start of trials, e.g. Ink and Pomey, and Zzz when 
% overlicking) and (b) what really matters is where the mouse is, not the fraction of a trial she has been running
% for (though other variables such as velocity might be informative as well).

% The new analysis code will use this map (a 2D array with the winner-take-all decision, a 2nd 2D array with the
% training accuracy, and a 3rd 2D array with the test accuracy) to make predictions with a certain level of 
% confidence (e.g. 70% cutoff) of where the mouse will go, and use this to censor trials in which the mouse's 
% eyes have moved the relevant target into their good field.

% This map will use half of the data (the odd trials of each target position, which helps with uneven presentations)
% to calculate the training accuracy, and find the threshold of training accuracy that produces a test accuracy 
% greater than a specificed value (e.g. targetTestAccuracy = 70%). It will then be used by subsequent analysis 
% to measure eye movements when the mouse reaches those points in space that have the minimum specified test 
% accuracy.

% trialFirstFrame specifies the first frame in each trial at which a prediction of where the mouse will go
% can be made with an accuracy of threshold.

sessions = [];
fps = 60;

stimLeftNear = 19973;
stimLeftFar = 19972;
stimRightNear = 20027;
stimRightFar = 20028;

stimLeft = 19975;
stimRight = 20025;
stimCenter = 20000;

colors4 = [1 1 1;   % white, for places on the winnerMask which are not used for predictions
          0.84 0.89 0.99;      % dull blue
          1 0.87 0.71;     % dull orange
          0.84 0.98 0.99;     % dull cyan
          0.9 0.9 0.69;   % dull yellow
          ];

colors3 = [ 1 1 1;   % white, for places on the winnerMask which are not used for predictions
            0.84 0.89 0.99;  % dull blue
            1 0.87 0.71;     % dull orange
            0.85 1 0.8];     % dull green

actionsFolder = 'C:\Users\nikhi\UCB\data-actions\';
replaysFolder = 'C:\Users\nikhi\UCB\data-replays\';

successDelay = 2; % sec
failureDelay = 4; % sec

totalTrialsAnalyzed = 0;

replaysFileList = [];
trialsPerDay = zeros(length(days), 1);
for d_i=1:length(days)  % Iterate through all of the specified days, collecting all relevant replays
    dayStr = num2str(days(d_i));
    if (~isempty(sessions))
        newList = dir([replaysFolder mouseName '-D' dayStr '-*-S' num2str(sessions(d_i)) '*']);
        replaysFileList = [replaysFileList; newList]; %
    else
        newList = dir([replaysFolder mouseName '-D' dayStr '*']);
        replaysFileList = [replaysFileList; newList];
    end
    trialsPerDay(d_i) = length(replaysFileList);
end

% If no replays found, print error and move on to next day
if (isempty(replaysFileList))
    error(['Could not find replays at least one of the days specified.']);
end

% Get the replayFileNames and sort them in trial order
s = struct2cell(replaysFileList);
replaysFileNames = natsortfiles(s(1,:));

% Extract the scenario name from the replay filename, which will be used to open the correct actions file
actRecs = [];
for d_i=1:length(days)  % Iterate through all of the specified days, collecting all relevant replays
    dayStr = num2str(days(d_i));
    expr = [mouseName '-D' dayStr '-([^-]+)-S([^-]+)-'];
    idx = 1;
    if (d_i > 1)
        idx = idx + trialsPerDay(d_i-1);
    end
    tokens = regexp(replaysFileList(idx).name, expr, 'tokens');
    scenarioName = tokens{1}{1};
    sessionNum = tokens{1}{2};

    % Open the actions file for this mouse on this day, whose number of lines will match the number of 
    % replay files for that day.  
    % We use the actions file to determine where the mouse decided to go on that trial.
    actionsFileName = [actionsFolder mouseName '-D' dayStr '-' scenarioName '-S' sessionNum '_actions.txt'];
    actionsFileID = fopen(actionsFileName);
    if (actionsFileID ~= -1)  % File was opened properly
        firstLine = fgets(actionsFileID); % Throw out the first line, as it is a column header
        if (isempty(actRecs))
            actRecs = textscan(actionsFileID, getActionLineFormat()); 
        else
            tmpActRecs = textscan(actionsFileID, getActionLineFormat());
            for actCol=1:length(actRecs)
                actRecs{actCol} = [actRecs{actCol}; tmpActRecs{actCol}];
            end
        end
    else
        error(['Actions file ' actionsFileName 'could not be opened, so ending.']);
    end
    fclose(actionsFileID); 
end

numTrials = length(actRecs{1});
mouseLocToActLoc = zeros(numTrials, 3);

% First, read all the replay records and find the min and max values

actionMap = containers.Map();
allXPos = [];
allZPos = [];

fprintf(['Mapping all frames of trial ' num2str(1, '%03d')]);
for currTrial = 1:numTrials
    fprintf(['\b\b\b' num2str(currTrial, '%03d')]);
    
    if (currTrial == 182)
        a = 0;
    end
    % By default include correction trials, as those are useful info.  Consider excluding if don't get good results.
    actLocX = getActionLoc(actRecs, currTrial);
    stimLocX = getStimLoc(actRecs, currTrial);
    
    replaysFileID = fopen([replaysFolder replaysFileNames{currTrial}]);
    if (replaysFileID ~= -1)
        repRecs = textscan(replaysFileID, '%f %f %f %f %f %f %f %f', 'Delimiter', {';', ','}); 
        fclose(replaysFileID); % done with it.
        % Sometimes, if a game is canceled before starting, there might be a blank replay file.  This handles that.
        if (isempty(repRecs{1}))
            disp('skipping empty replay file...');
            continue;
        end

        % Add each position (if new for this trial) to the actionMap
        alreadyAdded = containers.Map();
        for frame = 1:length(repRecs{3}(:))  % xPos might be recorded w/o zPos, so only read lines up to max that have a zPos
            xPos = round(repRecs{1}(frame));  % Need to incorporate poolingSize later
            zPos = round(repRecs{3}(frame));
            key = strcat(num2str(xPos), ',', num2str(zPos));
            if (~alreadyAdded.isKey(key))
                if (actLocX == stimLeftNear || actLocX == stimLeft)
                    idx = 1;
                elseif (actLocX == stimRightNear || actLocX == stimRight)
                    idx = 2;
                elseif (actLocX == stimLeftFar || actLocX == stimCenter)
                    idx = 3;
                else
                    idx = 4;
                end
                if (actionMap.isKey(key))
                    actLocs = actionMap(key);
                else
                    actLocs = zeros(1, numTargets);
                end
                actLocs(idx) = actLocs(idx) + 1;
                actionMap(key) = actLocs;
                alreadyAdded(key) = 1;
            end
        end
    end
end

% With all the positions mapped to actions, find the decision points and display them!
keys = actionMap.keys;
for i=1:length(keys)
    xz = str2num(keys{i});
    allXPos(end+1) = xz(1);
    allZPos(end+1) = xz(2);
end
minX = min(allXPos);
maxX = max(allXPos);
xRange = round((maxX - minX) / poolingSize) + 1;
minZ = min(allZPos);
maxZ = max(allZPos);
zRange = round((maxZ - minZ) / poolingSize) + 1;
binnedLocs = zeros(zRange, xRange, numTargets);

for i=1:length(keys)
    xBin = round((allXPos(i) - minX) / poolingSize) + 1;
    zBin = round((allZPos(i) - minZ) / poolingSize) + 1;
    actionsAtLoc = actionMap(keys{i});
    binnedLocs(zBin,  xBin, :) = actionsAtLoc;
end

locAccuracy = zeros(size(binnedLocs));
for idx=1:numTargets
    locAccuracy(:,:,idx) = binnedLocs(:,:,idx) ./ sum(binnedLocs,3);
end

% Append a NaN array to beginning of locAccuracy, just for the mask calculation
locAccuracyWithNaNSheet = cat(3, nan(zRange, xRange), locAccuracy);

% This array will keep an index of the winner at each location - that is, the highest probability actLoc at 
% that xz location.
[~, winnerMask] = max(locAccuracyWithNaNSheet, [], 3);
winnerMask = winnerMask - 1;

l = locAccuracyWithNaNSheet - threshold;
l = locAccuracyWithNaNSheet .* (l > 0);
l(l==0) = NaN;
[~, greaterThanThresholdMask] = max(l, [], 3);
greaterThanThresholdMask = greaterThanThresholdMask - 1;

% With an accurate map in hand, now find the first frame of each trial at which a prediction can be made.
trialFirstFrame = zeros(1, numTrials);
frac = zeros(1, numTrials);
for currTrial = 1:numTrials    
    % By default include correction trials, as those are useful info.  Consider excluding if don't get good results.
    actLocX = getActionLoc(actRecs, currTrial);
    stimLocX = getStimLoc(actRecs, currTrial);
        
    replaysFileID = fopen([replaysFolder replaysFileNames{currTrial}]);
    if (replaysFileID ~= -1)
        repRecs = textscan(replaysFileID, '%f %f %f %f %f %f %f %f', 'Delimiter', {';', ','}); 
        fclose(replaysFileID); % done with it.
        % Sometimes, if a game is canceled before starting, there might be a blank replay file.  This handles that.
        if (isempty(repRecs{1}))
            disp('skipping empty replay file...');
            continue;
        end

        numFrames = length(repRecs{3}(:));
        if (actLocX == stimLocX)
            endDelay = 2;
        else
            endDelay = 4;
        end
        % For each frame, find the mouse's position and stop if position is in greaterThanThreshold map
        for frame = 1:numFrames  % xPos might be recorded w/o zPos, so only read lines up to max that have a zPos
            xPos = round(repRecs{1}(frame));  % Need to incorporate poolingSize later
            zPos = round(repRecs{3}(frame));

            xBin = round((xPos - minX) / poolingSize) + 1;
            zBin = round((zPos - minZ) / poolingSize) + 1;
            
            acc = locAccuracy(zBin, xBin, :);
            if (isempty(acc(acc > threshold)))
                continue;
            else
                idx = find(acc == max(acc));
                trialFirstFrame(currTrial) = frame;
                frac(currTrial) = round(frame / (numFrames - endDelay * fps), 2);
                if (currTrial == numTrials)  % last trial, so no delay at the end
                    frac(currTrial) = round(frame / numFrames, 2);
                end
                disp([num2str(currTrial) ':' num2str(frame) ':' num2str(frac(currTrial))]);
                break;
            end
        end
    end
end

figure;
if (numTargets == 3)
    colormap(colors3);
elseif (numTargets == 4)
    colormap(colors4);
end
imagesc(flipud(winnerMask));
title('Winner take all');

figure
if (numTargets == 3)
    colormap(colors3);
elseif (numTargets == 4)
    colormap(colors4);
end
imagesc(flipud(greaterThanThresholdMask));
title(['Positions with threshold >= ' num2str(threshold)]);

disp(['Mean frac = ' num2str(round(mean(frac), 2))]);

end