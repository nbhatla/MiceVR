function getStats(mouseName, days, sessions, includeCorrectionTrials)
% This function will analyze the relevant actions.txt log files and return
% a set of statistics useful to analyzing blindness and blindsight.
%
% It supports 3-choice levels, 4-choice levels, and mixed levels.  The
% world-type is determined by the x-coord of the target, which hopefully
% won't change as worlds are modified at this point.  Alternatively, I
% could parse the filename - but do this for now.

% X locs of 3-chioce and 4-choice worlds
leftX = 19975;
centerX = 20000;
rightX = 20025;

nearLeftX = 19973;
farLeftX = 19972;
nearRightX = 20027;
farRightX = 20028;

% first column is all Left stim trials
% second column is all Right stim trials
% third column is all Center stim trials

% first row is all Left action trials
% second row is all Right action trials
% third row is all Center action trials

results_3choice = zeros(3,3,4);  % First is non-opto, second is optoL, third is optoR, and fourth is optoBoth - sum to get all
results_4choice = zeros(4,4,4);

% Only supports 3-choice perimetry, which was too difficult for the mice so I no longer do
leftStimStraightErrorsMap = containers.Map();
rightStimStraightErrorsMap = containers.Map();

% First, find all the filenames to read in
fileList = dir(['*actions.txt']); % Get all mat files, and use that to construct filenames for video files

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
                    C = textscan(fid, '%s %s %d %s %s %d %d %d %d %d %d %s %d %d %f %d %d %d %d %d %d'); 
                    for k = 1:length(C{1})  % For each line
                        % C{5} is the target location, C{12} is the turn location
                        if (iscell(C{5}(k)))
                            tmp = strsplit(C{5}{k}, ';');
                            stimLocX = str2double(tmp{1});
                        else
                            stimLocX = str2double(C{5}(k));
                        end
                        if (iscell(C{12}(k)))
                            tmp = strsplit(C{12}{k}, ';');
                            actionLocX = str2double(tmp{1});
                        else 
                            actionLocX = str2double(C{12}(k));
                        end
                        optoLoc = C{17}(k);
                        
                        isCorrectionTrial = C{21}(k);
                        if (isCorrectionTrial && ~includeCorrectionTrials)
                            continue;
                        end

                        % Figure out if it is 3-choice or 4-choice world for this trial
                        if (stimLocX == leftX || stimLocX == rightX || stimLocX == centerX)
                            trialType = 3;
                            if (stimLocX < centerX)
                                col = 1;
                            elseif (stimLocX > centerX)
                                col = 2;
                            elseif (stimLocX == centerX)
                                col = 3;
                            end

                            if (actionLocX < centerX)
                                row = 1;
                            elseif (actionLocX > centerX)
                                row = 2;
                            elseif (actionLocX == centerX)
                                row = 3;
                            end
                            
                            % Put trials in correct sheet
                            results_3choice(row, col, optoLoc + 2) = results_3choice(row, col, optoLoc + 2) + 1;
                        elseif (stimLocX == nearLeftX || stimLocX == farLeftX || stimLocX == nearRightX || stimLocX == farRightX)
                            trialType = 4;
                            if (stimLocX == nearLeftX)
                                col = 1;
                            elseif (stimLocX == nearRightX)
                                col = 2;
                            elseif (stimLocX == farLeftX)
                                col = 3;
                            elseif (stimLocX == farRightX)
                                col = 4;
                            end

                            if (actionLocX == nearLeftX)
                                row = 1;
                            elseif (actionLocX == nearRightX)
                                row = 2;
                            elseif (actionLocX == farLeftX)
                                row = 3;
                            elseif (actionLocX == farRightX)
                                row = 4;
                            end
                            
                            % Put trials in correct sheet
                            results_4choice(row, col, optoLoc + 2) = results_4choice(row, col, optoLoc + 2) + 1;
                        end

                        % The following analysis only applies to the 3-chioce task
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
        disp(['L->L = ' num2str(round(results(1,1,j) / sum(results(:,1,j)) * 100), 2) '% (' ...
            num2str(results(1,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['L->R = ' num2str(round(results(2,1,j) / sum(results(:,1,j)) * 100), 2) '% (' ...
            num2str(results(2,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp(['L->C = ' num2str(round(results(3,1,j) / sum(results(:,1,j)) * 100), 2) '% (' ...
            num2str(results(3,1,j)) '/' num2str(sum(results(:,1,j))) ')']);
        disp('-----------')
        disp(['R->L = ' num2str(round(results(1,2,j) / sum(results(:,2,j)) * 100), 2) '% (' ...
            num2str(results(1,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp(['R->R = ' num2str(round(results(2,2,j) / sum(results(:,2,j)) * 100), 2) '% (' ...
            num2str(results(2,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp(['R->C = ' num2str(round(results(3,2,j) / sum(results(:,2,j)) * 100), 2) '% (' ...
            num2str(results(3,2,j)) '/' num2str(sum(results(:,2,j))) ')']);
        disp('-----------')
        disp(['C->L = ' num2str(round(results(1,3,j) / sum(results(:,3,j)) * 100), 2) '% (' ...
            num2str(results(1,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        disp(['C->R = ' num2str(round(results(2,3,j) / sum(results(:,3,j)) * 100), 2) '% (' ...
            num2str(results(2,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        disp(['C->C = ' num2str(round(results(3,3,j) / sum(results(:,3,j)) * 100), 2) '% (' ...
            num2str(results(3,3,j)) '/' num2str(sum(results(:,3,j))) ')']);
        %disp('-----------')
        %disp(results(:,:,j));
        disp('===========')
    end
    
    %disp('Stim on left, but mouse goes straight:');
    %disp(keys(leftStimStraightErrorsMap));
    %disp(values(leftStimStraightErrorsMap));

    %disp('Stim on right, but mouse goes straight:');
    %disp(keys(rightStimStraightErrorsMap));
    %disp(values(rightStimStraightErrorsMap));
end

% If there are 4-choice trials, print the results
if (sum(sum(sum(results_4choice))) > 0)
    disp('///////4-CHOICE///////');
    results = results_4choice;  % just a helper
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
        sr = sum(results(:,1,j));
        disp(['NL->NL = ' num2str(round(results(1,1,j) / sr * 100), 2) '% (' ...
            num2str(results(1,1,j)) '/' num2str(sr) ')']);
        disp(['NL->NR = ' num2str(round(results(2,1,j) / sr * 100), 2) '% (' ...
            num2str(results(2,1,j)) '/' num2str(sr) ')']);
        disp(['NL->FL = ' num2str(round(results(3,1,j) / sr * 100), 2) '% (' ...
            num2str(results(3,1,j)) '/' num2str(sr) ')']);
        disp(['NL->FR = ' num2str(round(results(4,1,j) / sr * 100), 2) '% (' ...
            num2str(results(4,1,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,2,j));        
        disp(['NR->NL = ' num2str(round(results(1,2,j) / sr * 100), 2) '% (' ...
            num2str(results(1,2,j)) '/' num2str(sr) ')']);
        disp(['NR->NR = ' num2str(round(results(2,2,j) / sr * 100), 2) '% (' ...
            num2str(results(2,2,j)) '/' num2str(sr) ')']);
        disp(['NR->FL = ' num2str(round(results(3,2,j) / sr * 100), 2) '% (' ...
            num2str(results(3,2,j)) '/' num2str(sr) ')']);
        disp(['NR->FR = ' num2str(round(results(4,2,j) / sr * 100), 2) '% (' ...
            num2str(results(4,2,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,3,j));        
        disp(['FL->NL = ' num2str(round(results(1,3,j) / sr * 100), 2) '% (' ...
            num2str(results(1,3,j)) '/' num2str(sr) ')']);
        disp(['FL->NR = ' num2str(round(results(2,3,j) / sr * 100), 2) '% (' ...
            num2str(results(2,3,j)) '/' num2str(sr) ')']);
        disp(['FL->FL = ' num2str(round(results(3,3,j) / sr * 100), 2) '% (' ...
            num2str(results(3,3,j)) '/' num2str(sr) ')']);
        disp(['FL->FR = ' num2str(round(results(4,3,j) / sr * 100), 2) '% (' ...
            num2str(results(4,3,j)) '/' num2str(sr) ')']);
        disp('-----------')
        sr = sum(results(:,4,j));        
        disp(['FR->NL = ' num2str(round(results(1,4,j) / sr * 100), 2) '% (' ...
            num2str(results(1,4,j)) '/' num2str(sr) ')']);
        disp(['FR->NR = ' num2str(round(results(2,4,j) / sr * 100), 2) '% (' ...
            num2str(results(2,4,j)) '/' num2str(sr) ')']);
        disp(['FR->FL = ' num2str(round(results(3,4,j) / sr * 100), 2) '% (' ...
            num2str(results(3,4,j)) '/' num2str(sr) ')']);
        disp(['FR->FR = ' num2str(round(results(4,4,j) / sr * 100), 2) '% (' ...
            num2str(results(4,4,j)) '/' num2str(sr) ')']);        
        disp('-----------')
        disp(results(:,:,j));
        disp('===========')
    end
end

disp(['Analyzed ' num2str(numFilesAnalyzed) ' files.']);

end