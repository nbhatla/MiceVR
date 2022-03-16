function scanSheetsToAnalyze(rigNum)
% This script runs nightly at midnight as a scheduled task.
% It will read each sheet in the Google Spreadsheet and decide
% which analysis to do. To start, it will track and analyze the
% pupil videos and post the results on the spreadsheet when done.
% It will analyze the eye videos once n20 or higher is reached, 
% and record the results on the sheet, only if that mouse runs on
% the current rig.

vrGSdocidFileName = '../config/vrGSdocid.txt';

dayCol = 1;
nasalRestrictCol = 4;
dateCol = 13;

datePat = '.*/.*/.*';

rigNumRow = 7;
rigNumCol = 28; % "AB"

mouseNameRow = 1;
mouseNameCol = 27;

notesCol = 25;

global numVideosTracking;
numVideosTracking = 0;

% 6 was the max on my laptop before I got disk IO errors.  Maybe the desktops can do more?  
% Laptop had 4 physical cores but 8 virtual, but desktop has 6 physical and 6 logical.  So probably 6 is the most.
maxVideoTracking = 4;  
numThreads = maxVideoTracking;

futureNum = 0;

% This struct tracks where the analysis should be written in the Sheet
tracking = struct('mouseName', {}, 'sheetID', {}, 'row', {}, 'day', {});

% Setup parallel processing infrastructure, by first shutting down the
% existing parallel pool that was likely leftover from eye recording.
pool = gcp('nocreate');
if ~isempty(pool)
    if pool.NumWorkers < numThreads
        delete(pool); % Shut it down
        parpool(numThreads);
    end
else
    parpool(numThreads);
end

if (isfile(vrGSdocidFileName)) % If the docid file exists, use that to find the Google Sheet for this mouse
    fid = fopen(vrGSdocidFileName);
    docid = fgetl(fid);
    sheetIDs = GetSheetIDs(docid, {}, 1);   % Data sheets only, not all sheets
    for sheetIdx=1:length(sheetIDs)
        sheet = GetGoogleSpreadsheet(docid, sheetIDs(sheetIdx));
        % First, check to see if the mouse of this sheet is run on the
        % current rig.
        rig = sheet(rigNumRow, rigNumCol);
        rig = str2double(rig{1}(2:end));  % Remove the leading number sign
        mouseName = sheet(mouseNameRow, mouseNameCol);
        mouseName = mouseName{1};
        if rig == rigNum
            disp ([mouseName ' is on rig #' num2str(rig)]);
            % Now, find the last complete training day, check and see if it is is n20 or
            % greater, then kick off thread to trackPupils of that day's
            % eye videos, followed by analyzing it, followed by writing the
            % results back to the sheet, prepending the notes.
            lastCompleteTrainingDayStr = '0';
            lastNasalRestrictStr = '-90';
            lastRow = 0;
            padding = '';
            for row=1:size(sheet, 1)
                trainingDayStr = sheet{row, dayCol};
                trainingDateStr = sheet(row, dateCol);
                nasalRestrictStr = sheet(row, nasalRestrictCol);
                %disp([row '-' trainingDayStr '-' trainingDateStr]);
                if (~isempty(trainingDateStr{1}))  % Needed because sometimes datecolumn isn't found properly
                    r = regexp(trainingDateStr{1}, datePat, 'once');
                    if (sum(isstrprop(trainingDayStr, 'digit')) && ~isempty(r))  % Found a day with a date, store it overwriting the last one
                        lastCompleteTrainingDayStr = trainingDayStr;
                        lastNasalRestrictStr = nasalRestrictStr;
                        lastRow = row;
                    end
                end
            end
            lastCompleteTrainingDayNum = str2double(lastCompleteTrainingDayStr);            
            lastNasalRestrictDeg = str2double(lastNasalRestrictStr);
            % Need this to check and see if the video has already been analyzed
            if (lastCompleteTrainingDayNum < 10)
                padding = '00';
            elseif (lastCompleteTrainingDayNum < 100)
                padding = '0';
            end
            vidFileName = [mouseName '_' padding lastCompleteTrainingDayStr '_1.mp4'];
            % Sometimes a video might be missing, despite training.  Only continue tracking if it is present.
            if (isfile(vidFileName))
                trackedVidFileName = [vidFileName(1:end-6) '_opened_ann.mp4'];
                % Only continue tracking if the video has not been tracked before
                if (~isfile(trackedVidFileName))
                    % Only track if field restriction is at least n20
                    if (lastNasalRestrictDeg >= 20)
                        % Use parfeval and it will handle all the queueing, better than spmd
                        % To start, just run trackPupils, do analyze later
                        F(futureNum+1) = parfeval(@trackPupilsAuto, 0, mouseName, lastCompleteTrainingDayNum, rigNum, [0.2 0.2]);
                        futureNum = futureNum + 1;
                        tracking(end+1).mouseName = mouseName;
                        tracking(end).sheetID = sheetIDs(sheetIdx);
                        tracking(end).row = lastRow;
                        tracking(end).day = lastCompleteTrainingDayNum;
                        disp(['Tracking: ' mouseName ' on day ' lastCompleteTrainingDayStr]);
                    end
                end
            end
        end
    end
    % Wait for all the tracking to finish, then proceed to analyzing the
    % results and recording those results in the Sheet
    if (futureNum > 0)
        wait(F);
    end
    for i=1:length(tracking)
        try
            [lekl, lekle, lekr, lekre, rekl, rekle, rekr, rekre] = analyzePupils(tracking(i).mouseName, tracking(i).day, rigNum, [], [1 1], 1);
            sheet = GetGoogleSpreadsheet(docid, tracking(i).sheetID);
            notes = sheet(tracking(i).row, notesCol);
            mat2sheets(docid, num2str(tracking(i).sheetID), [tracking(i).row notesCol], {[num2str(lekl) '/' num2str(lekr) ' // ' num2str(rekl) '/' num2str(rekr) ' - ' notes{1}]});
        catch ME
            disp(ME.message);
        end
    end
else
    disp('SPREADSHEET CONFIG NOT FOUND.  Are you running from the correct folder?');
end


end