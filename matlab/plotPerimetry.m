function plotPerimetry(actionFileDirectory, matchName)
% This script takes in 1 or more action logs and outputs a figure and data
% file showing the accuracy at each position, in a greyscale gradient,
% where white is 100% and black is 0%.
% 
% One graph will be produced for each scale observed.  Each graph will
% encompass the full 180 degrees of azimuthal view.
% 
% In the first version, the logs will have 4 scales: full, 40x40, 20x20 and
% 10x10.
%
% Only works with 3-choice right now

% First, find all the filenames to read in
fileList = dir([actionFileDirectory '/*.txt']); % Get all mat files, and use that to construct filenames for video files

% Store the results in a hashtable, one for hits and one for misses
hitMapL90 = containers.Map();
hitMapL40 = containers.Map();
hitMapL20 = containers.Map();
hitMapL10 = containers.Map();
missMapL90 = containers.Map();
missMapL40 = containers.Map();
missMapL20 = containers.Map();
missMapL10 = containers.Map();

hitMapR90 = containers.Map();
hitMapR40 = containers.Map();
hitMapR20 = containers.Map();
hitMapR10 = containers.Map();
missMapR90 = containers.Map();
missMapR40 = containers.Map();
missMapR20 = containers.Map();
missMapR10 = containers.Map();

% Second, open each file. Then, read each line, determine the scale, and then add
% the trial either as correct or incorrect to the data structure recording
% accuracy at that scale and position.
numFilesAnalyzed = 0;
for i=1:length(fileList)
    if (isempty(matchName) || (~isempty(matchName) && contains(fileList(i).name, matchName)))
        fid = fopen([fileList(i).folder '\' fileList(i).name]);
        if (fid ~= -1)  % File was opened properly
            numFilesAnalyzed = numFilesAnalyzed + 1;
            tline = fgetl(fid); % Throw out the first line, as it is a column header
            C = textscan(fid, '%s %s %d %s %d %d %d %d %d %d %d %d %d %d %f'); % C is a cell array with each string separated by a space
            % If this is not a center trial, add it to the maps
            for j = 1:length(C{1})
                nasal = C{8}(j);
                temporal = C{9}(j);
                high = C{10}(j);
                low = C{11}(j);
                key = [num2str(nasal, '%02d') ',' num2str(temporal, '%02d') ',' num2str(high, '%02d') ',' num2str(low, '%02d')]; 
                prevVal = 0;
                dtn = temporal - nasal;
                %if (dtn == 20)
                %    disp ([num2str(j) '-' num2str(dtn)]);
                %end
                % If the mouse selected the correct stimulus, add to the correct Hit map.  Else, add to the correct Miss map.
                if (C{5}(j) == C{12}(j))
                    if (C{5}(j) == 19980) % Write to left maps
                        if (dtn == 90) % Write to map 90
                            if (isKey(hitMapL90, key))
                                prevVal = hitMapL90(key);
                            end
                            hitMapL90(key) = prevVal + 1;
                        elseif (dtn == 40)
                            if (isKey(hitMapL40, key))
                                prevVal = hitMapL40(key);
                            end
                            hitMapL40(key) = prevVal + 1;                        
                        elseif (dtn == 20)
                            if (isKey(hitMapL20, key))
                                prevVal = hitMapL20(key);
                            end
                            hitMapL20(key) = prevVal + 1;                        
                        elseif (dtn == 10)
                            if (isKey(hitMapL10, key))
                                prevVal = hitMapL10(key);
                            end
                            hitMapL10(key) = prevVal + 1;                        
                        end
                    elseif (C{5}(j) == 20020) % Write to the right maps
                        if (dtn == 90) % Write to map 90
                            if (isKey(hitMapR90, key))
                                prevVal = hitMapR90(key);
                            end
                            hitMapR90(key) = prevVal + 1;
                        elseif (dtn == 40)
                            if (isKey(hitMapR40, key))
                                prevVal = hitMapR40(key);
                            end
                            hitMapR40(key) = prevVal + 1;                        
                        elseif (dtn == 20)
                            if (isKey(hitMapR20, key))
                                prevVal = hitMapR20(key);
                            end
                            hitMapR20(key) = prevVal + 1;                        
                        elseif (dtn == 10)
                            if (isKey(hitMapR10, key))
                                prevVal = hitMapR10(key);
                            end
                            hitMapR10(key) = prevVal + 1;                        
                        end
                    end
                else
                    if (C{5}(j) == 19980) % Write to left maps
                        if (dtn == 90) % Write to map 90
                            if (isKey(missMapL90, key))
                                prevVal = missMapL90(key);
                            end
                            missMapL90(key) = prevVal + 1;
                        elseif (dtn == 40)
                            if (isKey(missMapL40, key))
                                prevVal = missMapL40(key);
                            end
                            missMapL40(key) = prevVal + 1;                        
                        elseif (dtn == 20)
                            if (isKey(missMapL20, key))
                                prevVal = missMapL20(key);
                            end
                            missMapL20(key) = prevVal + 1;                        
                        elseif (dtn == 10)
                            if (isKey(missMapL10, key))
                                prevVal = missMapL10(key);
                            end
                            missMapL10(key) = prevVal + 1;                        
                        end
                    elseif (C{5}(j) == 20020) % Write to the right maps
                        if (dtn == 90) % Write to map 90
                            if (isKey(missMapR90, key))
                                prevVal = missMapR90(key);
                            end
                            missMapR90(key) = prevVal + 1;
                        elseif (dtn == 40)
                            if (isKey(missMapR40, key))
                                prevVal = missMapR40(key);
                            end
                            missMapR40(key) = prevVal + 1;                        
                        elseif (dtn == 20)
                            if (isKey(missMapR20, key))
                                prevVal = missMapR20(key);
                            end
                            missMapR20(key) = prevVal + 1;                        
                        elseif (dtn == 10)
                            if (isKey(missMapR10, key))
                                prevVal = missMapR10(key);
                            end
                            missMapR10(key) = prevVal + 1;                        
                        end
                    end
                end
            end
        end
        fclose(fid);
    end
end

% Now that all the data are collected, draw the figures
% Each Map data structure will get 1 figure
% For a total of 8 maps, 4 on each side

set(0,'units','pixels');
pixSS = get(0,'screensize');
screenWidth = pixSS(3);
screenHeight = pixSS(4);

% Start with full, unrestricted stimuli; since only 1 key, can just call values.
drawPerimetricMap(hitMapL90, missMapL90, 90, 1); % final arg is whether to reverse the X-axis
movegui([0,screenHeight/2]);
drawPerimetricMap(hitMapR90, missMapR90, 90, 0);
movegui([screenWidth/4,screenHeight/2]);

% Now, draw the 40x40 stimulus map
drawPerimetricMap(hitMapL40, missMapL40, 40, 1);
movegui([0,0]);
drawPerimetricMap(hitMapR40, missMapR40, 40, 0);
movegui([screenWidth/4,0]);

% Draw the 20x20 stimulus map
drawPerimetricMap(hitMapL20, missMapL20, 20, 1);
movegui([screenWidth/2,screenHeight/2]);
drawPerimetricMap(hitMapR20, missMapR20, 20, 0);
movegui([3*screenWidth/4,screenHeight/2]);

% Draw the 10x10 stimulus map
drawPerimetricMap(hitMapL10, missMapL10, 10, 1);
movegui([screenWidth/2,0]);
drawPerimetricMap(hitMapR10, missMapR10, 10, 0);
movegui([3*screenWidth/4,0]);

disp(['Analyzed ' num2str(numFilesAnalyzed) ' files.']);

end