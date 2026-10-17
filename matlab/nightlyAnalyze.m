function nightlyAnalyze(rigNum, maxVideoTracking, rootDir)
% NIGHTLYANALYZE  Entry point for the compiled nightly eye-video analysis.
%
% Compiled usage (from the eyevideos folder):
%     nightlyAnalyze.exe 5                    rig 5, default 3 videos at once
%     nightlyAnalyze.exe 5 4                  rig 5, 4 videos at once
%     nightlyAnalyze.exe 5 4 "C:\...\MVR"     ...and this root folder
%
% Uncompiled usage (for testing inside MATLAB):
%     nightlyAnalyze(5)
%     nightlyAnalyze(5, 4)
%     nightlyAnalyze(5, 4, 'C:\Users\USER\Documents\MVR')
%
% ROOTDIR is the folder getPathRootFolder returns: it holds config\
% (vrGSdocid.txt, gcp_key.json), actions\, replays\ and scenarios\.  It
% reaches getPathRootFolder through the MVR_ROOT environment variable,
% which the parallel workers inherit too.  If it is not given, MVR_ROOT is
% left as it is (nightly.bat sets it as well), and failing that
% getPathRootFolder uses its built-in fallback path.
%
% This wrapper exists so that scanSheetsToAnalyze does not need to know it is
% compiled. It handles the things that differ when running as an .exe:
%   - command-line arguments arrive as text, not numbers
%   - figures must stay hidden and be closed, or the .exe never exits
%   - the parallel pool must be shut down cleanly
%   - an exit code is returned so Task Scheduler can show success/failure

% The pragma below tells the compiler to include functions that it might not
% find through its own dependency analysis (called via parfeval handles or run()).
%#function trackPupilsAuto trackPupils analyzePupils

DEFAULT_MAX_VIDEO_TRACKING = 3;

if nargin < 1
    fprintf(2, 'Usage: nightlyAnalyze <rigNum> [maxVideoTracking] [rootDir]\n');
    exitWith(2);
    return;
end

% Arguments from the command line are char arrays. Without this conversion,
% scanSheetsToAnalyze would compare the rig number against the character '5'
% (ASCII 53), so no mouse would ever match.
rigNum = toNumber(rigNum);
if isnan(rigNum)
    fprintf(2, 'Rig number must be numeric.\n');
    exitWith(2);
    return;
end

if nargin < 2 || isempty(maxVideoTracking)
    maxVideoTracking = DEFAULT_MAX_VIDEO_TRACKING;
else
    maxVideoTracking = toNumber(maxVideoTracking);
end
if isnan(maxVideoTracking) || maxVideoTracking < 1 || maxVideoTracking ~= round(maxVideoTracking)
    fprintf(2, 'maxVideoTracking must be a whole number of 1 or more.\n');
    exitWith(2);
    return;
end

% Root folder.  Must be set BEFORE the parallel pool starts (inside
% scanSheetsToAnalyze), so the worker processes inherit MVR_ROOT as well.
if nargin >= 3 && ~isempty(rootDir)
    rootDir = char(rootDir);
    rootDir = regexprep(rootDir, '[\\/]+$', '');   % drop any trailing slash
    if exist(rootDir, 'dir') ~= 7
        fprintf(2, 'Root folder not found: %s\n', rootDir);
        exitWith(2);
        return;
    end
    setenv('MVR_ROOT', rootDir);
end
fprintf('Root folder:    %s\n', getPathRootFolder());
fprintf('Config folder:  %s\n', getPathConfigFolder());
fprintf('Actions folder: %s\n', getPathActionsFolder());

% Keep all figures from analyzePupils off-screen.
set(groot, 'DefaultFigureVisible', 'off');

% A compiled program must be told explicitly to use the local cluster
% before scanSheetsToAnalyze starts its parallel pool.
if isdeployed
    parallel.defaultClusterProfile('local');
end

fprintf('=== Nightly analysis started %s | rig %d | %d videos at once | folder %s ===\n', ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), rigNum, maxVideoTracking, pwd);

exitCode = 0;
try
    scanSheetsToAnalyze(rigNum, maxVideoTracking);
catch ME
    fprintf(2, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    exitCode = 1;
end

% A compiled app waits for every open figure to close before it exits,
% so close any that are still around.
close all force;

% Shut down the parallel pool so no worker processes are left running.
try
    delete(gcp('nocreate'));
catch
end

fprintf('=== Nightly analysis finished %s (exit code %d) ===\n', ...
    datestr(now, 'yyyy-mm-dd HH:MM:SS'), exitCode);

exitWith(exitCode);
end

function n = toNumber(x)
if ischar(x) || isstring(x)
    n = str2double(x);
else
    n = double(x);
end
end

function exitWith(code)
% Only exit when compiled; when testing in MATLAB, just return.
if isdeployed
    exit(code);
end
end