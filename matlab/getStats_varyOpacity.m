function [normLeftSightRate, normRightSightRate, leftBlindRate, rightBlindRate, ...
    normLeftOnlySightRate, normRightOnlySightRate] = ...
    getStats(loc, mouseName, days, sessions, sightRate, includeCorrectionTrials, analyzeCensored)
% This function will analyze the relevant actions.txt log files and return a set of statistics useful to analyzing 
% blindness and blindsight, as well as a 2AFC stimulus discrimination task.
%
% It supports 2-choice levels, 3-choice levels, 4-choice levels, and mixed levels for blindness/blindsight.  The
% world-type is determined by the filename, though in the future it should be embedded in the trial record itself.
%
% It also supports 2 alternative forced choice (2AFC) for visual discrimination. It calculates accuracy as well as d' 
% for these experiments. 
%
% It also supports a separate category of catch trials, looking for the catch entry for a trial to be true, 
% or -1,-1,-1 stim location.
%
% sightRate is a rate from 0 to 1 for how often the mouse was sighted on 3-choice, to calculate chance rates on 4-choice

actionsFolderLocal = '.\';
actionsFolderUCB = getPathActionsFolder();
actionsFolderUCSF = 'C:\Users\nikhi\UCSF\data\';

% X locs of 2-choice, 3-chioce and 4-choice worlds
% Note that finding targets based on X-position is no longer used.  Kept for backwards compatibility to 6/29/20 and before.
nearLeftX = 19975;
farLeftX = 19976;
centerX = 20000;
nearRightX = 20025;
farRightX = 20024;

nearLeftXDiag = 19973;
farLeftXDiag = 19972;
nearRightXDiag = 20027;
farRightXDiag = 20028;

discLeftX = 19980;
discRightX = 20020;

catchX = -1;
catchIdx = -1;
zCutoff = 20050;  % Used to separate front from rear stimuli in the one-sided 2AFC

normLeftOnlySightRate = -1;
normRightOnlySightRate = -1;

% Results are stored for each world separately, and each cell contains a cell which has arrays for 2-, 3- or 4-choice
% For 2-, 3- and 4-choice, there are results and results_catch matrices.
% For 3-choice, there is also a results_extinction matrix.
% Each 2-d array in the matrix is duplicated for non-opto, optoL, optoR and optoBoth.
% Columns are stim locations, rows are actions.

% For ranges of opacities, the results are duplicated for each pair of opacities (for 3-choice)

worldResults = {};
worldTypes = [];  % this keeps track of whether the world is 2-, 3- or 4-choice.
worldTypesStr = {};

% Templates used below
results_2choice = zeros(2,2,4);
results_2choice_catch = zeros(2,1,4);  % No target presented in these results for "catch" trials
durations_2choice = cell(2,2,4);

results_3choice = zeros(3,4);
durations_3choice = cell(3,3,4);

% To record actions with different opacity singles and tuples, keep containers for each
% The key will be  the opacities displayed, e.g. '[1 0.06]' for an LC or RC trial and '[0.03]' for a LO, RO or CO trial
% The value will be a results vector of 3 entries, L, R or S actions, with 4 opto states.  So a 3x4 matrix.

results_4choice = zeros(4,4,4);
results_4choice_catch = zeros(4,1,4);
results_4choice_extinction = zeros(4,4,4);
durations_4choice = cell(4,4,4);

% Haven't tested in a while - might not work any more
results_disc = zeros(2,2,4);
results_disc_catch = zeros(2,2,4);

% For 3-choice perimetry, which was too difficult for the mice to learn so I no longer use it.  This analysis script still supports it.
leftStimStraightErrorsMap = containers.Map();
rightStimStraightErrorsMap = containers.Map();

% First, find all the filenames to read in
if (loc == 'UCB')
    actionsFolder = actionsFolderUCB;
elseif (loc == 'UCSF')
    actionsFolder = actionsFolderUCSF;
else
    actionsFolder = actionsFolderLocal;
end

if analyzeCensored
    fileList = dir([actionsFolder mouseName '*actions_censored.txt']);
else
    fileList = dir([actionsFolder mouseName '*actions.txt']); % Get all mat files, and use that to construct filenames for video files
end

numFilesAnalyzed = 0;
for i=1:length(fileList)
    for j=1:length(days)
        if (contains(lower(fileList(i).name), [lower(mouseName) '-d' num2str(days(j)) '-']))
            matchesSession = false;
            if isempty(sessions)
                matchesSession = true;
            else
                if (contains(fileList(i).name, ['-S' num2str(sessions(j))]))
                    matchesSession = true;
                end
            end
            if (matchesSession)
                fid = fopen([fileList(i).folder '\' fileList(i).name]);
                if (fid ~= -1)  % File was opened properly
                    numFilesAnalyzed = numFilesAnalyzed + 1;
                    tline = fgetl(fid); % Throw out the first line, as it is a column header
                    trialRecs = textscan(fid, getActionLineFormat()); 
                    strs = split(fileList(i).name, '-');  % Example filename: Waldo-D100-3_BG_Bl_R_10-S5_actions
                    % Take the 3rd string, and split by underscores to find the number of choices.
                    % In the future, record the level type in the actions file itself at the top.
                    world_parts = split(strs{3}, '_');
                    if (isempty(worldTypes))  % only initialize variables once
                        if(~isnan(str2double(world_parts{1}(1))))
                            worldTypes(end+1) = str2double(world_parts{1}(1));
                            worldTypesStr{end+1} = world_parts{1};
                            if (~isnan(str2double(world_parts{2}(1))))
                                worldTypes(end+1) = str2double(world_parts{2}(1));
                                worldTypesStr{end+1} = world_parts{2};
                            end
                        end
                        for (w_i = 1:length(worldTypes))
                            if (worldTypes(w_i) == 2)
                               worldResults{w_i} = cell(3,1);
                               worldResults{w_i}{1} = results_2choice;
                               worldResults{w_i}{2} = results_2choice_catch;
                               worldResults{w_i}{3} = durations_2choice;
                            elseif (worldTypes(w_i) == 3)
                               worldResults{w_i} = cell(4,1);
                               worldResults{w_i}{1} = cell (2,1);
                               worldResults{w_i}{1}{1} = containers.Map();  % LC trial maps
                               worldResults{w_i}{1}{2} = containers.Map();  % RC trial maps
                               worldResults{w_i}{2} = results_3choice;  % catch is not a map as no opacity to vary
                               worldResults{w_i}{3} = cell (3,1);
                               worldResults{w_i}{3}{1} = containers.Map();  % LO trial maps
                               worldResults{w_i}{3}{2} = containers.Map();  % RO trial maps
                               worldResults{w_i}{3}{3} = containers.Map();  % CO trial maps
                               worldResults{w_i}{4} = durations_3choice; % Need to fix later...
                            elseif (worldTypes(w_i) == 4)
                               worldResults{w_i} = cell(4,1);
                               worldResults{w_i}{1} = results_4choice;
                               worldResults{w_i}{2} = results_4choice_catch;
                               worldResults{w_i}{3} = results_4choice_extinction;
                               worldResults{w_i}{4} = durations_4choice;
                            else
                               error('Script currently supports worlds with 2-4 choices, no more.');
                            end
                        end
                    end
                    
                    for trialIdx = 1:length(trialRecs{1})  % For each trial
                        [stimLocX, ~] = getStimLoc(trialRecs, trialIdx);
                        [actionLocX, ~] = getActionLoc(trialRecs, trialIdx);
                        stimIdx = getStimIdx(trialRecs, trialIdx);
                        stimOpacity = getStimOpacity(trialRecs, trialIdx);
                        distractorOpacity = getDistractorOpacity(trialRecs, trialIdx);
                        actionIdx = getActionIdx(trialRecs, trialIdx);
                        optoLoc = getOptoLoc(trialRecs, trialIdx);
                        worldIdx = getWorldIdx(trialRecs, trialIdx);
                        isCorrectionTrial = getCorrection(trialRecs, trialIdx);
                        dur = getDuration(trialRecs, trialIdx);  % returns in seconds
                        
                        if (isCorrectionTrial && ~includeCorrectionTrials)
                            continue;
                        end
                        
                        %disp(trialIdx)
                        
                        currCatch = 0;
                        
                        isExtinctionTrial = getExtinction(trialRecs, trialIdx);
                        
                        if (worldTypes(worldIdx+1) == 2) % This is a trial in a 2-choice world
                            if (~isnan(stimIdx))  % new record format (post 6/29/20)
                                if (stimIdx == catchIdx)
                                    currCatch = 1;
                                else
                                    col = stimIdx + 1;
                                end
                            else  % old record format, for backwards compatibility
                                if (stimLocX == nearLeftX)
                                    col = 1;
                                elseif (stimLocX == farLeftX)
                                    col = 2;
                                elseif (stimLocX == nearRightX)
                                    % Hack that assumes that on 2H levels, R
                                    % level always comes second
                                    if (length(worldTypes) == 1)  % Assumes no 2R-only levels
                                        col = 2;
                                    elseif (length(worldTypes) == 2 && worldIdx == 0)
                                        col = 2;
                                    elseif (length(worldTypes) == 2 && worldIdx == 1)
                                        col = 1;
                                    end
                                elseif (stimLocX == farRightX)
                                    col = 2;
                                elseif (stimLocX == catchX) % Catch trials!
                                    currCatch = 1;
                                else
                                    error('Unexpected stimLocX');
                                end
                            end

                            if (~isnan(actionIdx)) % new record format (post 6/29/20)
                                row = actionIdx + 1;
                            else % old record format, for backwards compatibility
                                if (actionLocX == nearLeftX)
                                    row = 1;
                                elseif (actionLocX == farLeftX)
                                    row = 2;
                                elseif (actionLocX == nearRightX)
                                    % Hack that assumes that on 2H levels, R
                                    % level always comes second
                                    if (length(levels) == 1)  % Assumes no 2R-only levels
                                        row = 2;
                                    elseif (length(levels) == 2 && worldIdx == 0)
                                        row = 2;
                                    elseif (length(levels) == 2 && worldIdx == 1)
                                        row = 1;
                                    end
                                elseif (actionLocX == farRightX)
                                    row = 2;
                                else
                                    disp('action does not match an expected target location');
                                end
                            end
                            
                            if (~currCatch)
                                worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) + 1;
                                worldResults{worldIdx+1}{3}{row, col, optoLoc + 2} = ...
                                    [worldResults{worldIdx+1}{3}{row, col, optoLoc + 2} dur];
                            else
                                worldResults{worldIdx+1}{2}(row, 1, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{2}(row, 1, optoLoc + 2) + 1;
                            end
                            
                        elseif (worldTypes(worldIdx+1) == 3)   % This is a 3-choice trial!
                            if (~isnan(stimIdx))  % works with new trialRecs post 6/29/20
                                if (stimIdx == catchIdx)
                                    currCatch = 1;
                                else
                                    col = stimIdx + 1;
                                end
                            else  % compatibility with old trialRecs
                                if (stimLocX == nearLeftX)
                                    col = 1;
                                elseif (stimLocX == nearRightX)
                                    col = 2;
                                elseif (stimLocX == centerX)
                                    col = 3;
                                elseif (stimLocX == catchX)
                                    currCatch = 1;
                                else
                                    error('Unexpected stimLocX');
                                end
                            end
                            
                            if (~isnan(actionIdx)) % new record format (post 6/29/20)
                                row = actionIdx + 1;
                            else % old record format, for backwards compatibility
                                if (actionLocX == nearLeftX)
                                    row = 1;
                                elseif (actionLocX == nearRightX)
                                    row = 2;
                                elseif (actionLocX == centerX)
                                    row = 3;
                                else
                                    error('action does not match an expected target location');
                                end
                            end
                                                        
                            % Record trial in the correct map
                            if (currCatch)  % It is a catch trial - no change since adding maps
                                worldResults{worldIdx+1}{2}(row, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{2}(row, optoLoc + 2) + 1;
                            else
                                if (isExtinctionTrial || col == 3)  % It is an LO or RO or CO trial, with possibly varying opacities
                                    key = num2str(stimOpacity);  % Set the map key 
                                    idx = 3;
                                else
                                    key = [num2str(stimOpacity) '/' num2str(distractorOpacity)];
                                    idx = 1;
                                end
                                % First, check to see if this opacity has been seen before. 
                                % If no, set it up and initialize the counts to 0
                                % If yes or no, increment the count in the map for the action taken
                                if (~isKey(worldResults{worldIdx+1}{idx}{col}, key))
                                    worldResults{worldIdx+1}{idx}{col}(key) = results_3choice;  % Assign an empty matrix
                                end
                                v = values(worldResults{worldIdx+1}{idx}{col}, {key});
                                v{1}(row, optoLoc + 2) = v{1}(row, optoLoc + 2) + 1;
                                worldResults{worldIdx+1}{idx}{col}(key) = v{1};
                                % old approach without maps
                                % worldResults{worldIdx+1}{3}{row}(row, col, optoLoc + 2) = ...
                                %    worldResults{worldIdx+1}{3}(row, col, optoLoc + 2) + 1;
                           % else  % This is a 2-target trial
                           %     worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) = ...
                           %         worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) + 1;
                           %     worldResults{worldIdx+1}{4}{row, col, optoLoc + 2} = ...
                           %         [worldResults{worldIdx+1}{4}{row, col, optoLoc + 2} dur];
                            end
                            
                        elseif (worldTypes(worldIdx+1) == 4)
                            if (~isnan(stimIdx))  % works with new trialRecs post 6/29/20
                                if (stimIdx == catchIdx)
                                    currCatch = 1;
                                else
                                    col = stimIdx + 1;
                                end
                            else % backwards compatible
                                if (stimLocX == nearLeftXDiag)
                                    col = 1;
                                elseif (stimLocX == nearRightXDiag)
                                    col = 2;
                                elseif (stimLocX == farLeftXDiag)
                                    col = 3;
                                elseif (stimLocX == farRightXDiag)
                                    col = 4;
                                elseif (stimLocX == catchX)
                                    currCatch = 1;
                                else
                                    error('Unexpected stimLocX');
                                end
                            end
                            
                            if (~isnan(actionIdx)) % new record format (post 6/29/20)
                                row = actionIdx + 1;
                            else % old record format, for backwards compatibility
                                if (actionLocX == nearLeftXDiag)
                                    row = 1;
                                elseif (actionLocX == nearRightXDiag)
                                    row = 2;
                                elseif (actionLocX == farLeftXDiag)
                                    row = 3;
                                elseif (actionLocX == farRightXDiag)
                                    row = 4;
                                else
                                    error('action does not match an expected target location');
                                end
                            end
                            
                            % Put trials in correct sheet
                            if (currCatch)
                                worldResults{worldIdx+1}{2}(row, 1, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{2}(row, 1, optoLoc + 2) + 1;
                            elseif (isExtinctionTrial)
                                worldResults{worldIdx+1}{3}(row, col, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{3}(row, col, optoLoc + 2) + 1;
                            else
                                worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) = ...
                                    worldResults{worldIdx+1}{1}(row, col, optoLoc + 2) + 1;
                                worldResults{worldIdx+1}{4}{row, col, optoLoc + 2} = ...
                                    [worldResults{worldIdx+1}{4}{row, col, optoLoc + 2} dur];
                            end
                        elseif (stimLocX == discLeftX || stimLocX == discRightX) % Haven't tested in a while.  Might not work anymore
                            if (stimLocX == discLeftX)
                                col = 1;
                            elseif (stimLocX == discRightX)
                                col = 2;
                            else
                                currCatch = 1;
                            end
                            
                            if (actionLocX == discLeftX)
                                row = 1;
                            elseif (actionLocX == discRightX)
                                row = 2;
                            end
                            % Put trials in correct sheet
                            if (~currCatch)
                                results_disc(row, col, optoLoc + 2) = results_disc(row, col, optoLoc + 2) + 1;
                            else 
                                results_disc_catch(row, 1, optoLoc + 2) = results_disc(row, 1, optoLoc + 2) + 1;
                            end
                        else
                            error('Do not know how to analyze these data');
                        end

                        % The following analysis only applies to the 3-choice task - Not quite sure if this is
                        % relevant any more.
                        %disp(stimIdx);
                        if (worldTypes(worldIdx+1) == 3 && ~currCatch && col ~= row)  % error trial
                            nasal = trialRecs{8}(trialIdx);
                            temporal = trialRecs{9}(trialIdx);
                            high = trialRecs{10}(trialIdx);
                            low = trialRecs{11}(trialIdx);
                            key = ['N' num2str(nasal) '_T' num2str(temporal) '_H' num2str(high) '_L' num2str(low)];
                            prevVal = 0;
                            if (actionLocX == centerX)
                                if (stimLocX < centerX)
                                    if (isKey(leftStimStraightErrorsMap, key))
                                        prevVal = leftStimStraightErrorsMap(key);
                                    end
                                    leftStimStraightErrorsMap(key) = prevVal + 1; %#ok<*NASGU>
                                elseif (stimLocX > centerX)
                                    if (isKey(rightStimStraightErrorsMap, key))
                                        prevVal = rightStimStraightErrorsMap(key);
                                    end
                                    rightStimStraightErrorsMap(key) = prevVal + 1; %#ok<*NASGU>
                                end
                            end
                        end
                    end
                end
                fclose(fid);
            end
        end
    end
end

% Array which has the values needed for GraphPad.  These get printed out at the end for easy copy and paste
graphPad = [];
graphPadL = [];
graphPadR = [];
ca1 = 0;
ca2 = 0;
ca3 = 0;
ca4 = 0;

% Iterate through all worlds and print the results separately for each
% In general right now there will be 1 or 2 world types, but in principle there can be more
for (worldIdx = 1:length(worldTypes))
    if (worldTypes(worldIdx) == 2)
        disp('///////2-CHOICE///////');
        results = worldResults{worldIdx}{1};  % just a helper
        observed = zeros(2,2,size(results,3));  % First row is correct, second row is incorrect

        for j = 1:size(results,3)
            % Don't display results if none for this opto-type
            cnt = sum(sum(results));
            if (cnt(j) == 0)
                continue;
            end
            if (j == 1) 
                disp('=====Non-Opto======')
            elseif (j == 2)
                disp('=====Opto Left======')
            elseif (j == 3)
                disp('=====Opto Right======')
            elseif (j == 4)
                disp('=====Opto Both======')
            end
            numCorrect = results(1,1,j)+results(2,2,j);
            numTrials = sum(sum(results(:,:,j)));
            disp(['ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);

            if (strcmp(worldTypesStr{worldIdx}, '2L'))
                label1 = 'NL-NL';
                label2 = 'NL-FL';
                label3 = 'FL-NL';
                label4 = 'FL-FL';
            elseif (strcmp(worldTypesStr{worldIdx}, '2R'))
                label1 = 'NR-NR';
                label2 = 'NR-FR';
                label3 = 'FR-NR';
                label4 = 'FR-FR';
            else
                label1 = 'L-L';
                label2 = 'L-R';
                label3 = 'R-L';
                label4 = 'R-R';
            end
            total1 = sum(results(:,1,j));
            observed(1,1,j) = results(1,1,j);  % correct
            observed(2,1,j) = total1 - results(1,1,j); % incorrect
            res1 = str2double(num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3));
            disp([label1 ' = ' num2str(res1) '% (' num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            res2 = str2double(num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3));
            disp([label2 ' = ' num2str(res2) '% (' num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp('-----------')

            total2 = sum(results(:,2,j));
            observed(1,2,j) = results(2,2,j);
            observed(2,2,j) = total2 - results(2,2,j);
            res3 = str2double(num2str(round(results(1,2,j) / sum(results(:,2,j)) * 100), 3));
            disp([label3 ' = ' num2str(res3) '% (' num2str(results(1,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
            res4 = str2double(num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3));
            disp([label4 ' = ' num2str(res4) '% (' num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
            disp('-----------')
            disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
                  num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3)]);        
            disp('-----------')
            disp([num2str(numCorrect/numTrials * 100, 2)]);
            disp('===========')
            if (strcmp(worldTypesStr{worldIdx}, '2L'))
                graphPadL = [res1 0 res2 0 res3 0 res4 0];
            elseif (strcmp(worldTypesStr{worldIdx}, '2R'))
                graphPadR = [0 res1 0 res2 0 res3 0 res4];
            end
        end

        results = worldResults{worldIdx}{2};  % just a helper - these are the catch trial results
        if (sum(sum(sum(results))) > 0)
            disp('///////2-CHOICE CATCH///////');
            for j = 1:size(results,3)
                expectedFrac = zeros(1,2);

                % Don't display results if none for this opto-type
                cnt = sum(results);
                if (cnt(j) == 0)
                    continue;
                end
                if (j == 1) 
                    disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(results(:,:,j)));
                expectedFrac(1) = results(1,1,j) / sum(results(:,1,j));
                expectedFrac(2) = results(2,1,j) / sum(results(:,1,j));

                if (strcmp(worldTypesStr{worldIdx}, '2L'))
                    label1 = 'NEAR LEFT';
                    label2 = 'FAR LEFT';
                    ca1 = str2double(num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3));
                    ca3 = str2double(num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3));
                    disp([label1 ' BIAS = ' num2str(ca1) '% (' num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                    disp([label2 ' BIAS = ' num2str(ca3) '% (' num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                elseif (strcmp(worldTypesStr{worldIdx}, '2R'))
                    label1 = 'NEAR RIGHT';
                    label2 = 'FAR RIGHT';
                    ca2 = str2double(num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3));
                    ca4 = str2double(num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3));
                    disp([label1 ' BIAS = ' num2str(ca2) '% (' num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                    disp([label2 ' BIAS = ' num2str(ca4) '% (' num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                else
                    label1 = 'LEFT';
                    label2 = 'RIGHT';
                end
                
                disp('-----------')

                % Do chi-squared test, adjusted for the sight rate!
                observedCorrect = observed(1,1,j) + observed(1,2,j);
                expectedCorrectByChance = expectedFrac(1) * ((1-sightRate)*total1) + expectedFrac(2) * ((1-sightRate)*total2);
                expectedCorrect = sightRate * (total1+total2) + expectedCorrectByChance;
                total = total1 + total2;
                if (strcmp(worldTypesStr{worldIdx}, '2L'))
                    %if (observedCorrect - expectedCorrect >= 0)
                        normLeftSightRate = (observedCorrect - expectedCorrect) / (total - expectedCorrect);
                    %else
                    %    normLeftSightRate = (observedCorrect - expectedCorrect) / expectedCorrect;
                    %end
                elseif (strcmp(worldTypesStr{worldIdx}, '2R'))
                    %if (observedCorrect - expectedCorrect >= 0)
                        normRightSightRate = (observedCorrect - expectedCorrect) / (total - expectedCorrect);
                    %else
                    %    normRightSightRate = (observedCorrect - expectedCorrect) / expectedCorrect;
                    %end
                end
                
                expectedIncorrectByChance = (1 - expectedFrac(1)) * ((1-sightRate)*total1) + (1 - expectedFrac(2)) * ((1-sightRate)*total2);
                expectedIncorrectByChanceAndSight = expectedIncorrectByChance;
                disp(['Expected correct by chance = ' num2str(expectedCorrect)])
                disp(['Observed correct = ' num2str(observedCorrect)])
                disp(['Normalized sight rate = ' num2str((observedCorrect - expectedCorrect) / (total - expectedCorrect))]);
                disp(['Chi-squared p = ' num2str(chisquared(observed(1,1,j) + observed(1,2,j), expectedCorrect, ...
                                            observed(2,1,j) + observed(2,2,j), expectedIncorrectByChance))]);
                disp('---------------');
                
                disp('================')
            end
            if (strcmp(worldTypesStr{worldIdx}, '2R'))
                sumCa = ca1 + ca2 + ca3 + ca4;
                disp([graphPadL(1:4) graphPadR(1:4) graphPadL(5:8) graphPadR(5:8) round(ca1/sumCa*100) round(ca2/sumCa*100) round(ca3/sumCa*100) round(ca4/sumCa*100)]);
            end
        end
        
    elseif (worldTypes(worldIdx) == 3)  % Updated to support Maps instead of direct matrices
        fprintf(2, '<strong>///////3-CHOICE///////</strong>\n');
        resultsLCRC_Maps = worldResults{worldIdx}{1};  % just a helper

        accuracies_LC_RC_LO_RO_CO = zeros(5,1);
        
        for k = 1:2 % for LC and then RC
            keySet = keys(resultsLCRC_Maps{k});
            if (k == 1)
                trialType = 'LC';
            else
                trialType = 'RC';
            end
            % Used to tally overall accuracy regardless of opacity
            numCorrectAllOpacities = 0;
            numTrialsAllOpacities = 0;
            for m = 1:length(keySet)  % for each pair of opacities, print out the results
                results = values(resultsLCRC_Maps{k}, {keySet{m}});
                results = results{1};
                disp(['<strong>==== ' trialType ': ' keySet{m} ' ====</strong>']); 
                % It might be better to iterate through the opto types at a higher level, so all results from a specific optotype are grouped. Consider changing later, let's see
                for j = 1:size(results,2)  % now, iterate through the opto-types for this opacity pair
                    % Don't display results if none for this opto-type
                    cnt = sum(results(:,j));
                    if (cnt == 0)
                        continue;
                    end
                    if (j == 1) 
                        %disp('=====Non-Opto======')
                    elseif (j == 2)
                        disp('=====Opto Left======')
                    elseif (j == 3)
                        disp('=====Opto Right======')
                    elseif (j == 4)
                        disp('=====Opto Both======')
                    end
                    if (k==2)
                        %a;
                    end
                    numCorrectAllOpacities = numCorrectAllOpacities + results(k,j);
                    numTrialsAllOpacities = numTrialsAllOpacities + sum(results(:,j));
                    %disp(['ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);

                    label1 = [trialType '-L'];
                    label2 = [trialType '-R'];
                    label3 = [trialType '-S'];

                    res1 = str2double(num2str(round(results(1,j) / sum(results(:,j)) * 100), 3));
                    disp([label1 ' = ' num2str(res1) '% (' num2str(results(1,j)) '/' num2str(sum(results(:,j))) ')']);

                    res2 = str2double(num2str(round(results(2,j) / sum(results(:,j)) * 100), 3));
                    disp([label2 ' = ' num2str(res2) '% (' num2str(results(2,j)) '/' num2str(sum(results(:,j))) ')']);

                    res3 = str2double(num2str(round(results(3,j) / sum(results(:,j)) * 100), 3));
                    disp([label3 ' = ' num2str(res3) '% (' num2str(results(3,j)) '/' num2str(sum(results(:,j))) ')']);
                    disp('-----------')
                    
                    %if (strcmp(keySet{m}.)
                    %   a; 
                    %end
                end
            end
            accuracies_LC_RC_LO_RO_CO(k) = round(numCorrectAllOpacities / numTrialsAllOpacities * 100);
            disp(['<strong>OVERALL ACCURACY ON ' trialType ' = ' num2str(accuracies_LC_RC_LO_RO_CO(k), 3) '%</strong>']);
        end
        
        resultsLOROCO_Maps = worldResults{worldIdx}{3};  % just a helper
        for k=1:3
            keySet = keys(resultsLOROCO_Maps{k});
            if (k == 1)
                trialType = 'LO';
            elseif (k == 2)
                trialType = 'RO';
            else
                trialType = 'CO';    
            end            
            % Used to tally overall accuracy regardless of opacity
            numCorrectAllOpacities = 0;
            numTrialsAllOpacities = 0;
            for m = 1:length(keySet)  % for each pair of opacities, print out the results
                results = values(resultsLOROCO_Maps{k}, {keySet{m}});
                results = results{1};
                disp(['<strong>==== ' trialType ': ' keySet{m} ' ====</strong>']); 
                % It might be better to iterate through the opto types at a higher level, so all results from a specific optotype are grouped. Consider changing later, let's see
                for j = 1:size(results,2)  % now, iterate through the opto-types for this opacity pair
                    % Don't display results if none for this opto-type
                    cnt = sum(results(:,j));
                    if (cnt == 0)
                        continue;
                    end
                    if (j == 1) 
                        %disp('=====Non-Opto======')
                    elseif (j == 2)
                        disp('=====Opto Left======')
                    elseif (j == 3)
                        disp('=====Opto Right======')
                    elseif (j == 4)
                        disp('=====Opto Both======')
                    end
                    if (k==2)
                        %a;
                    end
                    numCorrectAllOpacities = numCorrectAllOpacities + results(k,j);
                    numTrialsAllOpacities = numTrialsAllOpacities + sum(results(:,j));
                    %disp(['ACCURACY = ' num2str(results(k,j) / sum(results(:,j)) * 100, 2) '%']);

                    label1 = [trialType '-L'];
                    label2 = [trialType '-R'];
                    label3 = [trialType '-S'];

                    res1 = str2double(num2str(round(results(1,j) / sum(results(:,j)) * 100), 3));
                    disp([label1 ' = ' num2str(res1) '% (' num2str(results(1,j)) '/' num2str(sum(results(:,j))) ')']);

                    res2 = str2double(num2str(round(results(2,j) / sum(results(:,j)) * 100), 3));
                    disp([label2 ' = ' num2str(res2) '% (' num2str(results(2,j)) '/' num2str(sum(results(:,j))) ')']);

                    res3 = str2double(num2str(round(results(3,j) / sum(results(:,j)) * 100), 3));
                    disp([label3 ' = ' num2str(res3) '% (' num2str(results(3,j)) '/' num2str(sum(results(:,j))) ')']);
                    disp('-----------')
                end
            end
            accuracies_LC_RC_LO_RO_CO(k+2) = round(numCorrectAllOpacities / numTrialsAllOpacities * 100);
            disp(['<strong>OVERALL ACCURACY ON ' trialType ' = ' num2str(accuracies_LC_RC_LO_RO_CO(k+2), 3) '%</strong>']);
        end
        
        disp(['<strong>' num2str(accuracies_LC_RC_LO_RO_CO(1)) '/' num2str(accuracies_LC_RC_LO_RO_CO(2)) '/' num2str(accuracies_LC_RC_LO_RO_CO(5)) '</strong>']);
        
        % Finally, analyze blank (catch) trials
        results = worldResults{worldIdx}{2};  % just a helper - these are the catch trials
        if (sum(sum(results)) > 0)
            disp('<strong>///////3-CHOICE BLANK///////</strong>');
            for j = 1:size(results,2)   % For each opto type
                % Don't display results if none for this opto-type
                cnt = sum(results(:,j));
                if (cnt == 0)
                    continue;
                end
                if (j == 1) 
                    %disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(results(:,:,j)));
                
                if (strcmp(worldTypesStr{worldIdx}, '3L'))
                    label1 = 'NEAR LEFT';
                    label2 = 'FAR LEFT';
                    label3 = 'STRAIGHT';
                elseif (strcmp(worldTypesStr{worldIdx}, '3R'))
                    label1 = 'NEAR RIGHT';
                    label2 = 'FAR RIGHT';
                    label3 = 'STRAIGHT';
                else
                    label1 = 'LEFT';
                    label2 = 'RIGHT';
                    label3 = 'STRAIGHT';
                end
                
                res1 = str2double(num2str(round(results(1,j) / sum(results(:,j)) * 100), 3));
                disp([label1 ' BIAS = ' num2str(res1) '% (' num2str(results(1,j)) '/' num2str(sum(results(:,j))) ')']);
                
                res2 = str2double(num2str(round(results(2,j) / sum(results(:,j)) * 100), 3));
                disp([label2 ' BIAS = ' num2str(res2) '% (' num2str(results(2,j)) '/' num2str(sum(results(:,j))) ')']);
                
                res3 = str2double(num2str(round(results(3,j) / sum(results(:,j)) * 100), 3));
                disp([label3 ' BIAS = ' num2str(res3) '% (' num2str(results(3,j)) '/' num2str(sum(results(:,j))) ')']);            
                disp('-----------')
            end
        end

        
        
        disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '/' ...
              num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 3)]);        
        disp('-----------')

        % Special calculations for 3F level
        if (strcmp(worldTypesStr{worldIdx}, '3L'))
            leftBlindRate = round((results(3,1,j) + results(3,2,j)) / (sum(results(:,1,j)) + sum(results(:,2,j))) * 100);
            normLeftSightRate = mean( [ results(1,1,j) / sum(results(:,1,j)) - results(1,3,j) / sum(results(:,3,j)), ...
                                      results(2,2,j) / sum(results(:,2,j)) - results(2,3,j) / sum(results(:,3,j))]);
        elseif (strcmp(worldTypesStr{worldIdx}, '3R'))
            rightBlindRate = round((results(3,1,j) + results(3,2,j)) / (sum(results(:,1,j)) + sum(results(:,2,j))) * 100);
            normRightSightRate = mean( [ results(1,1,j) / sum(results(:,1,j)) - results(1,3,j) / sum(results(:,3,j)), ...
                                      results(2,2,j) / sum(results(:,2,j)) - results(2,3,j) / sum(results(:,3,j))]);
        else
            leftBlindRate = round(results(3,1,j) / sum(results(:,1,j)) * 100);
            rightBlindRate = round(results(3,2,j) / sum(results(:,2,j)) * 100);  % Standard calculation

            expectedRightCorrect = results(2,3,j) / sum(results(:,3,j)) * sum(results(:,2,j));
            observedRightCorrect = results(2,2,j);
            %if (observedRightCorrect - expectedRightCorrect >= 0)
                normRightSightRate = (observedRightCorrect - expectedRightCorrect) / (totalRight - expectedRightCorrect);
            %else
            %    normRightSightRate = (observedRightCorrect - expectedRightCorrect) / expectedRightCorrect;
            %end
            observedLeftCorrect = results(1,1,j);
            expectedLeftCorrect = results(1,3,j) / sum(results(:,3,j)) * sum(results(:,1,j));
            normLeftSightRate = (observedLeftCorrect - expectedLeftCorrect) / (totalLeft - expectedLeftCorrect);

            observedCenterCorrect = results(3,3,j);
        end

        graphPad = [graphPad res1 res2 res3 res4 res5 res6 res7 res8 res9];

        disp([num2str(round(results(3,2,2) / sum(results(:,2,2)) * 100), 3) '/' ...
              num2str(round(results(3,1,3) / sum(results(:,1,3)) * 100), 3) ' BLIND (opto)']);
        
        % If there were some extinction trials, print out results
        resultsExt = worldResults{worldIdx}{3};  % just a helper - these are the catch trials
        if (sum(sum(sum(resultsExt))) > 0)
            disp('///////3-CHOICE UNILATERAL EXTINCTION///////');
            for j = 1:size(resultsExt,3)
                % Don't display results if none for this opto-type
                cnt = sum(sum(resultsExt(:,:,j)));
                if (cnt == 0)
                    continue;
                end
                if (j == 1) 
                    disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(resultsExt(:,:,j)));
                
                if (strcmp(worldTypesStr{worldIdx}, '3L'))
                    label1 = 'NLO-NL';
                    label2 = 'NLO-FL';
                    label3 = 'NLO-S';
                    label4 = 'FLO-NL';
                    label5 = 'FLO-FL';
                    label6 = 'FLO-S';
                elseif (strcmp(worldTypesStr{worldIdx}, '3R'))
                    label1 = 'NRO-NR';
                    label2 = 'NRO-FR';
                    label3 = 'NRO-S';
                    label4 = 'FRO-NR';
                    label5 = 'FRO-FR';
                    label6 = 'FRO-S';
                else
                    label1 = 'LO-L';
                    label2 = 'LO-R';
                    label3 = 'LO-S';
                    label4 = 'RO-L';
                    label5 = 'RO-R';
                    label6 = 'RO-S';
                end
                
                res1 = str2double(num2str(round(resultsExt(1,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp([label1 ' = ' num2str(res1) '% (' num2str(resultsExt(1,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                
                res2 = str2double(num2str(round(resultsExt(2,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp([label2 ' = ' num2str(res2) '% (' num2str(resultsExt(2,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);

                res3 = str2double(num2str(round(resultsExt(3,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp([label3 ' = ' num2str(res3) '% (' num2str(resultsExt(3,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                disp('-----------')

                res4 = str2double(num2str(round(resultsExt(1,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp([label4 ' = ' num2str(res4) '% (' num2str(resultsExt(1,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                
                res5 = str2double(num2str(round(resultsExt(2,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp([label5 ' = ' num2str(res5) '% (' num2str(resultsExt(2,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                
                res6 = str2double(num2str(round(resultsExt(3,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp([label6 ' = ' num2str(res6) '% (' ...
                                 num2str(resultsExt(3,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                disp('-----------')
                
                graphPad = [graphPad res1 res2 res3 res4 res5 res6];
            end
        end

        results = worldResults{worldIdx}{2};  % just a helper - these are the catch trials
        if (sum(sum(sum(results))) > 0)
            disp('///////3-CHOICE CATCH///////');
            for j = 1:size(results,3)
                % Don't display results if none for this opto-type
                cnt = sum(results);
                if (cnt(j) == 0)
                    continue;
                end
                if (j == 1) 
                    disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(results(:,:,j)));
                
                if (strcmp(worldTypesStr{worldIdx}, '3L'))
                    label1 = 'NEAR LEFT';
                    label2 = 'FAR LEFT';
                    label3 = 'STRAIGHT';
                elseif (strcmp(worldTypesStr{worldIdx}, '3R'))
                    label1 = 'NEAR RIGHT';
                    label2 = 'FAR RIGHT';
                    label3 = 'STRAIGHT';
                else
                    label1 = 'LEFT';
                    label2 = 'RIGHT';
                    label3 = 'STRAIGHT';
                end
                
                res1 = str2double(num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3));
                disp([label1 ' BIAS = ' num2str(res1) '% (' num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                
                res2 = str2double(num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3));
                disp([label2 ' BIAS = ' num2str(res2) '% (' num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                
                res3 = str2double(num2str(round(results(3,1,j) / sum(results(:,1,j)) * 100), 3));
                disp([label3 ' BIAS = ' num2str(res3) '% (' num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);            
                disp('-----------')

                % Special calculations for 3F level
                if (strcmp(worldTypesStr{worldIdx}, '3L') || strcmp(worldTypesStr{worldIdx}, '3R'))
                    extOrBSRate = round((round(resultsExt(1,1,j) / sum(resultsExt(:,1,j)) * 100) - round(results(1,1,j) / sum(results(:,1,j)) * 100) ...
                                    + round(resultsExt(2,2,j) / sum(resultsExt(:,2,j)) * 100) - round(results(2,1,j) / sum(results(:,1,j)) * 100))/2);
                    % the below might be wrong - investigate if get fishy answers
                    if (extOrBSRate > 0)
                        normExtOrBSRate = round(extOrBSRate / (100 - (round(sum(results(1:2,1,j)) / (2*sum(results(:,1,j)))*100))) * 100);
                    else
                        normExtOrBSRate = round(extOrBSRate / (round(sum(results(1:2,1,j) / (2*sum(results(:,1,j)))*100))) * 100);
                    end
                else
                    rExtRate = round(resultsExt(2,2,j) / sum(resultsExt(:,2,j)) * 100);
                    rCatchRate = round(results(2,1,j) / sum(results(:,1,j)) * 100);
                    rExtOrBSRate = rExtRate - rCatchRate;
                    if (rExtOrBSRate >= 0)
                        normRightExtOrBSRate = round(rExtOrBSRate / (100 - rCatchRate) * 100);
                    else
                        normRightExtOrBSRate = round(rExtOrBSRate / rCatchRate * 100);                        
                    end
                    lExtRate = round(resultsExt(1,1,j) / sum(resultsExt(:,1,j)) * 100);
                    lCatchRate = round(results(1,1,j) / sum(results(:,1,j)) * 100);
                    lExtOrBSRate = lExtRate - lCatchRate;
                    if (lExtOrBSRate >= 0)
                        normLeftExtOrBSRate = round(lExtOrBSRate / (100 - lCatchRate) * 100);
                    else
                        normLeftExtOrBSRate = round(lExtOrBSRate / lCatchRate * 100);                        
                    end

                    expectedCenterCorrect = round(results(3,1,j) / sum(results(:,1,j)) * totalCenter);
                    normCenterCorrectRate = (observedCenterCorrect - expectedCenterCorrect) / (totalCenter - expectedCenterCorrect);
                end
                normRightOnlySightRate = normRightExtOrBSRate / 100;
                normLeftOnlySightRate = normLeftExtOrBSRate / 100;

                % Do chi-squared test, adjusted for the sight rate!
                %{
                observedLeftCorrect = numLeftCorrect;
                expectedLeftCorrect = res1 / 100 * totalLeft;
                normLeftSightRate = (observedLeftCorrect - expectedLeftCorrect) / (totalLeft - expectedLeftCorrect);
                disp(['Expected left correct by chance = ' num2str(expectedLeftCorrect)])
                disp(['Observed left correct = ' num2str(observedLeftCorrect)])
                disp(['Chi-squared p = ' num2str(chisquared(observedLeftCorrect, expectedLeftCorrect, ...
                                            totalLeft - observedLeftCorrect, totalLeft - expectedLeftCorrect))]);
                disp(['---------------------']);

                observedRightCorrect = numRightCorrect;
                expectedRightCorrect = res2 / 100 * totalRight;
                normRightSightRate = (observedRightCorrect - expectedRightCorrect) / (totalRight - expectedRightCorrect);
                disp(['Expected right correct by chance = ' num2str(expectedRightCorrect)])
                disp(['Observed right correct = ' num2str(observedRightCorrect)])
                disp(['Chi-squared p = ' num2str(chisquared(observedRightCorrect, expectedRightCorrect, ...
                                            totalRight - observedRightCorrect, totalRight - expectedRightCorrect))]);
                disp(['---------------------']);
                %}
                                        
                graphPad = [graphPad res1 res2 res3];
            end
            
            % Summary stats to cut and paste into the sheet
            % BLINDNESS // SIGHT // EXT/BS
            if (strcmp(worldTypesStr{worldIdx}, '3L'))
                disp(['LEFT SUMMARY: ' num2str(leftBlindRate, 3) '//' num2str(round(normLeftSightRate * 100), 3) '//' num2str(extOrBSRate, 3) '//' num2str(normExtOrBSRate, 3)]);
            elseif (strcmp(worldTypesStr{worldIdx}, '3R'))
                disp(['RIGHT SUMMARY: ' num2str(rightBlindRate, 3) '//' num2str(round(normRightSightRate * 100), 3) '//' num2str(extOrBSRate, 3) '//' num2str(normExtOrBSRate, 3)]);
            else
                disp(['LEFT SUMMARY: ' num2str(leftBlindRate, 3) '//' num2str(round(normLeftSightRate * 100), 3) '//' num2str(lExtOrBSRate, 3) '//' num2str(normLeftExtOrBSRate, 3)]);
                disp(['CENTER SUMMARY: ' num2str(round(observedCenterCorrect / totalCenter * 100)) '//' num2str(round(normCenterCorrectRate * 100), 3)]);
                disp(['RIGHT SUMMARY: ' num2str(rightBlindRate, 3) '//' num2str(round(normRightSightRate * 100), 3) '//' num2str(rExtOrBSRate, 3) '//' num2str(normRightExtOrBSRate, 3)]);
            end
            disp('===========')
        end
        
        disp(graphPad);

    else if (worldTypes(worldIdx) == 4)
        disp('///////4-CHOICE///////');
        results = worldResults{worldIdx}{1};  % just a helper

        observed = zeros(2,4,size(results,3));  % First row is correct, second row is incorrect
        for j = 1:size(results,3)
            % Don't display results if none for this opto-type
            cnt = sum(sum(results));
            if (cnt(j) == 0)
                continue;
            end
            if (j == 1) 
                disp('=====Non-Opto======')
            elseif (j == 2)
                disp('=====Opto Left======')
            elseif (j == 3)
                disp('=====Opto Right======')
            elseif (j == 4)
                disp('=====Opto Both======')
            end
            numCorrect = results(1,1,j)+results(2,2,j)+results(3,3,j)+results(4,4,j);
            numTrials = sum(sum(results(:,:,j)));
            disp(['ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);
            totalNL = sum(results(:,1,j));
            observed(1,1,j) = results(1,1,j);
            observed(2,1,j) = totalNL - results(1,1,j);
            res1 = str2double(num2str(round(results(1,1,j) / totalNL * 100), 3));
            disp(['NL-NL = ' num2str(res1) '% (' num2str(results(1,1,j)) '/' num2str(totalNL) ')']);
            res2 = str2double(num2str(round(results(2,1,j) / totalNL * 100), 3));
            disp(['NL-NR = ' num2str(res2) '% (' num2str(results(2,1,j)) '/' num2str(totalNL) ')']);
            res3 = str2double(num2str(round(results(3,1,j) / totalNL * 100), 3));
            disp(['NL-FL = ' num2str(res3) '% (' num2str(results(3,1,j)) '/' num2str(totalNL) ')']);
            res4 = str2double(num2str(round(results(4,1,j) / totalNL * 100), 3));
            disp(['NL-FR = ' num2str(res4) '% (' num2str(results(4,1,j)) '/' num2str(totalNL) ')']);
            disp('-----------')
            totalNR = sum(results(:,2,j));
            observed(1,2,j) = results(2,2,j);
            observed(2,2,j) = totalNR - results(2,2,j);
            res5 = str2double(num2str(round(results(1,2,j) / totalNR * 100), 3));
            disp(['NR-NL = ' num2str(res5) '% (' num2str(results(1,2,j)) '/' num2str(totalNR) ')']);
            res6 = str2double(num2str(round(results(2,2,j) / totalNR * 100), 3));
            disp(['NR-NR = ' num2str(res6) '% (' num2str(results(2,2,j)) '/' num2str(totalNR) ')']);
            res7 = str2double(num2str(round(results(3,2,j) / totalNR * 100), 3));
            disp(['NR-FL = ' num2str(res7) '% (' num2str(results(3,2,j)) '/' num2str(totalNR) ')']);
            res8 = str2double(num2str(round(results(4,2,j) / totalNR * 100), 3));
            disp(['NR-FR = ' num2str(res8) '% (' num2str(results(4,2,j)) '/' num2str(totalNR) ')']);
            disp('-----------')
            totalFL = sum(results(:,3,j));        
            observed(1,3,j) = results(3,3,j);
            observed(2,3,j) = totalFL - results(3,3,j);
            res9 = str2double(num2str(round(results(1,3,j) / totalFL * 100), 3));
            disp(['FL-NL = ' num2str(res9) '% (' num2str(results(1,3,j)) '/' num2str(totalFL) ')']);
            res10 = str2double(num2str(round(results(2,3,j) / totalFL * 100), 3));
            disp(['FL-NR = ' num2str(res10) '% (' num2str(results(2,3,j)) '/' num2str(totalFL) ')']);
            res11 = str2double(num2str(round(results(3,3,j) / totalFL * 100), 3));
            disp(['FL-FL = ' num2str(res11) '% (' num2str(results(3,3,j)) '/' num2str(totalFL) ')']);
            res12 = str2double(num2str(round(results(4,3,j) / totalFL * 100), 3));
            disp(['FL-FR = ' num2str(res12) '% (' num2str(results(4,3,j)) '/' num2str(totalFL) ')']);
            disp('-----------')
            totalFR = sum(results(:,4,j));
            observed(1,4,j) = results(4,4,j);
            observed(2,4,j) = totalFR - results(4,4,j);
            res13 = str2double(num2str(round(results(1,4,j) / totalFR * 100), 3));
            disp(['FR-NL = ' num2str(res13) '% (' num2str(results(1,4,j)) '/' num2str(totalFR) ')']);
            res14 = str2double(num2str(round(results(2,4,j) / totalFR * 100), 3));
            disp(['FR-NR = ' num2str(res14) '% (' num2str(results(2,4,j)) '/' num2str(totalFR) ')']);
            res15 = str2double(num2str(round(results(3,4,j) / totalFR * 100), 3));
            disp(['FR-FL = ' num2str(res15) '% (' num2str(results(3,4,j)) '/' num2str(totalFR) ')']);
            res16 = str2double(num2str(round(results(4,4,j) / totalFR * 100), 3));
            disp(['FR-FR = ' num2str(res16) '% (' num2str(results(4,4,j)) '/' num2str(totalFR) ')']);
            disp('-----------');
            disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
                  num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '/' ...
                  num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 3) '/' ...
                  num2str(round(results(4,4,j) / sum(results(:,4,j)) * 100), 3)]);
            disp('-----------');
            disp([num2str(round((results(1,1,j) + results(3,3,j)) / (sum(results(:,1,j)) + sum(results(:,3,j))) * 100), 3) '/' ...
                  num2str(round((results(2,2,j) + results(4,4,j)) / (sum(results(:,2,j)) + sum(results(:,4,j))) * 100), 3)]);
            disp('-----------');

            disp(results(:,:,j));
            disp(['Total 4-choice trials = ' num2str(sum(sum(sum(results))))]);
            disp('===========');
            
            graphPad = [graphPad res1 res2 res3 res4 res5 res6 res7 res8 res9 res10 res11 res12 res13 res14 res15 res16];
        end

        % If there were some extinction trials, print out results
        resultsExt = worldResults{worldIdx}{3};  % just a helper - these are the catch trials
        if (sum(sum(sum(resultsExt))) > 0)
            disp('///////4-CHOICE 2-TARGET TRIALS (EXTINCTION)///////');
            for j = 1:size(resultsExt,3)
                % Don't display results if none for this opto-type
                cnt = sum(sum(resultsExt(:,:,j)));
                if (cnt == 0)
                    continue;
                end
                if (j == 1) 
                    disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(resultsExt(:,:,j)));
                                
                res1 = str2double(num2str(round(resultsExt(1,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp(['NL-NL = ' num2str(res1) '% (' num2str(resultsExt(1,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                res2 = str2double(num2str(round(resultsExt(2,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp(['NL-NR = ' num2str(res2) '% (' num2str(resultsExt(2,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                res3 = str2double(num2str(round(resultsExt(3,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp(['NL-FL = ' num2str(res3) '% (' num2str(resultsExt(3,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                res4 = str2double(num2str(round(resultsExt(4,1,j) / sum(resultsExt(:,1,j)) * 100), 3));
                disp(['NL-FR = ' num2str(res4) '% (' num2str(resultsExt(4,1,j)) '/' num2str(sum(resultsExt(:,1,j))) ')']);
                disp('-----------')
                res5 = str2double(num2str(round(resultsExt(1,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp(['NR-NL = ' num2str(res5) '% (' num2str(resultsExt(1,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                res6 = str2double(num2str(round(resultsExt(2,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp(['NR-NR = ' num2str(res6) '% (' num2str(resultsExt(2,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                res7 = str2double(num2str(round(resultsExt(3,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp(['NR-FL = ' num2str(res7) '% (' num2str(resultsExt(3,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                res8 = str2double(num2str(round(resultsExt(4,2,j) / sum(resultsExt(:,2,j)) * 100), 3));
                disp(['NR-FR = ' num2str(res8) '% (' num2str(resultsExt(4,2,j)) '/' num2str(sum(resultsExt(:,2,j))) ')']);
                disp('-----------')
                graphPad = [graphPad res1 res2 res3 res4 res5 res6 res7 res8];
            end
        end
        
        results = worldResults{worldIdx}{2};  % just a helper - these are the catch trials
        if (sum(sum(sum(results))) > 0)
            disp('///////4-CHOICE CATCH///////');
            for j = 1:size(results,3)
                expectedFrac = zeros(1,4);
                % Don't display results if none for this opto-type
                cnt = sum(results);
                if (cnt(j) == 0)
                    continue;
                end
                if (j == 1) 
                    disp('=====Non-Opto======')
                elseif (j == 2)
                    disp('=====Opto Left======')
                elseif (j == 3)
                    disp('=====Opto Right======')
                elseif (j == 4)
                    disp('=====Opto Both======')
                end
                numTrials = sum(sum(results(:,:,j)));
                expectedFrac(1) = results(1,1,j) / sum(results(:,1,j));
                expectedFrac(2) = results(2,1,j) / sum(results(:,1,j));
                expectedFrac(3) = results(3,1,j) / sum(results(:,1,j));
                expectedFrac(4) = results(4,1,j) / sum(results(:,1,j));

                res1 = str2double(num2str(round(expectedFrac(1) * 100), 3));
                disp(['NEAR LEFT BIAS = ' num2str(res1) '% (' num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                res2 = str2double(num2str(round(expectedFrac(2) * 100), 3));
                disp(['NEAR RIGHT BIAS = ' num2str(res2) '% (' num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                res3 = str2double(num2str(round(expectedFrac(3) * 100), 3));
                disp(['FAR LEFT BIAS = ' num2str(res3) '% (' num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);            
                res4 = str2double(num2str(round(expectedFrac(4) * 100), 3));
                disp(['FAR RIGHT BIAS = ' num2str(res4) '% (' num2str(results(4,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
                disp('-----------')
                
                % Do chi-squared test, adjusted for the sight rate!  Assumes right blindness for now
                expected = zeros(2,4);  % First row is correct, second row is incorrect
                expected(1,1) = expectedFrac(1) * ((1-sightRate) * (observed(1,1,j) + observed(2,1,j)));
                expected(2,1) = (1 - expectedFrac(1)) * ((1-sightRate) * (observed(1,1,j) + observed(2,1,j)));
                expected(1,2) = expectedFrac(2) * ((1-sightRate) * (observed(1,2,j) + observed(2,2,j)));
                expected(2,2) = (1 - expectedFrac(2)) * ((1-sightRate) * (observed(1,2,j) + observed(2,2,j)));
                expected(1,3) = expectedFrac(3) * ((1-sightRate) *(observed(1,3,j) + observed(2,3,j)));
                expected(2,3) = (1 - expectedFrac(3)) * ((1-sightRate) * (observed(1,3,j) + observed(2,3,j)));
                expected(1,4) = expectedFrac(4) * ((1-sightRate) * (observed(1,4,j) + observed(2,4,j)));
                expected(2,4) = (1 - expectedFrac(4)) * ((1-sightRate) * (observed(1,4,j) + observed(2,4,j)));
                
                % Print pooled expected values
                observedLeftCorrect = observed(1,1,j) + observed(1,3,j);
                expectedLeftCorrect = expected(1,1) + expected(1,3) + sightRate * (totalNL + totalFL);
                totalLeft = totalNL + totalFL;
                %if (observedLeftCorrect - expectedLeftCorrect >= 0)
                    normLeftSightRate = (observedLeftCorrect - expectedLeftCorrect) / (totalLeft - expectedLeftCorrect);
                %else
                %    normLeftSightRate = (observedLeftCorrect - expectedLeftCorrect) / expectedLeftCorrect;
                %end
                disp(['Expected left correct by chance = ' num2str(expectedLeftCorrect)])
                disp(['Observed left correct = ' num2str(observedLeftCorrect)]);
                disp(['Chi-squared p = ' num2str(chisquared(observed(1,1,j) + observed(1,3,j), expectedLeftCorrect, ...
                                            observed(2,1,j) + observed(2,3,j), expected(2,1) + expected(2,3)))]);
                disp(['Normalized L sight rate = ' num2str(normLeftSightRate)]);
                disp('---------------');

                observedRightCorrect = observed(1,2,j) + observed(1,4,j);
                expectedRightCorrect = sightRate * (totalNR + totalFR) + expected(1,2) + expected(1,4);
                totalRight = totalNR + totalFR;
                %if (observedRightCorrect - expectedRightCorrect >= 0)
                    normRightSightRate = (observedRightCorrect - expectedRightCorrect) / (totalRight - expectedRightCorrect);
                %else
                %    normRightSightRate = (observedRightCorrect - expectedRightCorrect) / expectedRightCorrect;
                %end
                disp(['Expected right correct by chance = ' num2str(expectedRightCorrect)])
                disp(['Observed right correct = ' num2str(observedRightCorrect)]);
                disp(['Chi-squared p = ' num2str(chisquared(observed(1,2,j) + observed(1,4,j), expectedRightCorrect, ...
                                            observed(2,2,j) + observed(2,4,j), expected(2,2) + expected(2,4)))]);
                disp(['Normalized R sight rate = ' num2str(normRightSightRate)]);
                disp('---------------');
                disp('================')
                
                graphPad = [graphPad res1 res2 res3 res4];
            end
        end     
        
        disp(graphPad);

    end
end

% If there are disc trials, print the results
if (sum(sum(sum(results_disc))) > 0)
    disp('///////2AFC DISCRIMINATION///////');
    results = results_disc;  % just a helper
    for j = 1:size(results,3)
        % Don't display results if none for this opto-type
        cnt = sum(sum(results));
        if (cnt(j) == 0)
            continue;
        end
        if (j == 1) 
            disp('=====Non-Opto======')
        elseif (j == 2)
            disp('=====Opto Left======')
        elseif (j == 3)
            disp('=====Opto Right======')
        elseif (j == 4)
            disp('=====Opto Both======')
        end
        numCorrect = results(1,1,j)+results(2,2,j);
        numTrials = sum(sum(results(:,:,j)));
        disp(['OVERALL ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);
        disp(['LEFT ACCURACY = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['RIGHT ACCURACY = ' num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp('-----------')
        disp([num2str(numCorrect/numTrials * 100, 2) ' // ' ...
              num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3)]);        
        disp('-----------')
        disp(['hit rate = '  num2str(round(results(1,1,j) / sum(results(:,1,j)), 2)*100) '%']);
        disp(['false alarm rate = ' num2str(round(results(1,2,j) / sum(results(:,2,j)), 2)*100) '%']);
        disp(['d'' = ' num2str(round(1/sqrt(2) * (norminv(results(1,1,j) / sum(results(:,1,j))) - norminv(results(1,2,j) / sum(results(:,2,j)))), 2))]);
        disp('-----------')
    end
end

disp(['Expected ' num2str(length(days)) ' files.']);
disp(['Analyzed ' num2str(numFilesAnalyzed) ' files.']);
if (length(days) ~= numFilesAnalyzed)
    beep
    disp(['Some data files MISSING?!']);
else
    disp (['ALL GOOD']);
end

end