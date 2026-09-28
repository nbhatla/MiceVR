function mousecamBuildInfo()
%MOUSECAMBUILDINFO  Print the paths you need for the Application Compiler app.
%
%   Run this first, then keep the Command Window open while you fill in the
%   compiler dialogs - you can copy and paste straight out of it.

fprintf('\n========================================================\n');
fprintf(' MouseCam - what to put in the Application Compiler app\n');
fprintf('========================================================\n');

% --- main file ---------------------------------------------------------
fprintf('\n[1] MAIN FILE\n');
p = which('mousecamApp');
if isempty(p)
    fprintf('    *** mousecamApp.m not found. cd to the MouseCam folder. ***\n');
else
    fprintf('    %s\n', p);
end

% --- supporting code ---------------------------------------------------
fprintf('\n[2] FILES REQUIRED FOR YOUR APPLICATION TO RUN\n');
fprintf('    (add all of these; paste the folder path into the file browser\n');
fprintf('     and press Ctrl+A to grab them in one go)\n\n');

others = {'mousecamConfig', 'mousecamCheckAdaptor', 'mousecamCameraIdentity', ...
          'mousecamPoolInit', ...
          'mousecamSlaveStart', 'mousecamSlaveStop', 'mousecamSlaveCleanup', ...
          'mousecamGetDay', 'mousecamFileBase', 'mousecamSaveSession', ...
          'logTrialMarks', 'GetGoogleToken', 'GetSheetIDs', 'GetGoogleSpreadsheet'};
missing = {};
for k = 1:numel(others)
    q = which(others{k});
    if isempty(q)
        fprintf('    MISSING  %s\n', others{k});
        missing{end+1} = others{k}; %#ok<AGROW>
    else
        fprintf('    %s\n', q);
    end
end

% --- camera adaptor ----------------------------------------------------
fprintf('\n[3] CAMERA ADAPTOR\n');
try
    root = matlabshared.supportpkg.getSupportPackageRoot;
catch
    root = '';
end

if isempty(root) || exist(root, 'dir') ~= 7
    fprintf('    *** No support packages found on this machine.        ***\n');
    fprintf('    *** Install the GenICam support package, then rerun.  ***\n');
else
    imaqFolder = fullfile(root, 'toolbox', 'imaq');
    if exist(imaqFolder, 'dir') == 7
        fprintf('    Add everything under this folder:\n');
        fprintf('    %s\n', imaqFolder);
    else
        fprintf('    Add everything under this folder:\n');
        fprintf('    %s\n', root);
    end

    try
        d = dir(fullfile(root, '**', 'mwgentlimaq.dll'));
    catch
        d = [];
    end
    if isempty(d)
        fprintf('\n    *** mwgentlimaq.dll NOT found - the GenICam support   ***\n');
        fprintf('    *** package is not installed here. Install it first.  ***\n');
    else
        fprintf('\n    The adaptor itself (add this one explicitly too):\n');
        fprintf('    %s\n', fullfile(d(1).folder, d(1).name));
    end
end

% --- runtime -----------------------------------------------------------
fprintf('\n[4] RUNTIME\n');
try
    src = mcrinstaller;
    if exist(src, 'file') == 2
        f = dir(src);
        fprintf('    Installer is on this machine (%.0f MB):\n', f.bytes / 1e6);
        fprintf('    %s\n', src);
        fprintf('    You do not need this path - just tick the "include\n');
        fprintf('    runtime in installer" option and the app uses it.\n');
    else
        fprintf('    Not found locally; the app will offer to download it.\n');
    end
catch
    fprintf('    Not found locally; the app will offer to download it.\n');
end

% --- summary -----------------------------------------------------------
fprintf('\n--------------------------------------------------------\n');
if isempty(missing)
    fprintf('All code files present. Now run:  applicationCompiler\n');
else
    fprintf('Fix the MISSING files above first.\n');
end
fprintf('--------------------------------------------------------\n\n');
end
