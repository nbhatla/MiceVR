function plotPerimetry(mouseName, days)
% This script takes in 1 or more action logs and outputs a figure and data
% file showing the accuracy at each position, in a green-red gradient,
% where green is 100% and red is 0%.
% 
% One graph will be produced for each scale observed.  Each graph will
% encompass the full 180 degrees of azimuthal view, and elevations 0->50
% degrees.
% 
% In the first version, the logs will have 4 scales: full, 40x40, 20x20 and
% 10x10.
%
% The transition from 40x40 to 20x20 was too difficult for not well-trained
% mice to learn. So in the second version, an additional scale was added:
% 20x40 (tall strips 20 degrees wide).
%
% Only works with 3-choice right now.

% First, find all the filenames to read in
fileList = dir(['data/*.txt']); % Get all mat files, and use that to construct filenames for video files

% Store the results in a hashtable, one for hits and one for misses
hitMapL90x80 = containers.Map();
hitMapL40x40 = containers.Map();
hitMapL20x40 = containers.Map();
hitMapL20x20 = containers.Map();
hitMapL10x10 = containers.Map();
missMapL90x80 = containers.Map();
missMapL40x40 = containers.Map();
missMapL20x40 = containers.Map();
missMapL20x20 = containers.Map();
missMapL10x10 = containers.Map();

hitMapR90x80 = containers.Map();
hitMapR40x40 = containers.Map();
hitMapR20x40 = containers.Map();
hitMapR20x20 = containers.Map();
hitMapR10x10 = containers.Map();
missMapR90x80 = containers.Map();
missMapR40x40 = containers.Map();
missMapR20x40 = containers.Map();
missMapR20x20 = containers.Map();
missMapR10x10 = containers.Map();

% Second, open each file. Then, read each line, determine the scale, and then add
% the trial either as correct or incorrect to the data structure recording
% accuracy at that scale and position.
numFilesAnalyzed = 0;
for i=1:length(fileList)
%    if (isempty(matchName) || (~isempty(matchName) && contains(fileList(i).name, matchName)))
    for k=1:length(days)
        if (contains(fileList(i).name, [mouseName '-D' num2str(days(k))]))
            fid = fopen([fileList(i).folder '\' fileList(i).name]);
            if (fid ~= -1)  % File was opened properly
                numFilesAnalyzed = numFilesAnalyzed + 1;
                tline = fgetl(fid); % Throw out the first line, as it is a column header
                C = textscan(fid, '%s %s %d %s %d %d %d %d %d %d %d %d %d %d %f %d %d'); % C is a cell array with each string separated by a space
                % If this is not a center trial, add it to the maps
                for j = 1:length(C{1})
                    nasal = C{8}(j);
                    temporal = C{9}(j);
                    high = C{10}(j);
                    low = C{11}(j);
                    key = [num2str(nasal, '%02d') ',' num2str(temporal, '%02d') ',' num2str(high, '%02d') ',' num2str(low, '%02d')]; 
                    prevVal = 0;
                    dtn = temporal - nasal;
                    dhl = high - low;
                    %if (dtn == 20)
                    %    disp ([num2str(j) '-' num2str(dtn)]);
                    %end
                    % If the mouse went left or right, see if it was a hit or a miss.
                    if (C{5}(j) == 19980 || C{5}(j) == 20020) % C{5} is the target location, C{12} is the turn location
                        if (C{5}(j) == C{12}(j))
                            if (C{5}(j) == 19980) % Write to one of the left hit maps
                                mapName = ['hitMapL' num2str(dtn) 'x' num2str(dhl)];
                            elseif (C{5}(j) == 20020) % Write to one of the right hit maps
                                mapName = ['hitMapR' num2str(dtn) 'x' num2str(dhl)];
                            end
                        else
                            if (C{5}(j) == 19980) % Write to one of the left miss maps
                                mapName = ['missMapL' num2str(dtn) 'x' num2str(dhl)];
                            elseif (C{5}(j) == 20020) % Write to one of the right miss maps
                                mapName = ['missMapR' num2str(dtn) 'x' num2str(dhl)];
                            end
                        end
                        map = eval([mapName ';']);
                        if (isKey(map, key))
                            prevVal = map(key);
                        end
                        map(key) = prevVal + 1; %#ok<*NASGU>
                        eval([mapName ' = map;']);  % write back to the state variables from the temp variable
                    end
                end
            end
            fclose(fid);
        end
    end
end

% Now that all the data are collected, draw the figures
% Each Map data structure will get 1 figure
% For a total of 10 maps, 5 on each side

[screenWidth, screenHeight] = getScreenDim();

offset = -20;
% Start with full, unrestricted stimuli; since only 1 key, can just call values.
h = drawPerimetricMap(hitMapL90x80, missMapL90x80, 90, 80, 1); % final arg is whether to reverse the X-axis
set(h, 'Position', [0 2*screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);
h = drawPerimetricMap(hitMapR90x80, missMapR90x80, 90, 80, 0);
set(h, 'Position', [screenWidth/4 2*screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);

% Now, draw the 40x40 stimulus map
h = drawPerimetricMap(hitMapL40x40, missMapL40x40, 40, 40, 1);
set(h, 'Position', [0 screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);
h = drawPerimetricMap(hitMapR40x40, missMapR40x40, 40, 40, 0);
set(h, 'Position', [screenWidth/4 screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);

% Now, draw the 20x40 stimulus map
h = drawPerimetricMap(hitMapL20x40, missMapL20x40, 20, 40, 1);
set(h, 'Position', [0 offset h.Position(3) h.Position(3)*50/90]);
h = drawPerimetricMap(hitMapR20x40, missMapR20x40, 20, 40, 0);
set(h, 'Position', [screenWidth/4 offset h.Position(3) h.Position(3)*50/90]);

% Draw the 20x20 stimulus map
h = drawPerimetricMap(hitMapL20x20, missMapL20x20, 20, 20, 1);
set(h, 'Position', [screenWidth/2 2*screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);
h = drawPerimetricMap(hitMapR20x20, missMapR20x20, 20, 20, 0);
set(h, 'Position', [3*screenWidth/4 2*screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);

% Draw the 10x10 stimulus map
h = drawPerimetricMap(hitMapL10x10, missMapL10x10, 10, 10, 1);
set(h, 'Position', [screenWidth/2 screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);
h = drawPerimetricMap(hitMapR10x10, missMapR10x10, 10, 10, 0);
set(h, 'Position', [3*screenWidth/4 screenHeight/3+offset h.Position(3) h.Position(3)*50/90]);

disp(['Analyzed ' num2str(numFilesAnalyzed) ' files.']);

end