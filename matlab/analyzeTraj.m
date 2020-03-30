function f = analyzeTraj(mouseName, days, sessions, trials, trialTypeStrArr, includeCorrectionTrials, drawOneFig, markSize, markAlpha, lastTrial)
% SAMPLE USAGE
% // MANY TRacks on one plot
% > analyzeTraj('Vixen', [43], [], [], ["L->L" "R->R" "C->C"], 0, 1, 1, 0.02, 0)
% // EACH TRIAL on a separate plot
% > analyzeTraj('Dragon', [182], [], [], [], 1, 0, 8, 0.06, 0)
%
% This function takes as input a mouse's name as well as the days and
% corresponding sessions that should be analyzed.  It then looks in the
% replay directory (hard-coded - change if it is somewhere else on your
% machine) to find the corresponding mouse position and heading files.  By
% reading the replay filename, the scenario can be extracted so the map can
% be drawn.  This is done by reading the scenario file in the scenarios 
% directory (again, hard-coded, so change to match on
% your machine) to extract the target and wall locations so that an
% appropriate map can be drawn.
%
% trialTypeStrArr specifies which trial types should be analyzed:
%   "*->*" - all targets, all actions
%   "R->*" - right target, all actions
%   "R->R" - right target, right action
%   "R->L" - right target, left action
%   "R->C" - right target, center action
%   "L->*" - left target, all actions
%   "L->L" - left target, left action
%   "L->R" - left target, right action
%   "L->C" - left target, center action
%   "C->*" - center target, all actions
%   "C->C" - center target, center action
%   "C->L" - center target, left action
%   "C->R" - center target, right action
%   "L->RC" - left target, center or right action (all incorrect on L trials)
%   "R->LC" - right target, center or left action (all incorrect on R trials)
%   "C->LR" - center target, left or right action (all incorrect on C trials)
%
% If trialTypeStrArr is specified (e.g. show only correct actions: ["L->L" "R->R" "S->S"],
% the program will also read the actions files for the corresponding
% day/session to determine which trial type it was and to only include
% those that map those asked for by the user.
%
% For each trajectory plot, a single trajectory is plotted as a grey line,
% with overlapping trajectories getting a bump in darkness.  Finally, a
% second plot is generated with just the mean trajectory for that trial
% type.
%
% Alternatively, we could plot each trajectory for a trial type as a single
% plot, with a mean plot plotted at the end
%
% Alternatively, this program could generate a video file with videos of
% the trajectories.
%
% I need to think about how to incorporate speed and heading in these plots.
% My instinct is to just ignore heading for now and just put arrows to
% indicate direction along the curve, ignoring speed as well.
% Alternatively, speed could be indicated by a thicker spot indicating a
% slower speed and a thinner spot indicating a faster speed.  Maybe I will
% get Tunlin's take on this as well.

%%% CHANGE THESE VARS FOR YOUR SETUP PRIOR TO RUNNING %%%
scenariosFolder = 'C:\Users\nikhi\Documents\GitHub\MiceVR\scenarios\';
actionsFolder = 'C:\Users\nikhi\UCB\data-actions\';
replaysFolder = 'C:\Users\nikhi\UCB\data-replays\';

% X locs of 2-choice, 3-chioce and 4-choice worlds
leftX = 19975;
centerX = 20000;
rightX = 20025;

leftNearX = 19973;
leftFarX = 19972;
rightNearX = 20027;
rightFarX = 20028;

catchX = -1;

wallColor = [0.85 0.85 0.85];
wallWidth = 20;

shadingColorLeft = [0.84 0.89 0.99];  % dull blue
shadingColorLeftFar = [0.84 0.98 0.99]; % dull cyan
shadingColorRight = [1 0.87 0.71]; % dull orange
shadingColorRightFar = [0.9 0.9 0.69];  % dull yellow
shadingColorCenter = [0.85 1 0.8]; % dull green

correctDelay = 2;
incorrectDelay = 4;
fps = 60;

% Error out if number of sessions is non-zero and does not match number of days.
if (~isempty(sessions) && length(days) ~= length(sessions))
    error('Number of sessions is non-zero and does not match number of days. It should.')
end

figN = 0;  % Used to count the separate figures made and lay them out on my laptop screen in a reasonable, though still unwieldy, manner

if(isempty(trialTypeStrArr))  % If no string specified, initialize to analyze all data
    trialTypeStrArr = "*->*";
end

numTrialsTotal = 0;

% First, iterate through all of the different trialTypes specified, as generally will make one plot per trialType
% if drawOneFig is specified.
for tt_i=1:length(trialTypeStrArr)
    % Local vars used for this figure plot title
    dayStr = '';
    numReplaysInFig = 0;
    daysPlotted = 0;
    if (includeCorrectionTrials)
        corrTxt = 'NC & Co';
    else
        corrTxt = 'NC';
    end

    % Generally will be drawingOneFig, so init a figure for drawing
    if (drawOneFig)
        figN = figN+1;
        f = initTrajFig(figN);
    end
    
    for d_i=1:length(days)  % Iterate through all of the specified days
        dayNum = num2str(days(d_i));
        if (~isempty(sessions))
            replaysFileList = dir([replaysFolder mouseName '-D' dayNum '-*-S' num2str(sessions(d_i)) '*']); %
        else
            replaysFileList = dir([replaysFolder mouseName '-D' dayNum '*']);
        end

        % If no replays found, print error and move on to next day
        if (isempty(replaysFileList))
            disp(['Could not find replays for day = ' dayNum '. Continuing to next day.']);
            continue; 
        end

        % Get the replayFileNames and sort them in trial order
        s = struct2cell(replaysFileList);
        replaysFileNames = natsortfiles(s(1,:));

        % Extract the scenario name from the replay filename
        expr = [mouseName '-D' dayNum '-([^-]+)-S([^-]+)-'];
        tokens = regexp(replaysFileList(1).name, expr, 'tokens');
        scenarioName = tokens{1}{1};
        sessionNum = tokens{1}{2};

        % Open the actions file for this mouse on this day, whose number of lines will match the number of 
        % replay files for that day.
        actionsFileName = [actionsFolder mouseName '-D' dayNum '-' scenarioName '-S' sessionNum '_actions.txt'];
        actionsFileID = fopen(actionsFileName);
        if (actionsFileID ~= -1)  % File was opened properly
            fgetl(actionsFileID); % Throw out the first line, as it is a column header
            actRecs = textscan(actionsFileID, '%s %s %d %s %s %d %d %d %d %d %d %s %d %d %f %d %d %d %d %d %d'); 
        else
            error(['Actions file ' actionsFileName 'could not be opened, so ending.']);
        end
        fclose(actionsFileID);  % If you forget to do this, then files no longer open and Matlab acts unpredictably

        % Use the scenario name to read the scenario file and then parse to draw the walls and targets.
        scenarioXDoc = xml2struct([scenariosFolder scenarioName '.xml']);  % Will spit error if not an XML file?
        % TODO: add support for multiple worlds, either embedded or pointed to
        % If the world is included, next read that file in
        if (isfield(scenarioXDoc.document.worlds, 'includeWorld')) 
            tempDOM = xml2struct([scenariosFolder scenarioXDoc.document.worlds.includeWorld(1).Text]);
            worldNode = tempDOM.world;
        else % world is embedded
            worldNode = scenarioXDoc.document.worlds.world(1);
        end
        
        % Next, identify which action records match the specified trial type
        filtRecIDs = [];
        for r_i=1:length(actRecs{1})
            stimLocX = getStimLocFromActions(actRecs, r_i);  % don't need stimLocZ so drop for now
            actionLocX = getActionLocFromActions(actRecs, r_i);
            if (trialTypeStrArr(tt_i) == "*->*" || ...
                (stimLocX == rightX && trialTypeStrArr(tt_i) == "R->*") || ...
                (stimLocX == rightX && actionLocX == rightX && trialTypeStrArr(tt_i) == "R->R") || ...
                (stimLocX == rightX && actionLocX == leftX && trialTypeStrArr(tt_i) == "R->L") || ...
                (stimLocX == rightX && actionLocX == centerX && trialTypeStrArr(tt_i) == "R->C") || ...
                (stimLocX == rightX && (actionLocX == leftX || actionLocX == centerX) && trialTypeStrArr(tt_i) == "R->LC") || ...
                (stimLocX == centerX && trialTypeStrArr(tt_i) == "C->*") || ...
                (stimLocX == centerX && actionLocX == centerX && trialTypeStrArr(tt_i) == "C->C") || ...
                (stimLocX == centerX && actionLocX == rightX && trialTypeStrArr(tt_i) == "C->R") || ...
                (stimLocX == centerX && actionLocX == leftX && trialTypeStrArr(tt_i) == "C->L") || ...
                (stimLocX == centerX && (actionLocX == leftX || actionLocX == rightX) && trialTypeStrArr(tt_i) == "C->LR") || ...
                (stimLocX == leftX && trialTypeStrArr(tt_i) == "L->*") || ...
                (stimLocX == leftX && actionLocX == leftX && trialTypeStrArr(tt_i) == "L->L") || ...
                (stimLocX == leftX && actionLocX == rightX && trialTypeStrArr(tt_i) == "L->R") || ...
                (stimLocX == leftX && actionLocX == centerX && trialTypeStrArr(tt_i) == "L->C") || ...
                (stimLocX == leftX && (actionLocX == rightX || actionLocX == centerX) && trialTypeStrArr(tt_i) == "L->RC"))
                    filtRecIDs(length(filtRecIDs)+1) = r_i;
            end
        end
                
        % There could be 1 more replay files than entries in the actions file if the game is manually ended, 
        % so limit the count to the number of rows in the actions files
        if (isempty(trials))
            trialsToDo = 1:length(filtRecIDs);
        else
            trialsToDo = trials(trials <= length(filtRecIDs));
        end
        for r_i=trialsToDo 
            stimLocX = getStimLocFromActions(actRecs, filtRecIDs(r_i));
            actionLocX = getActionLocFromActions(actRecs, r_i);
            optoLoc = getOptoLocFromActions(actRecs, filtRecIDs(r_i));
            worldNum = getWorldNumFromActions(actRecs, filtRecIDs(r_i));
            isCorrectionTrial = getCorrectionFromActions(actRecs, filtRecIDs(r_i));

            if (isCorrectionTrial && ~includeCorrectionTrials)
                continue;
            end

            if (~drawOneFig)
                f = initTrajFig(1);
                set(f, 'Position', [68*3 7*634/8 448 420])
            end

            % Draw level map with walls and tree as a large circle
            if (~exist('wall', 'var') || ~drawOneFig)
                for w_i=1:length(worldNode.walls.wall)
                    wall = worldNode.walls.wall{w_i};
                    wallPosStr = wall.pos.Text;
                    wallPosXYZ = split(wallPosStr, ';');
                    wallPosX = str2double(wallPosXYZ{1});
                    wallPosZ = str2double(wallPosXYZ{3});
                    % Got center of wall, but need to get orientation and length
                    wallRotStr = wall.rot.Text;
                    wallRotXYZ = split(wallRotStr, ';');
                    wallRotY = -str2double(wallRotXYZ{2});  % Need to flip sign

                    wallScaleStr = wall.scale.Text;
                    wallScaleXYZ = split(wallScaleStr, ';');
                    wallScaleZ = str2double(wallScaleXYZ{3}) + 1; % add 1 because Unity does this

                    % Rotation matrix to rotate about the Y axis (though conventionally the Z axis)
                    Ry = [cosd(wallRotY) -sind(wallRotY); sind(wallRotY) cosd(wallRotY)];
                    x = [wallPosX, wallPosX];
                    z = [wallPosZ - 0.5*wallScaleZ, wallPosZ + 0.5*wallScaleZ];
                    % Need to shift to origin, then rotate, then shift back 
                    xCenter = wallPosX;
                    zCenter = wallPosZ;
                    x = x - xCenter;
                    z = z - zCenter;
                    rotatedWallPos = Ry*[x;z];
                    rotatedWallPos(1,:) = rotatedWallPos(1,:) + xCenter;
                    rotatedWallPos(2,:) = rotatedWallPos(2,:) + zCenter;

                    plot(rotatedWallPos(1,:), rotatedWallPos(2,:), 'Color', wallColor, 'LineWidth', wallWidth)
                end
                % After drawing walls, draw the tree visible on this trial.
                % Supports 3 and 4-choice trials
                for t_i=1:length(worldNode.trees.t)
                    treePosStr = worldNode.trees.t{t_i}.pos.Text;
                    treePosXYZ = split(treePosStr, ';');
                    if (length(worldNode.trees.t) == 3)
                        if (t_i == 3)  % For 3-choice, always plot 3rd tree
                            plot(str2double(treePosXYZ{1}), str2double(treePosXYZ{3}), 'ok', 'MarkerSize', 44, 'LineWidth', 4, 'MarkerFaceColor', shadingColorCenter);
                        elseif (str2double(treePosXYZ{1}) == stimLocX)
                            markerColor = [1 1 1];
                            if (stimLocX == leftX)
                                markerColor = shadingColorLeft;
                            elseif (stimLocX == rightX)
                                markerColor = shadingColorRight;
                            end
                            plot(str2double(treePosXYZ{1}), str2double(treePosXYZ{3}), 'ok', 'MarkerSize', 44, 'LineWidth', 4, 'MarkerFaceColor', markerColor);
                        end
                    elseif (length(worldNode.trees.t) == 4)
                        if (str2double(treePosXYZ{1}) == stimLocX)
                            markerColor = [1 1 1];
                            if (stimLocX == leftNearX)
                                markerColor = shadingColorLeft;
                            elseif (stimLocX == leftFarX)
                                markerColor = shadingColorLeftFar;
                            elseif (stimLocX == rightNearX)
                                markerColor = shadingColorRight;
                            elseif (stimLocX == rightFarX)
                                markerColor = shadingColorRightFar;
                            end
                            plot(str2double(treePosXYZ{1}), str2double(treePosXYZ{3}), 'ok', 'MarkerSize', 44, 'LineWidth', 4, 'MarkerFaceColor', markerColor);
                        end
                    end
                    
                end
            end

            if (~lastTrial)
                if (stimLocX == actionLocX)
                    cutFromEnd = correctDelay * fps;
                else
                    cutFromEnd = incorrectDelay * fps;
                end
            else
                cutFromEnd = 0;
            end
            
            %disp(['Processed replay #' num2str(filtRecIDs(r_i))]);

            % Finally, parse the replay file to draw the path the mouse took for this level.
            replaysFileID = fopen([replaysFileList(filtRecIDs(r_i)).folder '\' replaysFileNames{filtRecIDs(r_i)}]);
            if (replaysFileID ~= -1)  % File was opened properly
                C = textscan(replaysFileID, '%f %f %f %f %f %f %f %f', 'Delimiter', {';', ','});
                % Sometimes the replay file has an x coord but no z coord, not sure why.
                scatter(C{1}(1:length(C{3})-cutFromEnd), C{3}(1:end-cutFromEnd), markSize, jet(length(C{3}(1:end-cutFromEnd))), 'MarkerFaceAlpha', markAlpha, 'MarkerEdgeAlpha', markAlpha);
                plot(centerX, centerX, 'o', 'MarkerSize', markSize, 'MarkerEdgeColor', 'w', 'MarkerFaceColor', 'b');

                fclose(replaysFileID);
            end
        end
        if (~isempty(filtRecIDs))
            daysPlotted = daysPlotted + 1;
            if ~isempty(dayStr) % Prepend a comma if past the first day
                dayStr = [dayStr ','];
            end
            dayStr = [dayStr num2str(days(d_i))];
            numReplaysInFig = numReplaysInFig + length(filtRecIDs);
        end
        clear wall;
    end
    
    % Plot title for all days of this trial type
    if(numReplaysInFig > 0)
        dayLabel = 'day';
        if (daysPlotted > 1)
            dayLabel = 'days';
        end
        tit = [upper(mouseName) ' (' dayLabel ' ' dayStr  '), ' trialTypeStrArr{tt_i} ', n=' num2str(length(trialsToDo)) ', ' corrTxt];
        title(tit);
    else % If not trajs plotted, close figure and reuse that position on the screen for the next figure
        close(f);
        figN = figN - 1;
    end
    numTrialsTotal = numTrialsTotal + numReplaysInFig;
end

if (drawOneFig)
    disp(['Total trials analyzed = ' num2str(length(trialsToDo))]);
end

fclose('all');

end