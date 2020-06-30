function getStats(loc, mouseName, days, sessions, includeCorrectionTrials, analyzeCensored)
% This function will analyze the relevant actions.txt log files and return
% a set of statistics useful to analyzing blindness and blindsight, as well
% as a 2AFC stimulus discrimination task.
%
% It supports 2-choice levels, 3-choice levels, 4-choice levels, and mixed levels for blindness/blindsight.  The
% world-type is determined by the filename, though in the future it should be embedded in the trial record itself.
%
% It also supports 2 alternative forced choice (2AFC) for visual discrimination. It calculates accuracy as well as d' for these experiments. 
%
% It also supports a separate category of catch trials, looking for the catch entry for a trial to be true, or -1,-1,-1 stim location.

actionsFolderUCB = 'C:\Users\nikhi\UCB\data-actions\';
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
zCutoff = 20050;  % Used to separate front from rear stimuli in the one-sided 2AFC

% Results are stored for each world separately, and each cell contains a cell which has arrays for 2-, 3- or 4-choice
% For 2-, 3- and 4-choice, there are results and results_catch matrices.
% For 3-choice, there is also a results_extinction matrix.
% Each 2-d array in the matrix is duplicated for non-opto, optoL, optoR and optoBoth.
% Columns are stim locations, rows are actions.
world_results = {};
world_type = [];  % this keeps track of whether the world is 2-, 3- or 4-choice.

results_2choice = zeros(2,2,4);
results_2choice_catch = zeros(2,1,4);  % No target presented in these results for "catch" trials
results_3choice = zeros(3,3,4);
results_3choice_catch = zeros(3,1,4);
results_3choice_extinction = zeros(3,3,4);
results_4choice = zeros(4,4,4);
results_4choice_catch = zeros(4,1,4);

results_disc = zeros(2,2,4);
results_disc_catch = zeros(2,2,4);

% For 3-choice perimetry, which was too difficult for the mice to learn so I no longer use it.  This analysis script still supports it.
leftStimStraightErrorsMap = containers.Map();
rightStimStraightErrorsMap = containers.Map();

% First, find all the filenames to read in
if (loc == 'UCB')
    actionsFolder = actionsFolderUCB;
else
    actionsFolder = actionsFolderUCSF;
end

if analyzeCensored
    fileList = dir([actionsFolder '*actions_censored.txt']);
else
    fileList = dir([actionsFolder '*actions.txt']); % Get all mat files, and use that to construct filenames for video files
end

numFilesAnalyzed = 0;
for i=1:length(fileList)
    for j=1:length(days)
        if (contains(fileList(i).name, [mouseName '-D' num2str(days(j))]))
            matchesSession = false;
            if isempty(sessions)
                matchesSession = true;
            else
                for m=1:length(sessions)
                    if (contains(fileList(i).name, ['-S' num2str(sessions(m))]))
                        matchesSession = true;
                    end
                end
            end
            if (matchesSession)
                fid = fopen([fileList(i).folder '\' fileList(i).name]);
                if (fid ~= -1)  % File was opened properly
                    numFilesAnalyzed = numFilesAnalyzed + 1;
                    tline = fgetl(fid); % Throw out the first line, as it is a column header
                    % C is a cell array with each string separated by a space
                    C = textscan(fid, getActionLineFormat()); 
                    levels = zeros(2,1);  % Currently support just 2 levels per world
                    strs = split(fileList(i).name, '-');  % Example filename: Waldo-D100-3_BG_Bl_R_10-S5_actions
                    % Take the 3rd string, and split by underscores to find the number of choices.
                    % In the future, record the level type in the actions file itself at the top.
                    level_parts = split(strs{3}, '_');
                    if(~isnan(str2double(level_parts{1}(1))))
                        levels(1) = str2double(level_parts{1}(1));
                        if (~isnan(str2double(level_parts{2}(1))))
                            levels(2) = str2double(level_parts{2}(1));
                        end
                    end
                    for k = 1:length(C{1})  % For each trial
                        [stimLocX, ~] = getStimLocFromActions(C, k);
                        [actionLocX, ~] = getActionLocFromActions(C, k);
                        optoLoc = getOptoLocFromActions(C, k);
                        worldNum = getWorldNumFromActions(C, k);
                        isCorrectionTrial = getCorrectionFromActions(C, k);
                        
                        if (isCorrectionTrial && ~includeCorrectionTrials)
                            continue;
                        end
                        
                        currCatch = 0;
                        
                        isExtinctionTrial = getExtinctionFromActions(C, k);
                        
                        if (levels(worldNum+1) == 2)
                            trialType = 2;
                            if (stimLocX == nearLeftX)
                                col = 1;
                            elseif (stimLocX == farLeftX)
                                col = 2;
                            elseif (stimLocX == nearRightX)
                                % Hack that assumes that on 2H levels, R
                                % level always comes second
                                if (length(levels) == 1)  % Assumes no 2R-only levels
                                    col = 2;
                                elseif (length(levels) == 2 && worldNum == 0)
                                    col = 2;
                                elseif (length(levels) == 2 && worldNum == 1)
                                    col = 1;
                                end
                            elseif (stimLocX == farRightX)
                                col = 2;
                            else % Catch trials!
                                currCatch = 1;
                            end
                            
                            if (actionLocX == nearLeftX)
                                row = 1;
                            elseif (actionLocX == farLeftX)
                                row = 2;
                            elseif (actionLocX == nearRightX)
                                % Hack that assumes that on 2H levels, R
                                % level always comes second
                                if (length(levels) == 1)  % Assumes no 2R-only levels
                                    row = 2;
                                elseif (length(levels) == 2 && worldNum == 0)
                                    row = 2;
                                elseif (length(levels) == 2 && worldNum == 1)
                                    row = 1;
                                end
                            elseif (actionLocX == farRightX)
                                row = 2;
                            else
                                disp('action does not match an expected target location');
                            end
                            
                            if (~currCatch)
                                results_2choice(row, col, optoLoc + 2) = results_2choice(row, col, optoLoc + 2) + 1;
                            else
                                results_2choice_catch(row, 1, optoLoc + 2) = results_2choice_catch(row, 1, optoLoc + 2) + 1;
                            end
                        elseif (levels(worldNum+1) == 3) 
                            trialType = 3;
                            if (stimLocX == nearLeftX)
                                col = 1;
                            elseif (stimLocX == nearRightX)
                                col = 2;
                            elseif (stimLocX == centerX)
                                col = 3;
                            else
                                currCatch = 1;
                            end

                            if (actionLocX == nearLeftX)
                                row = 1;
                            elseif (actionLocX == nearRightX)
                                row = 2;
                            elseif (actionLocX == centerX)
                                row = 3;
                            else
                                disp('action does not match an expected target location');
                            end
                                                        
                            % Put trials in correct sheet
                            if (currCatch)
                                results_3choice_catch(row, 1, optoLoc + 2) = results_3choice_catch(row, 1, optoLoc + 2) + 1;
                            elseif (isExtinctionTrial)
                                results_3choice_extinction(row, col, optoLoc + 2) = results_3choice_extinction(row, col, optoLoc + 2) + 1;
                            else
                                results_3choice(row, col, optoLoc + 2) = results_3choice(row, col, optoLoc + 2) + 1;
                            end
                        elseif (levels(worldNum+1) == 4)
                            trialType = 4;
                            if (stimLocX == nearLeftXDiag)
                                col = 1;
                            elseif (stimLocX == nearRightXDiag)
                                col = 2;
                            elseif (stimLocX == farLeftXDiag)
                                col = 3;
                            elseif (stimLocX == farRightXDiag)
                                col = 4;
                            else
                                currCatch = 1;
                            end

                            if (actionLocX == nearLeftXDiag)
                                row = 1;
                            elseif (actionLocX == nearRightXDiag)
                                row = 2;
                            elseif (actionLocX == farLeftXDiag)
                                row = 3;
                            elseif (actionLocX == farRightXDiag)
                                row = 4;
                            else
                                disp('action does not match an expected target location');
                            end
                            
                            % Put trials in correct sheet
                            if (~currCatch)
                                results_4choice(row, col, optoLoc + 2) = results_4choice(row, col, optoLoc + 2) + 1;
                            else
                                results_4choice_catch(row, 1, optoLoc + 2) = results_4choice_catch(row, 1, optoLoc + 2) + 1;
                            end
                        elseif (stimLocX == discLeftX || stimLocX == discRightX)
                            trialType = 2;
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

                        % The following analysis only applies to the
                        % 3-choice task - Not quite sure if this is
                        % relevant any more.
                        if (trialType == 3 && col ~= row)  % error trial
                            nasal = C{8}(k);
                            temporal = C{9}(k);
                            high = C{10}(k);
                            low = C{11}(k);
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

% If there are 2-choice trials, print the results
if (sum(sum(sum(results_2choice))) > 0)
    disp('///////2-CHOICE///////');
    results = results_2choice;  % just a helper

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
        disp(['L->L = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['L->R = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp('-----------')
        disp(['R->L = ' num2str(round(results(1,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(1,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp(['R->R = ' num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp('-----------')
        disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3)]);        
        disp('-----------')
        %disp(results(:,:,j));
        %disp('===========')
    end

    if (sum(sum(sum(results_2choice_catch))) > 0)
        disp('///////2-CHOICE CATCH///////');
        results = results_2choice_catch;
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
            disp(['LEFT BIAS = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['RIGHT BIAS = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp('-----------')
        end
    end
end

% If there are 3-choice trials, print the results
if (sum(sum(sum(results_3choice))) > 0)
    disp('///////3-CHOICE///////');
    results = results_3choice;  % just a helper
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
        numCorrect = results(1,1,j)+results(2,2,j)+results(3,3,j);
        numTrials = sum(sum(results(:,:,j)));
        disp(['ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);
        disp(['L->L = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['L->R = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['L->C = ' num2str(round(results(3,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
            num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp('-----------')
        disp(['R->L = ' num2str(round(results(1,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(1,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp(['R->R = ' num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp(['R->C = ' num2str(round(results(3,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
            num2str(results(3,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp('-----------')
        disp(['C->L = ' num2str(round(results(1,3,j) / sum(results(:,3,j)) * 100), 3) '% (' ...
            num2str(results(1,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        disp(['C->R = ' num2str(round(results(2,3,j) / sum(results(:,3,j)) * 100), 3) '% (' ...
            num2str(results(2,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        disp(['C->C = ' num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 3) '% (' ...
            num2str(results(3,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        disp('-----------')
        disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '/' ...
              num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 3)]);        
        disp('-----------')
        %disp(results(:,:,j));
        %disp('===========')
    end
    
    disp([num2str(round(results(3,2,2) / sum(results(:,2,2)) * 100), 3) '/' ...
          num2str(round(results(3,1,3) / sum(results(:,1,3)) * 100), 3) ' BLIND (opto)']);

    if (sum(sum(sum(results_3choice_catch))) > 0)
        disp('///////3-CHOICE CATCH///////');
        results = results_3choice_catch;
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
            disp(['LEFT BIAS = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['RIGHT BIAS = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['CENTER BIAS = ' num2str(round(results(3,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);            
            disp('-----------')
        end
    end

    % If there were some extinction trials, print out results
    if (sum(sum(sum(results_3choice_extinction))) > 0)
        disp('///////3-CHOICE UNILATERAL EXTINCTION///////');
        results = results_3choice_extinction;
        for j = 1:size(results,3)
            % Don't display results if none for this opto-type
            cnt = sum(sum(results(:,:,j)));
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
            numTrials = sum(sum(results(:,:,j)));
            disp(['LE->L = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                             num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['LE->R = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                             num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['LE->C = ' num2str(round(results(3,1,j) / sum(results(:,1,j)) * 100), 3) '% (' ...
                             num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp('-----------')
            disp(['RE->L = ' num2str(round(results(1,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
                             num2str(results(1,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
            disp(['RE->R = ' num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
                             num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
            disp(['RE->C = ' num2str(round(results(3,2,j) / sum(results(:,2,j)) * 100), 3) '% (' ...
                             num2str(results(3,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
            disp('-----------')
        end
    end

end

% If there are 4-choice trials, print the results
if (sum(sum(sum(results_4choice))) > 0)
    disp('///////4-CHOICE///////');
    results = results_4choice;  % just a helper
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
        disp('======RAW======');
        disp(['ACCURACY = ' num2str(numCorrect/numTrials * 100, 2) '%']);
        sr = sum(results(:,1,j));
        observed(1,1,j) = results(1,1,j);
        observed(2,1,j) = sr - results(1,1,j);
        disp(['NL->NL = ' num2str(round(results(1,1,j) / sr * 100), 3) '% (' num2str(results(1,1,j)) '/' num2str(sr) ')']);
        disp(['NL->NR = ' num2str(round(results(2,1,j) / sr * 100), 3) '% (' num2str(results(2,1,j)) '/' num2str(sr) ')']);
        disp(['NL->FL = ' num2str(round(results(3,1,j) / sr * 100), 3) '% (' num2str(results(3,1,j)) '/' num2str(sr) ')']);
        disp(['NL->FR = ' num2str(round(results(4,1,j) / sr * 100), 3) '% (' num2str(results(4,1,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,2,j));
        observed(1,2,j) = results(2,2,j);
        observed(2,2,j) = sr - results(2,2,j);
        disp(['NR->NL = ' num2str(round(results(1,2,j) / sr * 100), 3) '% (' num2str(results(1,2,j)) '/' num2str(sr) ')']);
        disp(['NR->NR = ' num2str(round(results(2,2,j) / sr * 100), 3) '% (' num2str(results(2,2,j)) '/' num2str(sr) ')']);
        disp(['NR->FL = ' num2str(round(results(3,2,j) / sr * 100), 3) '% (' num2str(results(3,2,j)) '/' num2str(sr) ')']);
        disp(['NR->FR = ' num2str(round(results(4,2,j) / sr * 100), 3) '% (' num2str(results(4,2,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,3,j));        
        observed(1,3,j) = results(2,2,j);
        observed(2,3,j) = sr - results(2,2,j);
        disp(['FL->NL = ' num2str(round(results(1,3,j) / sr * 100), 3) '% (' num2str(results(1,3,j)) '/' num2str(sr) ')']);
        disp(['FL->NR = ' num2str(round(results(2,3,j) / sr * 100), 3) '% (' num2str(results(2,3,j)) '/' num2str(sr) ')']);
        disp(['FL->FL = ' num2str(round(results(3,3,j) / sr * 100), 3) '% (' num2str(results(3,3,j)) '/' num2str(sr) ')']);
        disp(['FL->FR = ' num2str(round(results(4,3,j) / sr * 100), 3) '% (' num2str(results(4,3,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,4,j));
        observed(1,4,j) = results(4,4,j);
        observed(2,4,j) = sr - results(4,4,j);
        disp(['FR->NL = ' num2str(round(results(1,4,j) / sr * 100), 3) '% (' num2str(results(1,4,j)) '/' num2str(sr) ')']);
        disp(['FR->NR = ' num2str(round(results(2,4,j) / sr * 100), 3) '% (' num2str(results(2,4,j)) '/' num2str(sr) ')']);
        disp(['FR->FL = ' num2str(round(results(3,4,j) / sr * 100), 3) '% (' num2str(results(3,4,j)) '/' num2str(sr) ')']);
        disp(['FR->FR = ' num2str(round(results(4,4,j) / sr * 100), 3) '% (' num2str(results(4,4,j)) '/' num2str(sr) ')']);        
        disp('-----------');
        disp([num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 3) '/' ...
              num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 3) '/' ...
              num2str(round(results(4,4,j) / sum(results(:,4,j)) * 100), 3)]);
        disp('-----------');
        %{
        disp('===ADJUSTED===');
        denom = results(1,1,j) + results(3,1,j);
        disp(['NL->NL = ' num2str(round(results(1,1,j) / denom * 100), 3) '% (' num2str(results(1,1,j)) '/' num2str(denom) ')']);
        disp(['NL->FL = ' num2str(round(results(3,1,j) / denom * 100), 3) '% (' num2str(results(3,1,j)) '/' num2str(denom) ')']);
        disp(['KEPT = ' num2str(round(((results(1,1,j) + results(3,1,j)) / sum(results(:,1,j))) * 100, 0)) '% ']);
        disp('-----------')
        denom = results(2,2,j) + results(4,2,j);
        disp(['NR->NR = ' num2str(round(results(2,2,j) / denom * 100), 3) '% (' num2str(results(2,2,j)) '/' num2str(denom) ')']);
        disp(['NR->FR = ' num2str(round(results(4,2,j) / denom * 100), 3) '% (' num2str(results(4,2,j)) '/' num2str(denom) ')']);
        disp(['KEPT = ' num2str(round(((results(2,2,j) + results(4,2,j)) / sum(results(:,2,j))) * 100, 0)) '% ']);
        disp('-----------')
        denom = results(1,3,j) + results(3,3,j);
        disp(['FL->NL = ' num2str(round(results(1,3,j) / denom * 100), 3) '% (' num2str(results(1,3,j)) '/' num2str(denom) ')']);
        disp(['FL->FL = ' num2str(round(results(3,3,j) / denom * 100), 3) '% (' num2str(results(3,3,j)) '/' num2str(denom) ')']);
        disp(['KEPT = ' num2str(round(((results(1,3,j) + results(3,3,j)) / sum(results(:,3,j))) * 100, 0)) '% ']);
        disp('-----------')
        denom = results(2,4,j) + results(4,4,j);
        disp(['FR->NR = ' num2str(round(results(2,4,j) / denom * 100), 3) '% (' num2str(results(2,4,j)) '/' num2str(denom) ')']);
        disp(['FR->FR = ' num2str(round(results(4,4,j) / denom * 100), 3) '% (' num2str(results(4,4,j)) '/' num2str(denom) ')']);        
        disp(['KEPT = ' num2str(round(((results(2,4,j) + results(4,4,j)) / sum(results(:,4,j))) * 100, 0)) '% ']);
        disp('-----------');
        disp([num2str(round(results(1,1,j) / (results(1,1,j) + results(3,1,j)) * 100), 3) '/' ...
              num2str(round(results(2,2,j) / (results(2,2,j) + results(4,2,j)) * 100), 3) '/' ...
              num2str(round(results(3,3,j) / (results(1,3,j) + results(3,3,j)) * 100), 3) '/' ...
              num2str(round(results(4,4,j) / (results(2,4,j) + results(4,4,j)) * 100), 3)]);
        disp('-----------');
        %}
        
        disp(results(:,:,j));
        disp(['Total 4-choice trials = ' num2str(sum(sum(sum(results))))]);
        disp('===========');
    end
    
    if (sum(sum(sum(results_4choice_catch))) > 0)
        disp('///////4-CHOICE CATCH///////');
        results = results_4choice_catch;
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
            
            disp(['NEAR LEFT BIAS = ' num2str(round(expectedFrac(1) * 100), 3) '% (' ...
                num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['NEAR RIGHT BIAS = ' num2str(round(expectedFrac(2) * 100), 3) '% (' ...
                num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp(['FAR LEFT BIAS = ' num2str(round(expectedFrac(3) * 100), 3) '% (' ...
                num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);            
            disp(['FAR RIGHT BIAS = ' num2str(round(expectedFrac(4) * 100), 3) '% (' ...
                num2str(results(4,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
            disp('-----------')
            disp('Chi-squared p values:');
            % Do chi-squared test
            expected = zeros(2,4);  % First row is correct, second row is incorrect
            expected(1,1) = expectedFrac(1) * (observed(1,1,j) + observed(2,1,j));
            expected(2,1) = (1 - expectedFrac(1)) * (observed(1,1,j) + observed(2,1,j));
            expected(1,2) = expectedFrac(2) * (observed(1,2,j) + observed(2,2,j));
            expected(2,2) = (1 - expectedFrac(2)) * (observed(1,2,j) + observed(2,2,j));
            expected(1,3) = expectedFrac(3) * (observed(1,3,j) + observed(2,3,j));
            expected(2,3) = (1 - expectedFrac(3)) * (observed(1,3,j) + observed(2,3,j));
            expected(1,4) = expectedFrac(4) * (observed(1,4,j) + observed(2,4,j));
            expected(2,4) = (1 - expectedFrac(4)) * (observed(1,4,j) + observed(2,4,j));
            
            disp(['NEAR LEFT = ' num2str(chisquared(observed(1,1,j), expected(1,1), observed(2,1,j), expected(2,1)))]);
            disp(['NEAR RIGHT = ' num2str(chisquared(observed(1,2,j), expected(1,2), observed(2,2,j), expected(2,2)))]);
            disp(['FAR LEFT = ' num2str(chisquared(observed(1,3,j), expected(1,3), observed(2,3,j), expected(2,3)))]);
            disp(['FAR RIGHT = ' num2str(chisquared(observed(1,4,j), expected(1,4), observed(2,4,j), expected(2,4)))]);
            disp(['LEFT POOLED = ' num2str(chisquared(observed(1,1,j) + observed(1,3,j), expected(1,1) + expected(1,3), ...
                                        observed(2,1,j) + observed(2,3,j), expected(2,1) + expected(2,3)))]);
            disp(['RIGHT POOLED = ' num2str(chisquared(observed(1,2,j) + observed(1,4,j), expected(1,2) + expected(1,4), ...
                                        observed(2,2,j) + observed(2,4,j), expected(2,2) + expected(2,4)))]);
            disp('================')
        end
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

disp(['Analyzed ' num2str(numFilesAnalyzed) ' files.']);

end