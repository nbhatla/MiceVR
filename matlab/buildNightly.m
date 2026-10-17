% BUILDNIGHTLY  Compile nightlyAnalyze into a Windows console executable.
%
% Run this in MATLAB R2017b, from the folder that holds the analysis code,
% with every folder the code depends on (Google Sheets functions, helpers,
% config readers) already on the MATLAB path.
%
% Build on the rig PC itself (or a PC with identical PC-specific helper files):
% getPathActionsFolder and any other PC-specific functions are compiled INTO
% the .exe, so whatever paths they hold at build time are the ones it uses.

outDir = fullfile(pwd, 'nightly_build');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

mcc('-m', 'nightlyAnalyze.m', ...                    % console app (-m), so disp() output reaches the log
    '-o', 'nightlyAnalyze', ...
    '-d', outDir, ...
    '-a', which('UCB_mouse_eye_measurements.m'), ...  % loaded via run(), which the compiler can't see
    '-v');

% If the Google Sheets functions rely on extra files (Java .jar files,
% credential/token files, etc.), add them here with more '-a' entries,
% e.g.  '-a', 'C:\path\to\GoogleSheets\lib'

fprintf('\nBuilt: %s\n', fullfile(outDir, 'nightlyAnalyze.exe'));
fprintf('Check %s for anything the compiler could not resolve.\n', ...
    fullfile(outDir, 'mccExcludedFiles.log'));
