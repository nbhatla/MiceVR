function plotTargetAzimLoc(mouseName, days, sessions, trialTypeStrArr, includeCorrectionTrials)
% This function takes as inputs the replay files for a session as well as the mouse's eye movements 
% during that session.  It outputs several plots:
% 1) For the specified trialType, a plot for each trial showing the 
%    azimuthal extent of the target.
% 2) An average plot of the azimuthal extent over all trials of a specific type
% 3) A plot with medial component of the azimuthal extent of the target
%    over all trials of a specific type, drawn on one plot

% The main point of this script is to help me determine whether the mice could be 
% cheating, that is, moving the ball and their eyes such that the target 
% enters the good field prior to deciding to run in that direction.

% So the most important trial type to plot is the one where the target
% is contralateral to the lesion.

%%% CHANGE THESE VARS FOR YOUR SETUP PRIOR TO RUNNING %%%
scenariosFolder = 'C:\Users\nikhil\Documents\GitHub\MiceVR\scenarios\';
actionsFolder = 'C:\Users\nikhil\UCB\data-VR\';
replaysFolder = 'C:\Users\nikhil\UCB\data-replays\';
eyevideosFolder = 'C:\Users\nikhil\UCB\video_eyes\';

% Be sure to change these if the x location of the trees changes
stimLeftNear = 19973;
stimLeftFar = 19972;
stimRightNear = 20027;
stimRightFar = 20028;
stimCenter = 20000;

grayShade = [0.5 0.5 0.5];

fps = 60;
successDelay = 2; %sec
failureDelay = 4; %sec

% Error out if number of sessions is non-zero and does not match number of days.
if (~isempty(sessions) && length(days) ~= length(sessions))
    error('Number of sessions is non-zero and does not match number of days. It should.')
end

% To start, let's just produce one plot of the first trial of a specified session.
% To do this, we need to align the eye movements within a trial with the 
% ball movements within that trial.  The replay file has the ball movements and the 
% angular location of the target and distractor, and the analyzed eye file 
% has the eye location for both eyes.

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

    % Extract the scenario name from the replay filename, which will be used to open the correct actions file, though thi is probably not necessary
    expr = [mouseName '-D' dayNum '-([^-]+)-S([^-]+)-'];
    tokens = regexp(replaysFileList(1).name, expr, 'tokens');
    scenarioName = tokens{1}{1};
    sessionNum = tokens{1}{2};

    % Open the actions file for this mouse on this day, whose number of lines will match the number of 
    % replay files for that day.  
    % We use the actions file to cleanup the replays plot, by extracting the
    % (1) Field restriction, nasal and temporal fields
    % (2) Associated location of the target - is it on the left or the right of center, 
    %     so we can invert the sign of the restriction
    % (3) Whether the trial was a success (2 sec wait), or failure (4 sec wait), 
    %     so we can truncate truncate the plot at the end
    actionsFileName = [actionsFolder mouseName '-D' dayNum '-' scenarioName '-S' sessionNum '_actions.txt'];
    actionsFileID = fopen(actionsFileName);
    if (actionsFileID ~= -1)  % File was opened properly
        fgetl(actionsFileID); % Throw out the first line, as it is a column header
        actRecs = textscan(actionsFileID, '%s %s %d %s %s %d %d %d %d %d %d %s %d %d %f %d %d %d %d %d %d'); 
    else
        error(['Actions file ' actionsFileName 'could not be opened, so ending.']);
    end
    fclose(actionsFileID);  % If you forget to do this, then files no longer open and Matlab acts unpredictably

    % Iterate through each trial, drawing the angular bounds of the target
    for trialIdx = 1:length(actRecs{1})
        % First, need to determine if this was a correct or incorrect trial
        % actRecs{5} is the target location, actRecs{12} is the turn location
        if (iscell(actRecs{5}(trialIdx)))
            tmp = strsplit(actRecs{5}{trialIdx}, ';');
            stimLocX = str2double(tmp{1});
        else
            stimLocX = str2double(actRecs{5}(trialIdx));
        end
        if (iscell(actRecs{12}(trialIdx)))
            tmp = strsplit(actRecs{12}{trialIdx}, ';');
            actLocX = str2double(tmp{1});
        else 
            actLocX = str2double(actRecs{12}(trialIdx));
        end

        % No, just plot based on the replay file
        % Ex line: 20000,0.74,20000;0;-51,-8;,
        replaysFileID = fopen([replaysFolder replaysFileNames{trialIdx}]);
        if (replaysFileID ~= -1)
            repRecs = textscan(replaysFileID, '%f %f %f %f %f %f %f %f', 'Delimiter', {';', ','}); 
            xStart = 1;
            % Truncate the end of the replay file, since the screen is not displayed after the mouse makes a decision
            if (stimLocX == actLocX)
                xEnd = length(repRecs{1}) - successDelay * fps;
            else
                xEnd = length(repRecs{1}) - failureDelay * fps;
            end
            x = (xStart:xEnd)/fps;  % so units are in time, not frames
            y1 = repRecs{5};
            y1 = y1(xStart:xEnd);
            y2 = repRecs{6};
            y2 = y2(xStart:xEnd);
            figure
            patch([x flip(x)],[y1' flip(y2')], grayShade);
            ylim([-90 90]);
            xlim([0 x(end)]);
            yticks(-90:15:90);
            set(gca, 'YTickLabel', []);
            yticklabels({'-90', '', '-60', '', '-30', '', '0', '', '30', '', '60', '', '90'});
            ylabel('azimuth (deg, + right, - left)');
            xlabel('time (s)');
            fclose(replaysFileID);
        else
            error(['Replays file ' replaysFileNames(1) 'could not be opened, so ending.']);
        end
    end


end

end